---
description: >-
  Auto-generate ResourceQuotas and NetworkPolicies for new Kubernetes namespaces with Kyverno generation policies enforcing security by default.
tags:
  - kyverno
  - generation
  - namespace
  - resourcequota
  - network-policy
  - kubernetes
  - templates
---

# Kyverno Generation Templates: Namespace Resources

Automatically generates ResourceQuotas, NetworkPolicies, and LimitRanges when namespaces are created. Enforces security and resource governance by default.

!!! danger "Namespaces Without Quotas Enable Resource Exhaustion"
    New namespaces without ResourceQuotas can consume unlimited cluster resources. Generation policies enforce quotas on creation.

---

## Template 1: Automatic ResourceQuota Generation

Generates ResourceQuota objects for every new namespace. Prevents unbounded resource consumption.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: generate-namespace-resourcequota
  namespace: kyverno
spec:
  background: false
  rules:
    - name: generate-default-quota
      match:
        resources:
          kinds:
            - Namespace
      exclude:
        resources:
          names:
            - kube-system
            - kube-public
            - kube-node-lease
            - default
            - kyverno
      generate:
        synchronize: true
        apiVersion: v1
        kind: ResourceQuota
        name: default-quota
        namespace: "{{ request.object.metadata.name }}"
        data:
          spec:
            hard:
              requests.cpu: "10"
              requests.memory: "20Gi"
              limits.cpu: "20"
              limits.memory: "40Gi"
              persistentvolumeclaims: "10"
              services.loadbalancers: "2"
              services.nodeports: "5"
              pods: "50"
    - name: generate-object-count-quota
      match:
        resources:
          kinds:
            - Namespace
      exclude:
        resources:
          names:
            - kube-system
            - kube-public
            - kube-node-lease
            - default
      generate:
        synchronize: true
        apiVersion: v1
        kind: ResourceQuota
        name: object-count-quota
        namespace: "{{ request.object.metadata.name }}"
        data:
          spec:
            hard:
              count/deployments.apps: "20"
              count/statefulsets.apps: "10"
              count/jobs.batch: "50"
              count/cronjobs.batch: "10"
              count/services: "20"
              count/secrets: "50"
              count/configmaps: "50"
    - name: generate-production-quota
      match:
        resources:
          kinds:
            - Namespace
          selector:
            matchLabels:
              environment: "production"
      generate:
        synchronize: true
        apiVersion: v1
        kind: ResourceQuota
        name: production-quota
        namespace: "{{ request.object.metadata.name }}"
        data:
          spec:
            hard:
              requests.cpu: "50"
              requests.memory: "100Gi"
              limits.cpu: "100"
              limits.memory: "200Gi"
              persistentvolumeclaims: "50"
              services.loadbalancers: "5"
              pods: "200"
            scopeSelector:
              matchExpressions:
                - operator: In
                  scopeName: PriorityClass
                  values:
                    - high-priority
                    - critical
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `default-cpu-requests` | `10` cores | CPU request quota for development namespaces |
| `default-memory-requests` | `20Gi` | Memory request quota for development namespaces |
| `production-cpu-requests` | `50` cores | CPU request quota for production namespaces |
| `production-memory-requests` | `100Gi` | Memory request quota for production namespaces |
| `max-loadbalancers` | `2` (dev) / `5` (prod) | Limit expensive cloud resources |
| `max-pods` | `50` (dev) / `200` (prod) | Pod count limits per namespace |
| `synchronize` | `true` | Keep quota in sync with policy changes |

### Validation Commands

```bash
# Apply policy
kubectl apply -f generate-resourcequota-policy.yaml

# Create namespace (triggers quota generation)
kubectl create namespace test-quota

# Verify ResourceQuotas were created
kubectl get resourcequotas -n test-quota

# Expected output:
# NAME                  AGE     REQUEST   LIMIT
# default-quota         10s     ...       ...
# object-count-quota    10s     ...       ...

# View quota details
kubectl describe resourcequota default-quota -n test-quota

# Create production namespace with label
kubectl create namespace production-app
kubectl label namespace production-app environment=production

# Verify production quota created
kubectl get resourcequota production-quota -n production-app

# Test quota enforcement
kubectl run test --image=nginx -n test-quota --replicas=60  # Should fail (exceeds pod quota)

# Audit namespaces without quotas
kubectl get namespaces -o json | jq -r '.items[] | select(.metadata.name != "kube-system") | .metadata.name' | while read ns; do
  quota_count=$(kubectl get resourcequotas -n $ns --no-headers 2>/dev/null | wc -l)
  if [ $quota_count -eq 0 ]; then
    echo "WARNING: Namespace $ns has no ResourceQuota"
  fi
done

# Monitor quota usage
kubectl get resourcequotas -A -o json | jq -r '.items[] | "\(.metadata.namespace): CPU=\(.status.used."requests.cpu" // "0")/\(.spec.hard."requests.cpu") MEM=\(.status.used."requests.memory" // "0")/\(.spec.hard."requests.memory")"'
```

### Use Cases

1. **Cost Control**: Automatically limit resource consumption in new namespaces
2. **Blast Radius Limitation**: Prevent runaway workloads from consuming entire cluster
3. **Multi-tenant Fairness**: Enforce equitable resource distribution across teams
4. **Environment Tiering**: Different quota limits for dev, staging, production
5. **LoadBalancer Cost Management**: Cap expensive cloud resources per namespace
6. **Object Count Limits**: Prevent namespace sprawl and excessive API load

---

## Template 2: Default-Deny NetworkPolicy Generation

Generates default-deny NetworkPolicy for all new namespaces. Enforces zero-trust networking from creation.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: generate-default-deny-networkpolicy
  namespace: kyverno
spec:
  background: false
  rules:
    - name: generate-deny-all-ingress
      match:
        resources:
          kinds:
            - Namespace
      exclude:
        resources:
          names:
            - kube-system
            - kube-public
            - kube-node-lease
            - default
      generate:
        synchronize: true
        apiVersion: networking.k8s.io/v1
        kind: NetworkPolicy
        name: default-deny-ingress
        namespace: "{{ request.object.metadata.name }}"
        data:
          spec:
            podSelector: {}
            policyTypes:
              - Ingress
    - name: generate-deny-all-egress
      match:
        resources:
          kinds:
            - Namespace
          selector:
            matchLabels:
              network-policy: "strict"
      generate:
        synchronize: true
        apiVersion: networking.k8s.io/v1
        kind: NetworkPolicy
        name: default-deny-egress
        namespace: "{{ request.object.metadata.name }}"
        data:
          spec:
            podSelector: {}
            policyTypes:
              - Egress
    - name: generate-allow-dns-egress
      match:
        resources:
          kinds:
            - Namespace
      exclude:
        resources:
          names:
            - kube-system
            - kube-public
            - kube-node-lease
            - default
      generate:
        synchronize: true
        apiVersion: networking.k8s.io/v1
        kind: NetworkPolicy
        name: allow-dns-egress
        namespace: "{{ request.object.metadata.name }}"
        data:
          spec:
            podSelector: {}
            policyTypes:
              - Egress
            egress:
              - to:
                  - namespaceSelector:
                      matchLabels:
                        name: kube-system
                ports:
                  - protocol: UDP
                    port: 53
    - name: generate-allow-same-namespace
      match:
        resources:
          kinds:
            - Namespace
          selector:
            matchLabels:
              network-policy: "namespace-isolation"
      generate:
        synchronize: true
        apiVersion: networking.k8s.io/v1
        kind: NetworkPolicy
        name: allow-same-namespace
        namespace: "{{ request.object.metadata.name }}"
        data:
          spec:
            podSelector: {}
            policyTypes:
              - Ingress
            ingress:
              - from:
                  - podSelector: {}
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `default-ingress-policy` | `deny-all` | Default ingress behavior |
| `default-egress-policy` | `allow-dns` | Default egress behavior |
| `strict-namespaces` | Label-based | Namespaces requiring egress blocking |
| `allow-same-namespace` | Label-based | Automatically allow intra-namespace traffic |
| `synchronize` | `true` | Update policies when namespace labels change |

### Validation Commands

```bash
# Apply policy
kubectl apply -f generate-networkpolicy-policy.yaml

# Create namespace (triggers NetworkPolicy generation)
kubectl create namespace test-netpol

# Verify NetworkPolicies created
kubectl get networkpolicies -n test-netpol

# Expected output:
# NAME                     POD-SELECTOR   AGE
# default-deny-ingress     <none>         10s
# allow-dns-egress         <none>         10s

# View policy details
kubectl describe networkpolicy default-deny-ingress -n test-netpol

# Create strict namespace with egress blocking
kubectl create namespace strict-app
kubectl label namespace strict-app network-policy=strict
kubectl get networkpolicy default-deny-egress -n strict-app

# Test NetworkPolicy enforcement
kubectl run test-source --image=nginx -n test-netpol
kubectl exec -n test-netpol test-source -- nslookup kubernetes.default  # Should succeed (DNS allowed)

# Audit namespaces without NetworkPolicies
kubectl get namespaces -o json | jq -r '.items[] | select(.metadata.name != "kube-system") | .metadata.name' | while read ns; do
  netpol_count=$(kubectl get networkpolicies -n $ns --no-headers 2>/dev/null | wc -l)
  if [ $netpol_count -eq 0 ]; then
    echo "WARNING: Namespace $ns has no NetworkPolicies"
  fi
done
```

### Use Cases

1. **Zero Trust Networking**: Default-deny posture for all new namespaces
2. **Compliance Requirements**: Automatic network isolation for regulated workloads
3. **Lateral Movement Prevention**: Block cross-namespace traffic unless explicitly allowed
4. **DNS-Only Egress**: Permit DNS while blocking external communication by default
5. **Multi-tenant Isolation**: Guarantee network separation between teams/projects
6. **Incremental Allow-Listing**: Start with deny-all, add explicit allow rules as needed

---

## Related Resources

- **[Kyverno Network Security →](../kyverno-network/security.md)** - NetworkPolicy validation
- **[Kyverno Resource Limits →](../kyverno-resource/limits.md)** - Resource quota validation
- **[Kyverno Mutation - Labels →](../kyverno-mutation/labels.md)** - Auto-label resources
- **[Kyverno Generation - Workload Resources →](workload.md)** - PodDisruptionBudget generation
- **[Template Library Overview →](../index.md)** - Back to main page
