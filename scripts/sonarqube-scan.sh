#!/usr/bin/env bash
set -euo pipefail

project_key="todo-app"
server_url="http://127.0.0.1:19000"
container_name="sonarqube-${GITHUB_RUN_ID:-local}-${GITHUB_RUN_ATTEMPT:-1}"
container_id=""
mkdir -p sonar-report evidence

cleanup() {
  if [[ -n "$container_id" ]]; then
    docker rm -f -v "$container_id" >/dev/null || echo "Failed to remove SonarQube container $container_id" >&2
  fi
}
trap cleanup EXIT

container_id="$(docker run -d --name "$container_name" -p 127.0.0.1:19000:9000 \
  sonarqube:25.9.0.112764-community)"

ready=false
for ((attempt = 0; attempt < 90; attempt++)); do
  status="$(curl -fsS --max-time 3 "$server_url/api/system/status" 2>/dev/null | jq -r '.status' 2>/dev/null || true)"
  if [[ "$status" == "UP" ]]; then
    ready=true
    break
  fi
  sleep 5
done
if [[ "$ready" != true ]]; then
  echo "SonarQube did not become ready within 450 seconds." >&2
  docker logs "$container_id" >&2
  exit 1
fi

password="$(openssl rand -hex 24)"
echo "::add-mask::$password"
curl -fsS -u admin:admin -X POST "$server_url/api/users/change_password" \
  --data-urlencode "login=admin" --data-urlencode "previousPassword=admin" \
  --data-urlencode "password=$password" >/dev/null
token="$(curl -fsS -u "admin:$password" -X POST "$server_url/api/user_tokens/generate" \
  --data-urlencode "name=ci-analysis" | jq -er '.token')"
echo "::add-mask::$token"
export SONAR_TOKEN="$token"
export SONAR_HOST_URL="$server_url"

set +e
docker run --rm --network host \
  -e SONAR_HOST_URL -e SONAR_TOKEN \
  -v "$PWD:/usr/src:ro" \
  sonarsource/sonar-scanner-cli:11.4.0.2044_7.2.0 \
  -Dsonar.projectKey="$project_key" \
  -Dsonar.sources=todo-app/src/main/java \
  -Dsonar.tests=todo-app/src/test/java \
  -Dsonar.java.binaries=todo-app/target/classes \
  -Dsonar.java.test.binaries=todo-app/target/test-classes \
  '-Dsonar.java.libraries=todo-app/target/dependency/*.jar' \
  '-Dsonar.java.test.libraries=todo-app/target/dependency/*.jar' \
  -Dsonar.scm.disabled=true \
  -Dsonar.working.directory=/tmp/sonar-work \
  -Dsonar.qualitygate.wait=true \
  -Dsonar.qualitygate.timeout=300
scan_status=$?
set -e

if ! curl -fsS -u "$token:" --get "$server_url/api/qualitygates/project_status" \
    --data-urlencode "projectKey=$project_key" -o sonar-report/quality-gate.json; then
  echo "SonarQube analysis did not produce a quality gate report (scanner exit $scan_status)." >&2
  exit 1
fi

page=1
while :; do
  curl -fsS -u "$token:" --get "$server_url/api/issues/search" \
    --data-urlencode "componentKeys=$project_key" --data-urlencode "ps=500" \
    --data-urlencode "p=$page" -o "sonar-report/page-$page.json"
  total="$(jq -er '.paging.total' "sonar-report/page-$page.json")"
  if ((total > 10000)); then
    echo "SonarQube reported more than 10000 issues; export cannot be completed." >&2
    exit 1
  fi
  if ((page * 500 >= total)); then
    break
  fi
  ((page += 1))
done
jq -s '[.[].issues[] | {rule, severity, type, status, message, component, line, impacts}]' \
  sonar-report/page-*.json > sonar-report/issues.json
rm sonar-report/page-*.json

gate="$(jq -er '.projectStatus.status' sonar-report/quality-gate.json)"
printf 'SonarQube quality gate: %s\nIssues reported: %s\nScanner exit status: %s\n' \
  "$gate" "$total" "$scan_status" | tee evidence/sonar-summary.txt
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "### SonarQube Java analysis"
    cat evidence/sonar-summary.txt
    echo
    echo "Download the SonarQube report artifact for issue details."
  } >> "$GITHUB_STEP_SUMMARY"
fi
if ((scan_status != 0)) || [[ "$gate" != "OK" ]]; then
  exit 1
fi
