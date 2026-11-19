# SRE Autopilot MVP using GitHub Copilot SDK

This package replaces direct Copilot CLI invocation with the TypeScript `@github/copilot-sdk`. GitHub Actions remains the runtime and UI. There is no portal, database, Kubernetes cluster, external service, or PAT required for the included demo.

## Architecture
`test/build jobs -> evidence artifacts -> final job with if: always() -> Copilot SDK session -> GitHub run summary + report artifact`

The SDK session is read-only. A pre-tool hook denies every tool call, so Copilot can reason only over the bounded evidence passed in the prompt. No fix is applied.

## Prerequisites
1. GitHub repository with Actions enabled.
2. GitHub Copilot enabled for the organization/user.
3. Organization policy **Allow use of Copilot CLI billed to the organization** enabled. The SDK uses the bundled Copilot runtime.
4. Workflow permission `copilot-requests: write` allowed by enterprise/organization policy.
5. Actions allow-list permits `actions/checkout@v6`, `actions/setup-node@v7`, `actions/upload-artifact@v4`, and `actions/download-artifact@v4`.

## Deploy
```bash
unzip sre-autopilot-copilot-sdk-mvp.zip
cd sre-autopilot-copilot-sdk-mvp
git init
git add .
git commit -m "Add SDK-based SRE Autopilot MVP"
git branch -M main
git remote add origin https://github.com/YOUR_ORG/sre-autopilot-copilot-sdk-mvp.git
git push -u origin main
```

No repository secret is required. The analysis job grants `copilot-requests: write` and passes the built-in `${{ github.token }}` as both `GITHUB_TOKEN` and `COPILOT_GITHUB_TOKEN` for runtime compatibility.

## Demo
1. Open **Actions -> SRE Autopilot Copilot SDK MVP -> Run workflow**.
2. Run with `simulate_failure=false` for a healthy report.
3. Run with `simulate_failure=true`. The build job records a controlled Helm failure.
4. Open the workflow run summary. The report identifies repository, run, attempt, commit, actor, outcome, RCA, evidence, recommendation and approval risk.
5. Download `sre-autopilot-sdk-report-RUN_ID-ATTEMPT` for `analysis.md` and redacted `evidence.txt`.

If organization policy or Copilot authentication is unavailable, the analyzer catches the SDK error and publishes a deterministic fallback, instead of hiding the original pipeline result.

## Security controls
- Evidence only: all SDK tool calls are denied by `onPreToolUse`.
- No autonomous remediation.
- Evidence capped at roughly 150 KB; each file contributes at most its last 20 KB.
- Common token/password/private-key patterns are redacted before prompting.
- Artifacts expire after 3/14 days.
- Fork PRs should be treated as untrusted; keep the SDK analysis job disabled or fallback-only if organization policy does not authorize Copilot requests for forks.
- Never collect `.env`, kubeconfig, tokens, private keys, full environment dumps, customer data, or unbounded logs.

## Integrate with any existing pipeline
Copy `src/analyze.ts`, `runbooks`, `package.json`, `package-lock.json`, and the final `sre-analysis` job. Add small `evidence-*` uploads to upstream jobs with `if: always()`. Update `needs: [...]` to include all pipeline jobs. Keep analysis permissions limited to:

```yaml
permissions:
  contents: read
  copilot-requests: write
```

Recommended evidence consists of test summaries, scanner results, Helm output, rollout status, selected Kubernetes events, and the last 200-500 relevant log lines.

## Real Kubernetes/OpenShift collection
Use workload identity/OIDC and namespace-scoped read-only RBAC. Add to the deployment job under `if: always()`:

```bash
kubectl get pods -n "$NAMESPACE" -o wide > evidence/pods.txt 2>&1 || true
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp | tail -n 200 > evidence/events.txt 2>&1 || true
kubectl rollout status deployment/"$APP" -n "$NAMESPACE" --timeout=90s > evidence/rollout.txt 2>&1 || true
```

Do not store a long-lived kubeconfig. If remediation is added later, place it in a separate workflow protected by GitHub Environments approval.

## Validation performed on this package
- `npm ci`
- TypeScript compilation with strict mode
- Node test execution
- Local deterministic-fallback execution
- ZIP integrity test

## Production hardening
Pin action versions to immutable SHAs, centralize/version the analyzer, add JSON-schema output validation, add repository-specific failure taxonomy/runbooks, and record reviewer feedback on RCA accuracy. Keep mutation outside the agent session and behind environment approval.
