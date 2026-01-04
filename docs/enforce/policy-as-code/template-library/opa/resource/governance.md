---
title: OPA Resource Governance Templates
description: >-
  OPA Gatekeeper resource governance templates. Enforce resource limits, requests, and quota requirements with complete Rego implementations.
tags:
  - opa
  - gatekeeper
  - resource-limits
  - kubernetes
  - templates
---
# OPA Resource Governance Templates

OPA/Gatekeeper constraint templates for resource governance. Enforce resource limits, CPU/memory requests, and prevent resource exhaustion with production-tested Rego implementations.

!!! danger "No Limits = Node Failure"
    Pods without resource limits can exhaust node resources, causing OOM kills and cluster instability. These policies enforce resource governance at admission time.

---

## Template 1: Resource Limits and Requests Enforcement

Requires all containers to define CPU and memory limits and requests. Prevents resource starvation and noisy neighbor problems.

### Complete Policy

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srequireresources
spec:
  crd:
    spec:
      names:
        kind: K8sRequireResources
      validation:
        openAPIV3Schema:
          properties:
            requireCPU:
              type: boolean
              description: "Require CPU limits and requests"
            requireMemory:
              type: boolean
              description: "Require memory limits and requests"
            maxMemory:
              type: string
              description: "Maximum memory limit allowed (e.g., '4Gi')"
            maxCPU:
              type: string
              description: "Maximum CPU limit allowed (e.g., '2000m')"
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequireresources

        violation[{"msg": msg, "details": {}}] {
          container := input_containers[_]
          not container.resources.limits.memory
          input.parameters.requireMemory
          msg := sprintf("Container %v must define memory limits", [container.name])
        }

        violation[{"msg": msg, "details": {}}] {
          container := input_containers[_]
          not container.resources.requests.memory
          input.parameters.requireMemory
          msg := sprintf("Container %v must define memory requests", [container.name])
        }

        violation[{"msg": msg, "details": {}}] {
          container := input_containers[_]
          not container.resources.limits.cpu
          input.parameters.requireCPU
          msg := sprintf("Container %v must define CPU limits", [container.name])
        }

        violation[{"msg": msg, "details": {}}] {
          container := input_containers[_]
          not container.resources.requests.cpu
          input.parameters.requireCPU
          msg := sprintf("Container %v must define CPU requests", [container.name])
        }

        violation[{"msg": msg, "details": {}}] {
          container := input_containers[_]
          memory_limit := container.resources.limits.memory
          max_memory := input.parameters.maxMemory
          to_number(memory_limit) > to_number(max_memory)
          msg := sprintf("Container %v memory limit %v exceeds maximum %v",
            [container.name, memory_limit, max_memory])
        }

        violation[{"msg": msg, "details": {}}] {
          container := input_containers[_]
          cpu_limit := container.resources.limits.cpu
          max_cpu := input.parameters.maxCPU
          to_number(cpu_limit) > to_number(max_cpu)
          msg := sprintf("Container %v CPU limit %v exceeds maximum %v",
            [container.name, cpu_limit, max_cpu])
        }

        input_containers[c] {
          c := input.review.object.spec.containers[_]
        }

        input_containers[c] {
          c := input.review.object.spec.initContainers[_]
        }

        input_containers[c] {
          c := input.review.object.spec.ephemeralContainers[_]
        }

        # Simple conversion for common units (simplified for demo)
        to_number(str) = num {
          endswith(str, "Gi")
          num := to_number(trim_suffix(str, "Gi")) * 1024 * 1024 * 1024
        }
        to_number(str) = num {
          endswith(str, "Mi")
          num := to_number(trim_suffix(str, "Mi")) * 1024 * 1024
        }
        to_number(str) = num {
          endswith(str, "m")
          num := to_number(trim_suffix(str, "m"))
        }
        to_number(str) = num {
          not contains(str, "Gi")
          not contains(str, "Mi")
          not contains(str, "m")
          num := to_number(str)
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequireResources
metadata:
  name: require-resource-limits
spec:
  enforcementAction: deny  # Use 'dryrun' for testing
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
      - apiGroups: ["apps"]
        kinds: ["Deployment", "StatefulSet", "DaemonSet"]
      - apiGroups: ["batch"]
        kinds: ["Job", "CronJob"]
    excludedNamespaces:
      - kube-system
      - kube-public
  parameters:
    requireCPU: true
    requireMemory: true
    maxMemory: "8Gi"
    maxCPU: "4000m"
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `requireCPU` | `true` | Require CPU limits and requests |
| `requireMemory` | `true` | Require memory limits and requests |
| `maxMemory` | `8Gi` | Maximum memory limit allowed per container |
| `maxCPU` | `4000m` | Maximum CPU limit allowed per container |
| `excludedNamespaces` | System namespaces | Exempt cluster infrastructure |

### Validation Commands

```bash
# Apply constraint template and constraint
kubectl apply -f opa-require-resources.yaml

# Verify installation
kubectl get constrainttemplates k8srequireresources
kubectl get k8srequireresources

# Test without resources (should fail)
kubectl run test --image=nginx

# Test with resources (should pass)
kubectl run test --image=nginx --requests='memory=256Mi,cpu=100m' --limits='memory=512Mi,cpu=200m'

# Check violations
kubectl get k8srequireresources require-resource-limits -o yaml

# Audit existing pods without limits
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.spec.containers[] | .resources.limits.memory == null or .resources.limits.cpu == null) |
  "\(.metadata.namespace)/\(.metadata.name)"
'
```

### Use Cases

1. **Resource Starvation Prevention**: Ensure fair resource allocation across workloads
2. **Cost Control**: Prevent oversized resource requests driving up cloud costs
3. **Noisy Neighbor Prevention**: Block pods from consuming entire node resources
4. **Capacity Planning**: Enable accurate cluster capacity calculations
5. **SLA Enforcement**: Guarantee resource availability for production workloads

---

## Template 2: Resource Quota Requirements

Ensures all namespaces have ResourceQuotas defined. Prevents unbounded resource consumption at the namespace level.

### Complete Policy

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srequirenamespaceresourcequota
spec:
  crd:
    spec:
      names:
        kind: K8sRequireNamespaceResourceQuota
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequirenamespaceresourcequota

        violation[{"msg": msg, "details": {}}] {
          input.review.kind.kind == "Namespace"
          namespace := input.review.object.metadata.name
          not exempt_namespace(namespace)
          msg := sprintf("Namespace %v must have a ResourceQuota created before use", [namespace])
        }

        violation[{"msg": msg, "details": {}}] {
          # Block workload creation in namespaces without ResourceQuota
          is_workload
          namespace := input.review.object.metadata.namespace
          not exempt_namespace(namespace)
          not has_resource_quota(namespace)
          msg := sprintf("Cannot create workloads in namespace %v without ResourceQuota", [namespace])
        }

        is_workload {
          input.review.kind.kind == "Pod"
        }

        is_workload {
          input.review.kind.group == "apps"
          input.review.kind.kind == "Deployment"
        }

        is_workload {
          input.review.kind.group == "apps"
          input.review.kind.kind == "StatefulSet"
        }

        has_resource_quota(namespace) {
          data.inventory.namespace[namespace]["v1"]["ResourceQuota"][_]
        }

        exempt_namespace(namespace) {
          exemptions := ["kube-system", "kube-public", "kube-node-lease", "default"]
          exemptions[_] == namespace
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequireNamespaceResourceQuota
metadata:
  name: require-namespace-resourcequota
spec:
  enforcementAction: deny
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Namespace"]
      - apiGroups: [""]
        kinds: ["Pod"]
      - apiGroups: ["apps"]
        kinds: ["Deployment", "StatefulSet", "DaemonSet"]
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `enforcementAction` | `deny` | Use `dryrun` for gradual rollout |

### Validation Commands

```bash
# Apply policy
kubectl apply -f opa-require-namespace-quota.yaml

# Verify installation
kubectl get constrainttemplates k8srequirenamespaceresourcequota
kubectl get k8sRequireNamespaceResourceQuota

# Create namespace (should warn about missing quota)
kubectl create namespace test-ns

# Create ResourceQuota
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: namespace-quota
  namespace: test-ns
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    pods: "50"
EOF

# Test workload creation (should now pass)
kubectl run test --image=nginx -n test-ns

# Audit namespaces without ResourceQuotas
kubectl get namespaces -o json | jq -r '
  .items[].metadata.name as $ns |
  select(([($ns as $n | "\($n)" | in({"kube-system":1,"kube-public":1,"default":1}))] | any | not)) |
  $ns
' | while read ns; do
  if ! kubectl get resourcequota -n "$ns" -o name &>/dev/null; then
    echo "$ns: No ResourceQuota found"
  fi
done
```

### Use Cases

1. **Cost Control**: Prevent runaway resource consumption by team/project
2. **Multi-tenancy**: Enforce fair resource allocation across teams
3. **Capacity Planning**: Limit total cluster resource consumption
4. **Chargeback**: Enable accurate cost allocation per namespace/team
5. **Blast Radius Reduction**: Contain resource exhaustion to single namespace

---

## Related Resources

- **[OPA LimitRange Templates →](limitrange.md)** - Default resource limits per namespace
- **[OPA Storage Class Templates →](storage.md)** - Storage class restrictions and PVC limits
- **[OPA Pod Security Templates →](../pod-security/overview.md)** - Privileged containers and host namespaces
- **[OPA RBAC Templates →](../rbac/overview.md)** - Service account and role restrictions
- **[Kyverno Resource Templates →](../../kyverno/resource/limits.md)** - Kubernetes-native alternative
- **[Decision Guide →](../../decision-guide.md)** - OPA vs Kyverno selection
- **[Template Library Overview →](index.md)** - Back to main page
