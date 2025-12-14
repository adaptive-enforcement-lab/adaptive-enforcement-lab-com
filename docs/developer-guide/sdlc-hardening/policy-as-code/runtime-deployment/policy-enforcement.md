# Policy Enforcement

Deploy policies across environments, configure enforcement modes, enable background scanning, and test in-cluster.

## Policy Deployment

### Using Helm to Deploy Policies

Policies are packaged as Helm charts for multi-environment deployment:

```bash
# Deploy security policies to production
helm upgrade --install security-policy \
  /repos/security-policy/charts/security-policy \
  --namespace kyverno \
  --values /repos/security-policy/cd/prd/values.yaml
```

**Chart structure**:

```text
charts/security-policy/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── require-resource-limits.yaml
    ├── disallow-latest-tag.yaml
    ├── require-labels.yaml
    └── ...
```

**values.yaml** (environment-specific):

```yaml
policies:
  resourceLimits:
    enabled: true
    validationFailureAction: Enforce  # Enforce in prod

  imageTag:
    enabled: true
    allowLatest: false
    validationFailureAction: Enforce

  labels:
    enabled: true
    required:
      - app
      - environment
      - team
    validationFailureAction: Audit  # Warn only
```

### Multi-Environment Deployment

Deploy policies across environments with different enforcement levels:

**Development** (relaxed):

```yaml
policies:
  resourceLimits:
    validationFailureAction: Audit  # Warn only
  imageTag:
    allowLatest: true
```

**Production** (strict):

```yaml
policies:
  resourceLimits:
    validationFailureAction: Enforce  # Block violations
  imageTag:
    allowLatest: false
```

**Deployment command**:

```bash
for env in dev qac stg prd; do
  kubectl config use-context gke-${env}

  helm upgrade --install security-policy \
    /repos/security-policy/charts/security-policy \
    --namespace kyverno \
    --values /repos/security-policy/cd/${env}/values.yaml
done
```

!!! warning "Progressive Strictness"
    Development should be permissive (Audit mode). QAC should catch most violations (Audit with warnings). Staging should match production (Enforce). Production must be strictest (Enforce on all critical policies).

---

## Policy Modes

### Enforce vs Audit

**Enforce** - Block non-compliant resources:

```yaml
spec:
  validationFailureAction: Enforce
```

**Audit** - Log violations, allow deployment:

```yaml
spec:
  validationFailureAction: Audit
```

**Use Audit for**:

- Initial policy rollout
- Low-priority policies
- Gradual adoption

**Use Enforce for**:

- Critical security policies
- Production environments
- Mature policies

!!! tip "Audit First, Enforce Later"
    Deploy every new policy in Audit mode. Monitor PolicyReports for 1-2 weeks. Fix violations in dev/staging. Only then switch to Enforce in production. This prevents breaking existing workloads.

---

## Background Scanning

### Continuous Compliance

Background scans detect policy violations in existing resources:

```yaml
spec:
  background: true  # Enable background scanning
```

**How It Works**:

1. Kyverno scans existing resources every 6 hours
2. Generates PolicyReports for violations
3. Alerts sent via Policy Reporter

**Example PolicyReport**:

```yaml
apiVersion: wgpolicyk8s.io/v1alpha2
kind: PolicyReport
metadata:
  name: polr-ns-default
  namespace: default
results:
  - policy: require-resource-limits
    rule: check-cpu-memory
    result: fail
    scored: true
    severity: medium
    category: Best Practices
    resources:
      - apiVersion: apps/v1
        kind: Deployment
        name: legacy-app
        namespace: default
```

### Background Scan Configuration

```yaml
# kyverno-values.yaml
features:
  backgroundScan:
    backgroundScanInterval: 6h  # Adjust based on cluster size
```

**Recommendations**:

| Cluster Size | Scan Interval | Rationale                          |
| -------------- | --------------- | ------------------------------------- |
| < 100 nodes | 1h           | Fast drift detection               |
| 100-500 nodes | 6h (default) | Balance between load and compliance |
| > 500 nodes | 12h          | Reduce controller load             |

!!! note "Background Scans Generate Reports Only"
    Background scans don't block resources. They generate PolicyReports for existing violations. Use these reports to track compliance drift.

---

## Policy Testing in Cluster

### Dry-Run Deployments

Test policies without actual deployment:

```bash
kubectl apply --dry-run=server -f deployment.yaml
```

**Output** (policy violation):

```text
Error from server: admission webhook "validate.kyverno.svc" denied the request:

policy Deployment/default/nginx for resource violation:

require-resource-limits:
  check-cpu-memory: 'CPU and memory limits required'
```

### Policy Simulation

Test policy changes before deployment:

```bash
# Apply policy in Audit mode first
kubectl apply -f new-policy.yaml

# Check PolicyReports for violations
kubectl get policyreport -A

# Review violations
kubectl describe policyreport polr-ns-default -n default

# Switch to Enforce after validation
kubectl patch clusterpolicy require-resource-limits \
  --type merge \
  -p '{"spec":{"validationFailureAction":"Enforce"}}'
```

!!! tip "Always Test with Dry-Run"
    Before applying any manifest to production, run `kubectl apply --dry-run=server` first. This shows policy violations without risking actual deployments.

---

## Integration with CI/CD

Runtime policies should **match CI policies exactly**:

**CI** (pre-deployment):

```bash
kyverno apply /repos/security-policy/ --resource app.yaml
```

**Runtime** (admission control):

```bash
helm install security-policy /repos/security-policy/charts/security-policy
```

**Same policy source. Zero drift.**

!!! warning "CI and Runtime Must Match"
    If CI validates with policy version v1.0.1 but runtime runs v1.0.2, you get "passes CI, fails production" scenarios. Always deploy same policy versions to CI container and runtime cluster.

---

## Next Steps

- **[Monitoring](monitoring.md)** - Dashboards, metrics, alerts, troubleshooting
- **[Operations](../operations/index.md)** - Policy lifecycle management
- **[CI Integration](../ci-integration/index.md)** - Automated pipeline validation
