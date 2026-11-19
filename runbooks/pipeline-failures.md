# Approved SRE runbook
Find the first causal error, not cascade errors. Correlate it with the current commit and clearly separate facts from hypotheses.
For Kubernetes failures inspect image pulls, probes, events, resource limits, scheduling and rollout status.
This MVP is read-only. Never reveal secrets or execute production remediation. Production changes require human approval.
