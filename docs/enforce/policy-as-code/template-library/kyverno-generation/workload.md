---
description: >-
  Auto-generate PodDisruptionBudgets for high-availability Kubernetes workloads with Kyverno generation policies ensuring resilience during disruptions.
tags:
  - kyverno
  - generation
  - poddisruptionbudget
  - high-availability
  - kubernetes
  - templates
---

# Kyverno Generation Templates: Workload Resources

Automatically generates PodDisruptionBudgets (PDBs) for high-availability workloads. Ensures resilience during node maintenance and cluster upgrades.

!!! danger "No PDB Equals Downtime During Upgrades"
    Without PodDisruptionBudgets, cluster upgrades can drain all pods simultaneously. PDBs enforce minimum availability during voluntary disruptions.

---

## Template 1: Automatic PodDisruptionBudget Generation

Generates PodDisruptionBudgets for Deployments and StatefulSets with 2+ replicas. Prevents accidental downtime during maintenance.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: generate-poddisruptionbudget
  namespace: kyverno
spec:
  background: false
  rules:
    - name: generate-pdb-for-deployments
      match:
        resources:
          kinds:
            - Deployment
      exclude:
        resources:
          namespaces:
            - kube-system
            - kube-public
          selector:
            matchExpressions:
              - key: skip-pdb
                operator: Exists
      preconditions:
        all:
          - key: "{{ request.object.spec.replicas }}"
            operator: GreaterThanOrEquals
            value: 2
      generate:
        synchronize: true
        apiVersion: policy/v1
        kind: PodDisruptionBudget
        name: "{{ request.object.metadata.name }}-pdb"
        namespace: "{{ request.namespace }}"
        data:
          spec:
            minAvailable: 1
            selector:
              matchLabels:
                app: "{{ request.object.spec.template.metadata.labels.app }}"
    - name: generate-pdb-for-statefulsets
      match:
        resources:
          kinds:
            - StatefulSet
      exclude:
        resources:
          namespaces:
            - kube-system
          selector:
            matchExpressions:
              - key: skip-pdb
                operator: Exists
      preconditions:
        all:
          - key: "{{ request.object.spec.replicas }}"
            operator: GreaterThanOrEquals
            value: 2
      generate:
        synchronize: true
        apiVersion: policy/v1
        kind: PodDisruptionBudget
        name: "{{ request.object.metadata.name }}-pdb"
        namespace: "{{ request.namespace }}"
        data:
          spec:
            maxUnavailable: 1
            selector:
              matchLabels:
                app: "{{ request.object.spec.template.metadata.labels.app }}"
    - name: generate-pdb-production-strict
      match:
        resources:
          kinds:
            - Deployment
            - StatefulSet
          selector:
            matchLabels:
              sla: "critical"
      preconditions:
        all:
          - key: "{{ request.object.spec.replicas }}"
            operator: GreaterThanOrEquals
            value: 3
      generate:
        synchronize: true
        apiVersion: policy/v1
        kind: PodDisruptionBudget
        name: "{{ request.object.metadata.name }}-critical-pdb"
        namespace: "{{ request.namespace }}"
        data:
          spec:
            minAvailable: "50%"
            selector:
              matchLabels:
                app: "{{ request.object.spec.template.metadata.labels.app }}"
    - name: generate-pdb-with-unhealthy-threshold
      match:
        resources:
          kinds:
            - Deployment
          selector:
            matchLabels:
              generate-pdb: "true"
      preconditions:
        all:
          - key: "{{ request.object.spec.replicas }}"
            operator: GreaterThanOrEquals
            value: 5
      generate:
        synchronize: true
        apiVersion: policy/v1
        kind: PodDisruptionBudget
        name: "{{ request.object.metadata.name }}-pdb"
        namespace: "{{ request.namespace }}"
        data:
          spec:
            maxUnavailable: "25%"
            unhealthyPodEvictionPolicy: IfHealthyBudget
            selector:
              matchLabels:
                app: "{{ request.object.spec.template.metadata.labels.app }}"
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `min-replicas-for-pdb` | `2` | Minimum replicas to trigger PDB generation |
| `default-min-available` | `1` | Minimum pods available during disruption |
| `default-max-unavailable` | `1` | Maximum pods unavailable during disruption |
| `critical-min-available` | `50%` | Availability for critical workloads |
| `unhealthy-eviction-policy` | `IfHealthyBudget` | Eviction behavior for unhealthy pods |
| `synchronize` | `true` | Update PDB when Deployment changes |

### Validation Commands

```bash
# Apply policy
kubectl apply -f generate-pdb-policy.yaml

# Create deployment with 2+ replicas
kubectl create deployment nginx --image=nginx --replicas=3 -n default
kubectl label deployment nginx app=nginx

# Verify PDB was created
kubectl get poddisruptionbudgets -n default

# Expected output:
# NAME         MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
# nginx-pdb    1               N/A               2                     10s

# View PDB details
kubectl describe pdb nginx-pdb -n default

# Create critical deployment
kubectl create deployment critical-app --image=app:latest --replicas=5 -n default
kubectl label deployment critical-app app=critical-app sla=critical

# Verify critical PDB created with 50% minAvailable
kubectl get pdb critical-app-critical-pdb -n default -o yaml

# Test disruption protection (simulate node drain)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Verify PDB prevents draining all pods
kubectl get events -n default | grep "Cannot evict"

# Create single-replica deployment (should NOT generate PDB)
kubectl create deployment single --image=nginx --replicas=1 -n default

# Verify no PDB created
kubectl get pdb -n default | grep single  # Should return nothing

# Opt-out of PDB generation
kubectl create deployment opt-out --image=nginx --replicas=3 -n default
kubectl label deployment opt-out skip-pdb=true

# Verify no PDB created for opt-out
kubectl get pdb -n default | grep opt-out  # Should return nothing

# Audit workloads without PDBs
kubectl get deployments -A -o json | jq -r '.items[] | select(.spec.replicas >= 2) | "\(.metadata.namespace)/\(.metadata.name): replicas=\(.spec.replicas)"' | while read workload; do
  ns=$(echo $workload | cut -d'/' -f1)
  name=$(echo $workload | cut -d':' -f1 | cut -d'/' -f2)
  pdb_count=$(kubectl get pdb -n $ns -o json | jq -r --arg name "$name" '.items[] | select(.spec.selector.matchLabels.app == $name) | .metadata.name' | wc -l)
  if [ $pdb_count -eq 0 ]; then
    echo "WARNING: $workload has no PDB"
  fi
done
```

### Use Cases

1. **Zero-Downtime Upgrades**: Ensure availability during cluster node upgrades
2. **SLA Compliance**: Enforce minimum availability for critical services
3. **Automated Resilience**: Generate PDBs without manual configuration
4. **Blast Radius Control**: Prevent mass pod evictions during maintenance
5. **Cluster Autoscaling**: Prevent autoscaler from draining too many pods simultaneously
6. **Disaster Recovery**: Maintain service during partial cluster failures

---

## Related Resources

- **[Kyverno Resource Limits →](../kyverno-resource-limits.md)** - Resource requests and limits
- **[Kyverno Resource HPA →](../kyverno-resource-hpa.md)** - HorizontalPodAutoscaler requirements
- **[Kyverno Generation - Namespaces →](namespace.md)** - ResourceQuota and NetworkPolicy generation
- **[Kyverno Pod Security →](../kyverno-pod-security.md)** - Security contexts and capabilities
- **[Template Library Overview →](../index.md)** - Back to main page
