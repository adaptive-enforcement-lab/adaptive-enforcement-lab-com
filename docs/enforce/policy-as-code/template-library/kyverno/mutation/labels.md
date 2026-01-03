---
description: >-
  Automatically add required labels to Kubernetes workloads with Kyverno mutation policies ensuring consistent metadata and resource governance.
tags:
  - kyverno
  - mutation
  - labels
  - kubernetes
  - templates
---

# Kyverno Mutation Templates: Labels

Automatically injects required labels into Kubernetes resources. Ensures consistent metadata without requiring manual configuration in every manifest.

!!! tip "Mutation vs Validation"
    Mutations fix resources before admission. Validation blocks non-compliant resources. Use mutations to reduce friction while enforcing standards.

---

## Template 1: Default Label Injection

Automatically adds required labels to all workloads. Enforces organizational standards without blocking deployments.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-default-labels
  namespace: kyverno
spec:
  background: false  # Mutations only apply to CREATE/UPDATE operations
  rules:
    - name: add-team-label
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
            - CronJob
      exclude:
        resources:
          namespaces:
            - kube-system
            - kube-public
            - kube-node-lease
      mutate:
        patchStrategicMerge:
          metadata:
            labels:
              +(team): "{{ request.object.metadata.namespace }}"
              +(managed-by): "kyverno"
              +(environment): "{{ request.object.metadata.namespace | split(@, '-') | [-1] }}"
    - name: add-app-version-label
      match:
        resources:
          kinds:
            - Deployment
            - StatefulSet
            - DaemonSet
      exclude:
        resources:
          namespaces:
            - kube-system
      mutate:
        patchStrategicMerge:
          metadata:
            labels:
              +(app.kubernetes.io/version): "{{ request.object.spec.template.spec.containers[0].image | split(@, ':') | [-1] }}"
          spec:
            template:
              metadata:
                labels:
                  +(app.kubernetes.io/version): "{{ request.object.spec.template.spec.containers[0].image | split(@, ':') | [-1] }}"
    - name: add-network-policy-labels
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
      exclude:
        resources:
          namespaces:
            - kube-system
          selector:
            matchExpressions:
              - key: app
                operator: Exists
      preconditions:
        all:
          - key: "{{ request.object.metadata.labels.app || '' }}"
            operator: Equals
            value: ""
      mutate:
        patchStrategicMerge:
          metadata:
            labels:
              +(app): "{{ request.object.metadata.name }}"
          spec:
            (template)?:
              metadata:
                labels:
                  +(app): "{{ request.object.metadata.name }}"
    - name: add-cost-center-from-namespace
      match:
        resources:
          kinds:
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
            - CronJob
      exclude:
        resources:
          namespaces:
            - kube-system
            - kube-public
            - default
      context:
        - name: namespace_labels
          apiCall:
            urlPath: "/api/v1/namespaces/{{ request.namespace }}"
            jmesPath: "metadata.labels"
      mutate:
        patchStrategicMerge:
          metadata:
            labels:
              +(cost-center): "{{ namespace_labels.\"cost-center\" || 'unassigned' }}"
              +(business-unit): "{{ namespace_labels.\"business-unit\" || 'engineering' }}"
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `team-label-source` | `namespace` | Extract team from namespace or annotations |
| `environment-extraction` | Last segment after `-` | Parse environment from namespace name |
| `version-source` | Image tag | Extract version from container image |
| `cost-center-fallback` | `unassigned` | Default when namespace lacks cost-center label |
| `exclude-namespaces` | System namespaces | Skip mutation for infrastructure namespaces |

### Validation Commands

```bash
# Apply policy
kubectl apply -f add-default-labels-policy.yaml

# Create deployment without labels
kubectl create deployment nginx --image=nginx:1.21 -n default

# Verify labels were added
kubectl get deployment nginx -n default -o jsonpath='{.metadata.labels}' | jq

# Expected output includes:
# {
#   "app": "nginx",
#   "team": "default",
#   "managed-by": "kyverno",
#   "environment": "default",
#   "app.kubernetes.io/version": "1.21",
#   "cost-center": "unassigned",
#   "business-unit": "engineering"
# }

# Create namespace with cost-center label
kubectl create namespace production
kubectl label namespace production cost-center=eng-platform business-unit=platform

# Deploy to labeled namespace
kubectl create deployment app --image=app:v1.0.0 -n production

# Verify cost-center inherited from namespace
kubectl get deployment app -n production -o jsonpath='{.metadata.labels.cost-center}'

# Audit resources that had labels added
kubectl logs -n kyverno deployment/kyverno | grep "add-default-labels"

# List all resources by cost-center
kubectl get deployments -A -o json | jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name): \(.metadata.labels."cost-center" // "NO-COST-CENTER")"'
```

### Use Cases

1. **Cost Attribution**: Automatically tag resources with cost-center from namespace annotations
2. **Network Policy Automation**: Ensure all pods have required labels for NetworkPolicy selectors
3. **Compliance Reporting**: Auto-label resources with team and environment for audit trails
4. **Version Tracking**: Extract application version from container image tags automatically
5. **Multi-tenant Governance**: Enforce organizational metadata standards without manual intervention
6. **Incident Response**: Quickly identify resource ownership through consistent labeling

---

## Template 2: Namespace Label Propagation

Propagates namespace labels to all resources created within the namespace. Enables hierarchical metadata management.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: propagate-namespace-labels
  namespace: kyverno
spec:
  background: false
  rules:
    - name: sync-namespace-labels-to-pods
      match:
        resources:
          kinds:
            - Pod
      exclude:
        resources:
          namespaces:
            - kube-system
            - kube-public
      context:
        - name: namespace_labels
          apiCall:
            urlPath: "/api/v1/namespaces/{{ request.namespace }}"
            jmesPath: "metadata.labels"
      mutate:
        patchStrategicMerge:
          metadata:
            labels:
              +(propagate.kubernetes.io/team): "{{ namespace_labels.team || '' }}"
              +(propagate.kubernetes.io/environment): "{{ namespace_labels.environment || '' }}"
              +(propagate.kubernetes.io/owner): "{{ namespace_labels.owner || '' }}"
              +(propagate.kubernetes.io/project): "{{ namespace_labels.project || '' }}"
    - name: sync-namespace-labels-to-services
      match:
        resources:
          kinds:
            - Service
      exclude:
        resources:
          namespaces:
            - kube-system
            - kube-public
            - default
      context:
        - name: namespace_labels
          apiCall:
            urlPath: "/api/v1/namespaces/{{ request.namespace }}"
            jmesPath: "metadata.labels"
      mutate:
        patchStrategicMerge:
          metadata:
            labels:
              +(propagate.kubernetes.io/team): "{{ namespace_labels.team || '' }}"
              +(propagate.kubernetes.io/sla): "{{ namespace_labels.sla || 'standard' }}"
    - name: sync-compliance-labels
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
      context:
        - name: namespace_labels
          apiCall:
            urlPath: "/api/v1/namespaces/{{ request.namespace }}"
            jmesPath: "metadata.labels"
      preconditions:
        all:
          - key: "{{ namespace_labels.\"compliance.pci-dss\" || 'false' }}"
            operator: Equals
            value: "true"
      mutate:
        patchStrategicMerge:
          metadata:
            labels:
              +(compliance.pci-dss): "true"
              +(data-classification): "restricted"
          spec:
            (template)?:
              metadata:
                labels:
                  +(compliance.pci-dss): "true"
                  +(data-classification): "restricted"
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `label-prefix` | `propagate.kubernetes.io/` | Namespace for propagated labels |
| `propagated-labels` | `team`, `environment`, `owner`, `project` | Labels to copy from namespace |
| `compliance-labels` | `compliance.pci-dss`, `data-classification` | Security/compliance metadata |
| `sla-default` | `standard` | Fallback SLA tier |

### Validation Commands

```bash
# Apply policy
kubectl apply -f propagate-namespace-labels-policy.yaml

# Create namespace with labels
kubectl create namespace my-app
kubectl label namespace my-app \
  team=platform \
  environment=production \
  owner=platform-team \
  project=core-services \
  sla=critical \
  compliance.pci-dss=true

# Deploy workload
kubectl create deployment app --image=nginx -n my-app

# Verify labels propagated
kubectl get deployment app -n my-app -o yaml | grep -A 10 "labels:"

# Check pod labels
kubectl get pods -n my-app -o jsonpath='{.items[0].metadata.labels}' | jq

# List all pods with compliance label
kubectl get pods -A -l compliance.pci-dss=true

# Audit label propagation
kubectl get deployments -A -o json | jq -r '.items[] | select(.metadata.labels."propagate.kubernetes.io/team") | "\(.metadata.namespace)/\(.metadata.name): team=\(.metadata.labels."propagate.kubernetes.io/team")"'
```

### Use Cases

1. **Centralized Governance**: Manage metadata at namespace level, auto-apply to all resources
2. **Compliance Tagging**: Automatically mark resources in PCI-DSS namespaces with compliance labels
3. **Team Attribution**: Inherit team ownership from namespace without per-resource configuration
4. **SLA Enforcement**: Propagate service-level requirements from namespace to services
5. **Cost Allocation**: Simplify chargeback by inheriting project/cost-center from namespace
6. **Security Posture**: Automatically tag resources in high-security namespaces for monitoring

---

## Related Resources

- **[Kyverno Network Security →](../network/security.md)** - NetworkPolicy requirements (needs app labels)
- **[Kyverno Generation - Namespaces →](../generation/namespace.md)** - ResourceQuota and NetworkPolicy generation
- **[Kyverno Pod Security →](../pod-security/standards.md)** - Security contexts and capabilities
- **[Kyverno Labels →](../labels.md)** - Label validation policies
- **[Template Library Overview →](index.md)** - Back to main page
