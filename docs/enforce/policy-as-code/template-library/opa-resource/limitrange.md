---
description: >-
  OPA Gatekeeper LimitRange and ephemeral storage templates. Enforce default resource limits and storage constraints with Rego implementations.
tags:
  - opa
  - gatekeeper
  - limitrange
  - ephemeral-storage
  - kubernetes
  - templates
---

# OPA LimitRange and Ephemeral Storage Templates

OPA/Gatekeeper constraint templates for LimitRange enforcement and ephemeral storage governance. Ensure namespaces have default resource limits and prevent disk exhaustion.

!!! warning "LimitRanges Provide Safety Nets"
    LimitRanges set default resource limits when developers forget. Combined with ResourceQuotas, they form defense-in-depth for resource governance.

---

## Template 3: LimitRange Requirements

Ensures all namespaces have LimitRanges defined. LimitRanges set default limits and prevent extremely large or small resource requests.

### Complete Policy

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srequirelimitrange
spec:
  crd:
    spec:
      names:
        kind: K8sRequireLimitRange
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequirelimitrange

        violation[{"msg": msg, "details": {}}] {
          input.review.kind.kind == "Namespace"
          namespace := input.review.object.metadata.name
          not exempt_namespace(namespace)
          msg := sprintf("Namespace %v should have a LimitRange for default resource limits", [namespace])
        }

        violation[{"msg": msg, "details": {}}] {
          # Block workload creation in namespaces without LimitRange
          is_workload
          namespace := input.review.object.metadata.namespace
          not exempt_namespace(namespace)
          not has_limitrange(namespace)
          msg := sprintf("Namespace %v does not have a LimitRange. Create one before deploying workloads", [namespace])
        }

        is_workload {
          input.review.kind.kind == "Pod"
        }

        is_workload {
          input.review.kind.group == "apps"
          workload_kinds := ["Deployment", "StatefulSet", "DaemonSet"]
          workload_kinds[_] == input.review.kind.kind
        }

        has_limitrange(namespace) {
          data.inventory.namespace[namespace]["v1"]["LimitRange"][_]
        }

        exempt_namespace(namespace) {
          exemptions := ["kube-system", "kube-public", "kube-node-lease", "default"]
          exemptions[_] == namespace
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequireLimitRange
metadata:
  name: require-limitrange
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
| `enforcementAction` | `deny` | Use `dryrun` for audit mode |

### Validation Commands

```bash
# Apply policy
kubectl apply -f opa-require-limitrange.yaml

# Verify installation
kubectl get constrainttemplates k8srequirelimitrange
kubectl get k8srequirelimitrange

# Create namespace
kubectl create namespace test-ns

# Create LimitRange
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: test-ns
spec:
  limits:
    - type: Container
      default:
        cpu: 500m
        memory: 512Mi
      defaultRequest:
        cpu: 100m
        memory: 128Mi
      max:
        cpu: 2000m
        memory: 4Gi
      min:
        cpu: 50m
        memory: 64Mi
    - type: Pod
      max:
        cpu: 4000m
        memory: 8Gi
EOF

# Test workload creation (should pass with LimitRange)
kubectl run test --image=nginx -n test-ns

# Audit namespaces without LimitRanges
kubectl get namespaces -o json | jq -r '.items[].metadata.name' | \
  grep -v -E '^(kube-system|kube-public|default)$' | \
  while read ns; do
    if ! kubectl get limitrange -n "$ns" -o name 2>/dev/null | grep -q .; then
      echo "$ns: No LimitRange found"
    fi
  done
```

### Use Cases

1. **Default Resource Limits**: Automatically set limits when developers forget
2. **Prevent Oversized Requests**: Block extremely large resource requests
3. **Cost Control**: Enforce maximum resource consumption per container/pod
4. **Developer Experience**: Reduce policy violations through automatic defaults
5. **Compliance**: Demonstrate resource governance controls for audits

---

## Template 4: Ephemeral Storage Limits

Requires all containers to define ephemeral storage limits. Ephemeral storage includes writable container layers, logs, and emptyDir volumes.

### Complete Policy

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srequireephemeralstorage
spec:
  crd:
    spec:
      names:
        kind: K8sRequireEphemeralStorage
      validation:
        openAPIV3Schema:
          properties:
            maxEphemeralStorage:
              type: string
              description: "Maximum ephemeral storage limit (e.g., '10Gi')"
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequireephemeralstorage

        violation[{"msg": msg, "details": {}}] {
          container := input_containers[_]
          not container.resources.limits["ephemeral-storage"]
          msg := sprintf("Container %v must define ephemeral-storage limits", [container.name])
        }

        violation[{"msg": msg, "details": {}}] {
          container := input_containers[_]
          not container.resources.requests["ephemeral-storage"]
          msg := sprintf("Container %v must define ephemeral-storage requests", [container.name])
        }

        violation[{"msg": msg, "details": {}}] {
          container := input_containers[_]
          storage_limit := container.resources.limits["ephemeral-storage"]
          max_storage := input.parameters.maxEphemeralStorage
          to_bytes(storage_limit) > to_bytes(max_storage)
          msg := sprintf("Container %v ephemeral-storage limit %v exceeds maximum %v",
            [container.name, storage_limit, max_storage])
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

        # Convert storage units to bytes
        to_bytes(str) = num {
          endswith(str, "Ti")
          num := to_number(trim_suffix(str, "Ti")) * 1024 * 1024 * 1024 * 1024
        }
        to_bytes(str) = num {
          endswith(str, "Gi")
          num := to_number(trim_suffix(str, "Gi")) * 1024 * 1024 * 1024
        }
        to_bytes(str) = num {
          endswith(str, "Mi")
          num := to_number(trim_suffix(str, "Mi")) * 1024 * 1024
        }
        to_bytes(str) = num {
          endswith(str, "Ki")
          num := to_number(trim_suffix(str, "Ki")) * 1024
        }
        to_bytes(str) = num {
          not contains(str, "i")
          num := to_number(str)
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequireEphemeralStorage
metadata:
  name: require-ephemeral-storage-limits
spec:
  enforcementAction: deny
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
  parameters:
    maxEphemeralStorage: "20Gi"
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `maxEphemeralStorage` | `20Gi` | Maximum ephemeral storage per container |
| `excludedNamespaces` | System namespaces | Exempt cluster infrastructure |

### Validation Commands

```bash
# Apply policy
kubectl apply -f opa-require-ephemeral-storage.yaml

# Verify installation
kubectl get constrainttemplates k8srequireephemeralstorage
kubectl get k8srequireephemeralstorage

# Test without ephemeral storage limits (should fail)
kubectl run test --image=nginx

# Test with ephemeral storage limits (should pass)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test
spec:
  containers:
    - name: nginx
      image: nginx
      resources:
        limits:
          ephemeral-storage: "2Gi"
        requests:
          ephemeral-storage: "1Gi"
EOF

# Check violations
kubectl get k8srequireephemeralstorage require-ephemeral-storage-limits -o yaml

# Audit pods without ephemeral storage limits
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.spec.containers[] | .resources.limits["ephemeral-storage"] == null) |
  "\(.metadata.namespace)/\(.metadata.name)"
'
```

### Use Cases

1. **Node Disk Protection**: Prevent pods from filling node disk space
2. **Log Flooding Prevention**: Limit log volume from verbose applications
3. **Build Job Safety**: Constrain disk usage from CI/CD build containers
4. **EmptyDir Protection**: Prevent unbounded emptyDir volume growth
5. **Node Stability**: Avoid node evictions from disk pressure

---

## Related Resources

- **[OPA Resource Governance Templates →](opa-resource-governance.md)** - Resource limits and quota enforcement
- **[OPA Storage Class Templates →](opa-resource-storage.md)** - Storage class restrictions and PVC limits
- **[OPA Pod Security Templates →](opa-pod-security.md)** - Privileged containers and host namespaces
- **[Kyverno Resource Templates →](kyverno-resource-storage.md)** - Kubernetes-native alternative
- **[Decision Guide →](decision-guide.md)** - OPA vs Kyverno selection
- **[Template Library Overview →](index.md)** - Back to main page
