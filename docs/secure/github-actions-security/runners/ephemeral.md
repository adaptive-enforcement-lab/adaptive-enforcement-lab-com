---
title: Ephemeral Runner Patterns
description: >-
  Disposable runner patterns for GitHub Actions. Container-based, VM-based, and
  ARC deployment strategies with complete state isolation between jobs.
tags:
  - github-actions
  - security
  - runners
  - ephemeral
  - containers
  - kubernetes
---

# Ephemeral Runner Patterns

Persistent runners are persistence vectors. Deploy disposable infrastructure instead.

!!! success "The Goal"

    Every job executes in a fresh environment. Malicious workflows cannot plant backdoors because the execution environment is destroyed after completion. State isolation prevents cross-job contamination.

## Why Ephemeral Runners?

Persistent runners retain state between jobs. One compromised workflow means every subsequent job inherits the malicious modifications.

**Ephemeral Benefits**:

- **State Isolation**: Fresh filesystem, network identity, credentials per job
- **Backdoor Prevention**: No cron jobs, no persistence mechanisms survive job completion
- **Credential Containment**: Leaked credentials expire when environment is destroyed
- **Attack Surface Reduction**: Minimal installed packages, no accumulated cruft
- **Automatic Cleanup**: No manual intervention required to restore clean state

**Persistent Runner Risks**:

- Malicious job installs reverse shell in crontab for future execution
- Credentials stolen from filesystem persist across job boundaries
- Network connections remain open for reconnaissance between jobs
- Filesystem poisoning affects subsequent builds
- Compliance violations accumulate without audit trail

## Deployment Models

Choose based on security requirements, provisioning speed, and infrastructure constraints.

| Model | Isolation Level | Provisioning Time | Security Risk | Best For |
| ----- | --------------- | ----------------- | ------------- | -------- |
| **Container** | Process + Network | 5-30 seconds | **Low** | Production workloads with frequent job execution |
| **VM** | Full virtualization | 30-120 seconds | **Very Low** | High-security workloads requiring hardware isolation |
| **ARC (Kubernetes)** | Pod + Node isolation | 10-60 seconds | **Low-Medium** | Organizations with existing Kubernetes infrastructure |

## Container-Based Ephemeral Runners

Fresh container per job. Fast provisioning, minimal attack surface, strong isolation with gVisor.

### Podman Runner Pattern

Rootless containers with automatic cleanup.

```bash
#!/bin/bash
# /opt/runner-orchestrator/run-ephemeral-job.sh
# Ephemeral runner using Podman rootless containers

set -euo pipefail

RUNNER_VERSION="2.311.0"
RUNNER_IMAGE="ghcr.io/actions/runner:${RUNNER_VERSION}"
RUNNER_TOKEN="${1:?Runner registration token required}"
RUNNER_NAME="ephemeral-$(date +%s)-$(openssl rand -hex 4)"
RUNNER_LABELS="self-hosted,ephemeral,container"

echo "==> Starting ephemeral runner: ${RUNNER_NAME}"

# Pull latest runner image
podman pull "${RUNNER_IMAGE}"

# Run container with strict isolation
podman run \
  --rm \
  --name "${RUNNER_NAME}" \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,nodev,size=2G \
  --tmpfs /opt/runner/_work:rw,noexec,nosuid,nodev,size=8G \
  --security-opt no-new-privileges=true \
  --security-opt label=type:runner_t \
  --cap-drop ALL \
  --network slirp4netns:allow_host_loopback=false \
  --env RUNNER_TOKEN="${RUNNER_TOKEN}" \
  --env RUNNER_NAME="${RUNNER_NAME}" \
  --env RUNNER_LABELS="${RUNNER_LABELS}" \
  --env RUNNER_EPHEMERAL=true \
  "${RUNNER_IMAGE}"

echo "==> Runner ${RUNNER_NAME} completed and destroyed"
```

**Security Features**:

- `--read-only`: Immutable root filesystem prevents persistent modifications
- `--tmpfs`: Temporary writable storage with `noexec` to block malicious binaries
- `--security-opt no-new-privileges`: Prevents privilege escalation
- `--cap-drop ALL`: Removes all Linux capabilities
- `--network slirp4netns`: User-mode networking without host network access
- `RUNNER_EPHEMERAL=true`: Runner deregisters after single job

### Podman with gVisor Isolation

Enhanced container isolation using gVisor user-space kernel.

```bash
#!/bin/bash
# Ephemeral runner with gVisor container runtime

set -euo pipefail

# Requires gVisor runsc runtime configured
# See: https://gvisor.dev/docs/user_guide/install/

RUNNER_VERSION="2.311.0"
RUNNER_IMAGE="ghcr.io/actions/runner:${RUNNER_VERSION}"
RUNNER_TOKEN="${1:?Runner registration token required}"
RUNNER_NAME="gvisor-ephemeral-$(date +%s)-$(openssl rand -hex 4)"

echo "==> Starting gVisor-isolated runner: ${RUNNER_NAME}"

podman run \
  --rm \
  --runtime /usr/local/bin/runsc \
  --name "${RUNNER_NAME}" \
  --read-only \
  --tmpfs /tmp:rw,size=2G \
  --tmpfs /opt/runner/_work:rw,size=8G \
  --security-opt no-new-privileges=true \
  --cap-drop ALL \
  --network slirp4netns \
  --env RUNNER_TOKEN="${RUNNER_TOKEN}" \
  --env RUNNER_NAME="${RUNNER_NAME}" \
  --env RUNNER_EPHEMERAL=true \
  "${RUNNER_IMAGE}"
```

**gVisor Benefits**:

- System calls intercepted by user-space kernel (not host kernel)
- Container escape requires gVisor exploit + kernel exploit
- Stronger isolation than standard Linux namespaces
- Performance trade-off: 10-20% overhead vs native containers

### Systemd Service for Ephemeral Containers

Automatic provisioning on boot with systemd unit.

```ini
# /etc/systemd/system/github-runner-ephemeral@.service
# Systemd template for ephemeral container runners

[Unit]
Description=GitHub Actions Ephemeral Runner (Container %i)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=github-runner
Environment=RUNNER_VERSION=2.311.0
Environment=RUNNER_IMAGE=ghcr.io/actions/runner:${RUNNER_VERSION}
Environment=RUNNER_TOKEN_FILE=/etc/github-runner/token
ExecStartPre=/usr/bin/podman pull ${RUNNER_IMAGE}
ExecStart=/opt/runner-orchestrator/run-ephemeral-job.sh $(cat ${RUNNER_TOKEN_FILE})
Restart=always
RestartSec=10
TimeoutStopSec=30

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadOnlyPaths=/
ReadWritePaths=/opt/github-runner

[Install]
WantedBy=multi-user.target
```

```bash
# Enable multiple concurrent ephemeral runners
systemctl enable github-runner-ephemeral@{1..5}.service
systemctl start github-runner-ephemeral@{1..5}.service
```

## VM-Based Ephemeral Runners

Full VM per job. Strongest isolation, slower provisioning, higher resource overhead.

### Cloud VM Autoscaling Pattern

Provision fresh VM for each job using cloud autoscaling.

#### GCP Managed Instance Group

```bash
#!/bin/bash
# Create GCP instance template for ephemeral runners

set -euo pipefail

PROJECT_ID="my-gcp-project"
REGION="us-central1"
ZONE="${REGION}-a"
TEMPLATE_NAME="github-runner-ephemeral-$(date +%Y%m%d-%H%M%S)"
SERVICE_ACCOUNT="github-runner@${PROJECT_ID}.iam.gserviceaccount.com"

# Create instance template with startup script
gcloud compute instance-templates create "${TEMPLATE_NAME}" \
  --project="${PROJECT_ID}" \
  --machine-type=e2-medium \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=20GB \
  --boot-disk-type=pd-standard \
  --service-account="${SERVICE_ACCOUNT}" \
  --scopes=cloud-platform \
  --metadata=enable-oslogin=TRUE \
  --metadata-from-file=startup-script=/opt/runner-orchestrator/vm-startup.sh \
  --tags=github-runner,ephemeral \
  --network-interface=network=default,no-address

# Create managed instance group with autoscaling
gcloud compute instance-groups managed create github-runners-ephemeral \
  --project="${PROJECT_ID}" \
  --base-instance-name=runner \
  --template="${TEMPLATE_NAME}" \
  --size=0 \
  --zone="${ZONE}"

# Configure autoscaling based on job queue
gcloud compute instance-groups managed set-autoscaling github-runners-ephemeral \
  --project="${PROJECT_ID}" \
  --zone="${ZONE}" \
  --min-num-replicas=0 \
  --max-num-replicas=10 \
  --cool-down-period=60 \
  --mode=on \
  --scale-based-on-cpu \
  --target-cpu-utilization=0.6
```

#### VM Startup Script

```bash
#!/bin/bash
# /opt/runner-orchestrator/vm-startup.sh
# GCP VM startup script for ephemeral runner

set -euo pipefail

echo "==> Configuring ephemeral runner VM"

# Install runner
mkdir -p /opt/actions-runner && cd /opt/actions-runner
curl -o actions-runner-linux-x64-2.311.0.tar.gz \
  -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
tar xzf actions-runner-linux-x64-2.311.0.tar.gz
rm actions-runner-linux-x64-2.311.0.tar.gz

# Fetch registration token from Secret Manager
RUNNER_TOKEN=$(gcloud secrets versions access latest --secret=github-runner-token)
RUNNER_NAME="vm-ephemeral-$(hostname)-$(date +%s)"
RUNNER_LABELS="self-hosted,ephemeral,vm,gcp"

# Register runner (ephemeral mode)
./config.sh \
  --url https://github.com/my-org/my-repo \
  --token "${RUNNER_TOKEN}" \
  --name "${RUNNER_NAME}" \
  --labels "${RUNNER_LABELS}" \
  --ephemeral \
  --unattended

# Run single job
./run.sh

# Self-destruct after job completion
echo "==> Job complete, destroying VM"
gcloud compute instances delete "$(hostname)" --zone="$(gcloud compute instances list --filter="name=$(hostname)" --format="value(zone)")" --quiet
```

### Packer VM Image for Hardened Runners

Pre-baked VM image with security hardening applied.

```json
{
  "builders": [
    {
      "type": "googlecompute",
      "project_id": "my-gcp-project",
      "source_image_family": "ubuntu-2204-lts",
      "zone": "us-central1-a",
      "image_name": "github-runner-hardened-{{timestamp}}",
      "image_family": "github-runner-hardened",
      "ssh_username": "packer",
      "machine_type": "e2-medium",
      "disk_size": 20
    }
  ],
  "provisioners": [
    {
      "type": "shell",
      "script": "scripts/hardening/os-baseline.sh"
    },
    {
      "type": "shell",
      "script": "scripts/hardening/cis-benchmarks.sh"
    },
    {
      "type": "shell",
      "script": "scripts/hardening/firewall-rules.sh"
    },
    {
      "type": "shell",
      "script": "scripts/install-runner.sh"
    },
    {
      "type": "shell",
      "inline": [
        "echo 'Hardened runner image build complete'",
        "echo 'Image includes: OS hardening, firewall, audit logging, runner software'",
        "echo 'Startup script will configure ephemeral mode at boot'"
      ]
    }
  ]
}
```

## Actions Runner Controller (ARC) Patterns

Kubernetes-native runner orchestration with pod-level isolation.

### ARC Installation

Deploy ARC controller to Kubernetes cluster.

```yaml
# arc-controller-install.yml
# Install Actions Runner Controller using Helm

apiVersion: v1
kind: Namespace
metadata:
  name: actions-runner-system
---
# Install cert-manager (required for ARC)
# helm repo add jetstack https://charts.jetstack.io
# helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set installCRDs=true

# Install ARC controller
# helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
# helm install actions-runner-controller actions-runner-controller/actions-runner-controller \
#   --namespace actions-runner-system \
#   --set authSecret.github_token=<GITHUB_PAT>
```

### Ephemeral Runner Deployment

Configure runner pools with ephemeral mode enabled.

```yaml
# arc-ephemeral-runners.yml
# Ephemeral runner deployment for ARC

apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: ephemeral-runners
  namespace: actions-runner-system
spec:
  replicas: 3  # Minimum runners available
  template:
    spec:
      repository: my-org/my-repo
      ephemeral: true  # Critical: Destroy pod after single job
      labels:
        - self-hosted
        - ephemeral
        - kubernetes
        - arc

      # Pod security context
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault

      # Container security
      containerMode: kubernetes
      containers:
        - name: runner
          image: ghcr.io/actions/actions-runner:latest
          imagePullPolicy: Always
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
          resources:
            requests:
              memory: "512Mi"
              cpu: "500m"
            limits:
              memory: "2Gi"
              cpu: "2000m"
          volumeMounts:
            - name: work
              mountPath: /runner/_work
      volumes:
        - name: work
          emptyDir:
            sizeLimit: 8Gi
```

### ARC Horizontal Autoscaler

Scale runners based on job queue depth.

```yaml
# arc-autoscaler.yml
# Scale runners based on pending GitHub Actions jobs

apiVersion: actions.summerwind.dev/v1alpha1
kind: HorizontalRunnerAutoscaler
metadata:
  name: ephemeral-runners-autoscaler
  namespace: actions-runner-system
spec:
  scaleTargetRef:
    name: ephemeral-runners
  minReplicas: 0  # Scale to zero when idle
  maxReplicas: 20
  metrics:
    - type: TotalNumberOfQueuedAndInProgressWorkflowRuns
      repositoryNames:
        - my-org/my-repo
  scaleDownDelaySecondsAfterScaleOut: 300  # Wait 5 minutes before scaling down
  scaleUpTriggers:
    - githubEvent:
        workflowJob: {}
      duration: 5m  # Scale up for 5 minutes after trigger
```

### Network Policies for ARC Runners

Restrict network access for runner pods.

```yaml
# arc-network-policy.yml
# Deny-by-default network policy for runner pods

apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ephemeral-runner-network-policy
  namespace: actions-runner-system
spec:
  podSelector:
    matchLabels:
      app: ephemeral-runners
  policyTypes:
    - Egress
  egress:
    # Allow DNS
    - to:
        - namespaceSelector:
            matchLabels:
              name: kube-system
      ports:
        - protocol: UDP
          port: 53

    # Allow GitHub API
    - to:
        - ipBlock:
            cidr: 140.82.112.0/20
        - ipBlock:
            cidr: 143.55.64.0/20
      ports:
        - protocol: TCP
          port: 443

    # Allow package registries (add as needed)
    - ports:
        - protocol: TCP
          port: 443

    # Deny cloud metadata endpoints
    - to:
        - ipBlock:
            cidr: 169.254.169.254/32
      ports: []  # Empty ports = deny all
```

### Pod Security Standards

Enforce restricted security policies for runner pods.

```yaml
# arc-pod-security.yml
# Pod Security Admission for runner namespace

apiVersion: v1
kind: Namespace
metadata:
  name: actions-runner-system
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

## State Isolation Best Practices

Ensure zero state leakage between jobs.

### Filesystem Cleanup Verification

```bash
#!/bin/bash
# /opt/runner-orchestrator/verify-cleanup.sh
# Verify ephemeral runner destroys all state

set -euo pipefail

RUNNER_ID="${1:?Runner ID required}"

echo "==> Verifying cleanup for runner: ${RUNNER_ID}"

# Check container is destroyed
if podman ps -a | grep -q "${RUNNER_ID}"; then
    echo "ERROR: Container ${RUNNER_ID} still exists"
    exit 1
fi

# Check no filesystem artifacts remain
if [[ -d "/tmp/runner-${RUNNER_ID}" ]]; then
    echo "ERROR: Filesystem artifacts remain: /tmp/runner-${RUNNER_ID}"
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
