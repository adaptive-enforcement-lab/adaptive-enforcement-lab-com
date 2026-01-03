---
title: VM-Based Ephemeral Runners
description: >-
  Cloud VM autoscaling patterns, Packer hardened image creation, and Kubernetes ARC ephemeral runner deployment configurations
---

!!! tip "Pre-Harden VM Images"

    Use Packer to create hardened VM images with security controls baked in. Pre-configured images reduce provisioning time and ensure consistent security baselines across all ephemeral runners.

## Kubernetes-Based Ephemeral Runners (ARC)

```yaml
kind: Namespace
metadata:
  name: actions-runner-system
---

# Install cert-manager (required for ARC)

# helm repo add jetstack <https://charts.jetstack.io>

# helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set installCRDs=true

# Install ARC controller

# helm repo add actions-runner-controller <https://actions-runner-controller.github.io/actions-runner-controller>

# helm install actions-runner-controller actions-runner-controller/actions-runner-controller \

# --namespace actions-runner-system \

# --set authSecret.github_token=<GITHUB_PAT>

```

## Ephemeral Runner Deployment

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

## ARC Horizontal Autoscaler

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

## Network Policies for ARC Runners

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

## Pod Security Standards

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

## Filesystem Cleanup Verification

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
