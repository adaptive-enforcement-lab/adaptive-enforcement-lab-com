---
description: >-
  Fail-secure pattern for Kubernetes. Admission webhooks with safe failure modes, policy enforcement at admission time, and audit logging.
tags:
  - security
  - kubernetes
  - admission-control
  - policy-enforcement
---

# Fail Secure

Fail secure means the system defaults to denying access. Failures default to safe states.

## Core Principle

When security controls fail, the system should deny access rather than allow it.

**Key Properties**:

- Default-deny posture
- Explicit allow rules required
- Failures block operations (don't bypass)
- All decisions audited and logged

## Admission Control

Admission controllers intercept API requests before objects are persisted.

### ValidatingAdmissionWebhook

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: security-policy-validator
webhooks:
- name: validate.security.example.com
  admissionReviewVersions: ["v1", "v1beta1"]
  clientConfig:
    service:
      name: security-webhook
      namespace: security-system
      path: "/validate"
    caBundle: LS0tLS1CRUdJTi... # Base64-encoded CA cert
  failurePolicy: Fail  # CRITICAL: Block on webhook failure
  sideEffects: None
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
  namespaceSelector:
    matchExpressions:
    - key: security-policy
      operator: NotIn
      values: ["exempt"]
```

**Critical Configuration**:

- `failurePolicy: Fail` - Rejects requests if webhook is unavailable
- `sideEffects: None` - Webhook does not modify cluster state
- `namespaceSelector` - Scopes which namespaces are validated

!!! warning "failurePolicy: Ignore Is Dangerous"
    Using `failurePolicy: Ignore` means policies are bypassed when webhooks fail. This defeats the purpose. Use `Fail` in production. Accept temporary deployment blocks over policy bypass.

### Failure Policy Comparison

| Policy | Behavior on Webhook Failure | Use Case |
|--------|----------------------------|----------|
| **Fail** | Rejects all matching requests | Production security policies |
| **Ignore** | Allows all requests through | Development, testing only |

**Security Implication**:

```yaml
failurePolicy: Fail   # Secure: Blocks if webhook down
failurePolicy: Ignore # DANGEROUS: Bypasses policy if webhook down
```

**When to Use Ignore**:

- Never in production for security policies
- Development environments only
- Non-critical validation only

### Webhook Implementation

See [integration.md](integration.md) for complete webhook implementation examples in Go.

## Policy Enforcement Patterns

### Pattern 1: Image Registry Allowlist

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: image-policy
webhooks:
- name: validate.image.example.com
  admissionReviewVersions: ["v1"]
  clientConfig:
    service:
      name: image-validator
      namespace: security-system
      path: "/validate-image"
  failurePolicy: Fail
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: ["", "apps"]
    apiVersions: ["*"]
    resources: ["pods", "deployments", "replicasets"]
```

**Threat Mitigated**: Prevents pulling images from untrusted registries.

### Pattern 2: Resource Quota Enforcement

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: resource-quota-validator
webhooks:
- name: validate.quota.example.com
  admissionReviewVersions: ["v1"]
  clientConfig:
    service:
      name: quota-validator
      namespace: security-system
      path: "/validate-resources"
  failurePolicy: Fail
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
```

**Threat Mitigated**: Prevents resource exhaustion and noisy neighbor problems.

### Pattern 3: Security Context Validation

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: security-context-validator
webhooks:
- name: validate.securitycontext.example.com
  admissionReviewVersions: ["v1"]
  clientConfig:
    service:
      name: security-validator
      namespace: security-system
      path: "/validate-security"
  failurePolicy: Fail
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
```

**What This Enforces**: Pod security contexts, runAsNonRoot, allowPrivilegeEscalation, and readOnlyRootFilesystem requirements.

## MutatingAdmissionWebhook

Mutating webhooks modify objects before admission.

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  name: security-defaults
webhooks:
- name: mutate.security.example.com
  admissionReviewVersions: ["v1"]
  clientConfig:
    service:
      name: security-mutator
      namespace: security-system
      path: "/mutate"
  failurePolicy: Fail
  rules:
  - operations: ["CREATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
```

**Use Case**: Inject security defaults if not specified. Mutate to add secure defaults, then validate with ValidatingWebhook.

## Audit Logging

Audit logs record all API requests for forensics and compliance.

### Audit Policy

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# Log all authentication decisions
- level: RequestResponse
  verbs: ["create", "update", "patch", "delete"]
  resources:
  - group: ""
    resources: ["secrets", "configmaps"]
  - group: "rbac.authorization.k8s.io"
    resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]

# Log pod creation/deletion
- level: Request
  verbs: ["create", "delete"]
  resources:
  - group: ""
    resources: ["pods"]
  - group: "apps"
    resources: ["deployments", "statefulsets", "daemonsets"]

# Log all denials
- level: RequestResponse
  omitStages:
  - RequestReceived
```

**What This Logs**:

- All secret and ConfigMap modifications
- RBAC changes
- Pod creation and deletion
- All admission denials

### Audit Log Analysis

Query denied admissions:

```bash
# Find all denied pod creations
jq 'select(.verb=="create" and .objectRef.resource=="pods" and .responseStatus.code>=400)' \
  /var/log/kubernetes/audit.log

# Find RBAC modifications
jq 'select(.objectRef.apiGroup=="rbac.authorization.k8s.io")' \
  /var/log/kubernetes/audit.log
```

## Webhook High Availability

Admission webhooks are critical. They must be highly available.

### Deployment Configuration

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: security-webhook
  namespace: security-system
spec:
  replicas: 3
  selector:
    matchLabels:
      app: security-webhook
  template:
    metadata:
      labels:
        app: security-webhook
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: security-webhook
            topologyKey: kubernetes.io/hostname
      containers:
      - name: webhook
        image: security-webhook:1.0
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8443
            scheme: HTTPS
          initialDelaySeconds: 5
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /readyz
            port: 8443
            scheme: HTTPS
          initialDelaySeconds: 5
          periodSeconds: 5
```

**High Availability Properties**:

- 3 replicas for redundancy
- Pod anti-affinity (different nodes)
- Liveness and readiness probes
- Resource limits prevent starvation

### PodDisruptionBudget

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: security-webhook-pdb
  namespace: security-system
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: security-webhook
```

**What This Ensures**: At least 2 webhook pods available during node maintenance.

## Testing Admission Webhooks

See [integration.md](integration.md) for complete testing examples including valid/invalid pod tests and webhook failure simulations.

## Common Patterns

### Pattern: Exempt System Namespaces

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: security-policy
webhooks:
- name: validate.security.example.com
  namespaceSelector:
    matchExpressions:
    - key: kubernetes.io/metadata.name
      operator: NotIn
      values: ["kube-system", "kube-public", "kube-node-lease"]
```

**Why**: System components may need privileged access.

## Threat Model

| Threat | Mitigation |
|--------|-----------|
| **Configuration bypass** | failurePolicy: Fail (blocks if webhook down) |
| **Untrusted images** | Image registry allowlist webhook |
| **Privilege escalation** | Security context validation webhook |
| **Resource exhaustion** | Resource quota enforcement webhook |
| **Audit evasion** | Audit policy logs all denials |

## References

- [Admission Controllers](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)
- [Dynamic Admission Control](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/)
- [Audit Logging](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/)
- [PodDisruptionBudget](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/)

---

*Fail secure: deny by default, audit everything, enforce at admission time.*
