#!/usr/bin/env bash
set -euo pipefail

script="$(cd "$(dirname "$0")" && pwd)/sonarqube-scan.sh"
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT
mkdir -p "$temp_dir/bin" "$temp_dir/work"

cat > "$temp_dir/bin/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  run)
    if [[ "$2" == "-d" ]]; then echo "test-container"; fi
    ;;
  rm) echo "$*" >> "$MOCK_DOCKER_LOG" ;;
  *) echo "Unexpected docker command: $*" >&2; exit 1 ;;
esac
EOF
cat > "$temp_dir/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
args="$*"
case "$args" in
  *"/api/system/status"*) echo '{"status":"UP"}' ;;
  *"/api/users/change_password"*)
    password=""
    for arg in "$@"; do
      case "$arg" in password=*) password="${arg#password=}" ;; esac
    done
    if [[ ! "$password" =~ [A-Z] || ! "$password" =~ [a-z] || ! "$password" =~ [0-9] || ! "$password" =~ [^a-zA-Z0-9] || ${#password} -lt 12 ]]; then
      echo '{"errors":[{"msg":"Password does not meet policy"}]}'
      exit 22
    fi
    if [[ "${MOCK_PASSWORD_FAILURE:-}" == 1 ]]; then
      echo '{"errors":[{"msg":"Test password change failed"}]}'
      exit 22
    fi
    ;;
  *"/api/user_tokens/generate"*) echo '{"token":"test-token"}' ;;
  *"/api/qualitygates/project_status"*)
    printf '{"projectStatus":{"status":"OK"}}' > sonar-report/quality-gate.json ;;
  *"/api/issues/search"*)
    printf '{"paging":{"total":0},"issues":[]}' > sonar-report/page-1.json ;;
  *) echo "Unexpected curl command: $*" >&2; exit 1 ;;
esac
EOF
cat > "$temp_dir/bin/jq" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
  *".projectStatus.status"*) echo "OK" ;;
  *".status"*) echo "UP" ;;
  *".token"*) echo "test-token" ;;
  *".paging.total"*) echo "0" ;;
  *".issues[]"*) echo "[]" ;;
  *) echo "Unexpected jq command: $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$temp_dir/bin/docker" "$temp_dir/bin/curl" "$temp_dir/bin/jq"
export PATH="$temp_dir/bin:$PATH"
export MOCK_DOCKER_LOG="$temp_dir/docker.log"
cd "$temp_dir/work"

bash "$script" > "$temp_dir/success.log" 2>&1
grep -q 'SonarQube quality gate: OK' evidence/sonar-summary.txt
grep -q 'rm -f -v test-container' "$MOCK_DOCKER_LOG"

if MOCK_PASSWORD_FAILURE=1 bash "$script" > "$temp_dir/failure.log" 2>&1; then
  echo "Expected SonarQube password change failure." >&2
  exit 1
fi
grep -q 'SonarQube password change failed:.*Test password change failed' "$temp_dir/failure.log"
echo "SonarQube script setup and failure-path tests passed."
