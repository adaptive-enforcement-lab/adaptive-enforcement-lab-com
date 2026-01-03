---
title: Actions Runner Controller Patterns
description: >-
  ARC deployment, autoscaling, and security policies for Kubernetes-based runners. Horizontal pod autoscaling, network policies, and pod security standards for ephemeral self-hosted runners in Kubernetes.
---

# Actions Runner Controller Patterns

## State Isolation Best Practices

### Filesystem Cleanup Verification

Verify ephemeral runners leave no state between jobs:

```bash
#!/bin/bash
# Verify runner filesystem cleanup after job completion

set -euo pipefail

RUNNER_ID="${1:?Runner ID required}"

# Check runner container/VM/pod destroyed
if podman ps -a | grep "${RUNNER_ID}"; then
    echo "ERROR: Runner ${RUNNER_ID} still exists"
    exit 1
fi

# Check runner deregistered from GitHub
if gh api repos/my-org/my-repo/actions/runners | jq -e ".runners[] | select(.name==\"${RUNNER_ID}\")"; then
    echo "ERROR: Runner ${RUNNER_ID} still registered"
    exit 1
fi

echo "==> Cleanup verified: ${RUNNER_ID} completely destroyed"
```

### Network Identity Rotation

```bash
#!/bin/bash
# Verify fresh network identity per job

set -euo pipefail

# Container-based: Each container gets new network namespace
podman inspect "${RUNNER_ID}" | jq '.[] | .NetworkSettings.IPAddress'

# VM-based: Each VM gets new IP from DHCP pool
gcloud compute instances describe "${RUNNER_NAME}" --format="value(networkInterfaces[0].networkIP)"

# ARC: Each pod gets new IP from Kubernetes cluster pool
kubectl get pod "${POD_NAME}" -n actions-runner-system -o jsonpath='{.status.podIP}'
```

### Credential Lifecycle Validation

```bash
#!/bin/bash
# Verify credentials expire with runner destruction

set -euo pipefail

RUNNER_ID="${1:?Runner ID required}"
START_TIME=$(date +%s)

# Start ephemeral runner with OIDC
podman run --rm \
  --name "${RUNNER_ID}" \
  --env RUNNER_EPHEMERAL=true \
  ghcr.io/actions/runner:latest

END_TIME=$(date +%s)

# Verify OIDC token no longer valid
if gcloud auth print-access-token --impersonate-service-account="${RUNNER_SA}" 2>/dev/null; then
    echo "ERROR: Credentials still valid after runner destruction"
    exit 1
fi

echo "==> Credentials expired at runner destruction (${END_TIME})"
```

## Monitoring and Observability

Track ephemeral runner provisioning and job execution.

### Provisioning Metrics

```yaml
# prometheus-runner-metrics.yml
# Prometheus metrics for ephemeral runner orchestration

scrape_configs:
  - job_name: 'ephemeral-runners'
    static_configs:
      - targets: ['localhost:9090']
    metrics_path: '/metrics'
    relabel_configs:
      - source_labels: [__name__]
        regex: 'runner_(provisioning_duration_seconds|job_execution_duration_seconds|cleanup_duration_seconds)'
        action: keep
```

### Alerting Rules

```yaml
# alerts/ephemeral-runners.yml
# Alert on provisioning failures

groups:
  - name: ephemeral-runners
    interval: 30s
    rules:
      - alert: RunnerProvisioningFailed
        expr: rate(runner_provisioning_failures_total[5m]) > 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Ephemeral runner provisioning failures detected"
          description: "{{ $value }} provisioning failures in last 5 minutes"

      - alert: RunnerCleanupFailed
        expr: runner_cleanup_failures_total > 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Ephemeral runner cleanup failed"
          description: "Runner state may persist across jobs. Investigate immediately."

      - alert: RunnerProvisioningSlow
        expr: histogram_quantile(0.95, runner_provisioning_duration_seconds) > 300
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Ephemeral runner provisioning slow"
          description: "95th percentile provisioning time: {{ $value }}s"
```

## Quick Reference: Ephemeral Runner Checklist

Use this checklist when deploying ephemeral runners.

### Container-Based Runners

- [ ] Containers run with `--rm` flag for automatic cleanup
- [ ] Read-only root filesystem (`--read-only`)
- [ ] Temporary writable storage with `noexec` (`--tmpfs`)
- [ ] All capabilities dropped (`--cap-drop ALL`)
- [ ] No new privileges (`--security-opt no-new-privileges`)
- [ ] User-mode networking (no host network access)
- [ ] `RUNNER_EPHEMERAL=true` environment variable set
- [ ] gVisor runtime for enhanced isolation (optional)
- [ ] Systemd service configured for auto-restart

### VM-Based Runners

- [ ] Fresh VM provisioned per job (no reuse)
- [ ] Startup script installs and configures runner
- [ ] `--ephemeral` flag set during runner registration
- [ ] Self-destruct script executes after job completion
- [ ] VM image pre-hardened with Packer (recommended)
- [ ] Cloud metadata endpoints blocked
- [ ] Autoscaling configured with min=0, max=N
- [ ] No persistent disks attached

### ARC (Kubernetes) Runners

- [ ] `ephemeral: true` set in RunnerDeployment spec
- [ ] Pod security context enforces non-root
- [ ] Read-only root filesystem for container
- [ ] All capabilities dropped
- [ ] Network policies deny-by-default
- [ ] Horizontal autoscaler configured (min=0)
- [ ] Pod Security Standards set to `restricted`
- [ ] Cleanup verification monitoring enabled

### State Isolation Validation

- [ ] Filesystem artifacts deleted after job
- [ ] Runner deregistered from GitHub after job
- [ ] Network identity rotated (new IP per job)
- [ ] Credentials expire with runner destruction
- [ ] No cross-job contamination possible
- [ ] Monitoring alerts on cleanup failures
- [ ] Regular audit of runner registration list

## Next Steps

- **[Runner Hardening](hardening.md)**: Apply OS and network hardening to runner images
- **[Runner Groups](groups.md)**: Organize ephemeral runners by trust level and repository access
- **[Runner Security Overview](index.md)**: Review threat model and deployment strategies

## Related Documentation

- [OIDC Federation](../secrets/oidc.md): Secretless authentication for ephemeral runners
- [Secret Management](../secrets/index.md): Temporary credential patterns
- [Workflow Triggers](../workflows/triggers.md): Understanding which events provision runners
