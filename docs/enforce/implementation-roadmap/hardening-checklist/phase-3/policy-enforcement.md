---
title: Phase 3: Runtime Policy Enforcement
description: >-
  Runtime policy enforcement with Kyverno. Required resource limits, image source verification, security context requirements, and admission control for Kubernetes production environments.
tags:
  - kyverno
  - policy-as-code
  - kubernetes
  - runtime-security
  - admission-control
---
# Phase 3: Runtime Policy Enforcement

Control what runs in production through admission control policies.

---

## Policy-as-Code Deployment

### Kyverno Installation

- [ ] **Deploy Kyverno to enforce policies at admission time**

  ```bash
  helm repo add kyverno https://kyverno.github.io/kyverno/
  helm install kyverno kyverno/kyverno \
    --namespace kyverno \
    --create-namespace \
    --set config.webhooks=null

  ```

  **How to validate**:

  ```bash
  kubectl get pods -n kyverno | grep kyverno
  # Should show webhook pods running
  ```

  **Why it matters**: Pods without resource limits, images from untrusted registries, or missing security context cannot run. Policy is enforced before deployment.

!!! tip "Webhook Configuration"
    Kyverno uses admission webhooks. Ensure your Kubernetes API server can reach the webhook service on port 9443. Test connectivity before deploying policies.

---

## Required Resource Limits

### CPU and Memory Enforcement

- [ ] **Enforce CPU and memory limits on all containers**

  ```yaml
  apiVersion: kyverno.io/v1
  kind: ClusterPolicy
  metadata:
    name: require-resource-limits
  spec:
    validationFailureAction: Enforce
    rules:
      - name: check-limits
        match:
          resources:
            kinds: [Pod]
        validate:
          message: "CPU and memory limits required"
          pattern:
            spec:
              containers:
                - resources:
                    limits:
                      memory: "?*"
                      cpu: "?*"

  ```

  **How to validate**:

  ```bash
  # Attempt to deploy pod without limits
  kubectl apply -f - <<EOF
  apiVersion: v1
  kind: Pod
  metadata:
    name: test
  spec:
    containers:
      - name: app
        image: nginx
  EOF
  # Should be rejected with validation error
  ```

  **Why it matters**: Containers without limits can consume unlimited resources, causing node failures and outages.

!!! warning "Resource Exhaustion Pattern"
    A single pod without memory limits can OOMKill the entire node. A pod without CPU limits can starve other workloads. Enforce limits on everything.

---

## Image Source Verification

### Approved Registries

- [ ] **Enforce images from approved registries only**

  ```yaml
  apiVersion: kyverno.io/v1
  kind: ClusterPolicy
  metadata:
    name: restrict-registries
  spec:
    validationFailureAction: Enforce
    rules:
      - name: check-registry
        match:
          resources:
            kinds: [Pod]
        validate:
          message: "Images must be from approved registries"
          pattern:
            spec:
              containers:
                - image: 'gcr.io/* | ghcr.io/org/*'

  ```

  **How to validate**:

  ```bash
  # Attempt to deploy from untrusted registry
  kubectl apply -f - <<EOF
  apiVersion: v1
  kind: Pod
  metadata:
    name: test
  spec:
    containers:
      - name: app
        image: ghcr.io/untrusted:latest
  EOF
  # Should be rejected
  ```

  **Why it matters**: Docker Hub images can be replaced or compromised. Approved registries are versioned and scanned.

---

## Required Security Context

### Container Security Standards

- [ ] **Enforce non-root, read-only filesystem, and no privileged escalation**

  ```yaml
  apiVersion: kyverno.io/v1
  kind: ClusterPolicy
  metadata:
    name: require-security-context
  spec:
    validationFailureAction: Enforce
    rules:
      - name: check-security-context
        match:
          resources:
            kinds: [Pod]
        validate:
          message: "Security context required"
          pattern:
            spec:
              containers:
                - securityContext:
                    runAsNonRoot: true
                    readOnlyRootFilesystem: true
                    allowPrivilegeEscalation: false

  ```

  **How to validate**:

  ```bash
  # Attempt to deploy as root
  kubectl apply -f - <<EOF
  apiVersion: v1
  kind: Pod
  metadata:
    name: test
  spec:
    containers:
      - name: app
        image: nginx
        securityContext:
          runAsUser: 0
  EOF
  # Should be rejected
  ```

  **Why it matters**: Root containers and privilege escalation allow attackers to compromise the host.

!!! example "Security Context Best Practice"
    Always set `runAsNonRoot: true`, `readOnlyRootFilesystem: true`, and `allowPrivilegeEscalation: false`. This eliminates entire classes of container escape attacks.

---

## Policy Observability

### Compliance Dashboard

- [ ] **Deploy Policy Reporter for compliance dashboard**

  ```bash
  helm repo add kyverno https://kyverno.github.io/kyverno/
  helm install policy-reporter kyverno/policy-reporter \
    --namespace kyverno \
    --set ui.enabled=true

  ```

  **How to validate**:

  ```bash
  kubectl port-forward -n kyverno svc/policy-reporter-ui 8080:8080
  # Open http://localhost:8080
  # Should show policy violations and audit data
  ```

  **Why it matters**: Dashboard shows which policies are failing, which teams need training, and overall compliance posture.

---

## Common Issues and Solutions

**Issue**: Kyverno webhook timeouts during high load

**Solution**: Increase webhook replicas and resource limits:

```yaml
helm upgrade kyverno kyverno/kyverno \
  --namespace kyverno \
  --set replicaCount=3 \
  --set resources.limits.cpu=1000m \
  --set resources.limits.memory=1Gi
```

**Issue**: Policies block legitimate workloads

**Solution**: Use namespace exclusions for system components:

```yaml
rules:
  - name: check-limits
    exclude:
      resources:
        namespaces:
          - kube-system
          - kyverno
          - monitoring
```

**Issue**: Policy Reporter shows no violations but violations exist

**Solution**: Enable background scanning for existing resources:

```yaml
spec:
  background: true  # Scan existing resources, not just new ones
```

**Issue**: Image verification fails for internal registries

**Solution**: Add your internal registry to approved list:

```yaml
pattern:
  spec:
    containers:
      - image: 'gcr.io/* | ghcr.io/org/* | registry.internal.company.com/*'
```

---

## Related Patterns

- **[Advanced Runtime Policies](advanced-policies.md)** - Pod security standards, network policies, quotas
- **[Policy Rollout Strategy](rollout.md)** - Audit-first deployment approach
- **[Phase 3 Overview →](index.md)** - Runtime phase summary

---

*Kyverno deployed. Policies enforced. Pods without limits blocked. Untrusted images rejected. Root containers denied.*
