---
title: Monitoring and Compliance
description: >-
  Track policy compliance with Prometheus metrics, Slack alerts, and Policy Reporter dashboards. Manage exceptions and troubleshoot Kyverno enforcement.
---
# Monitoring and Compliance

Track policy compliance, manage exceptions, troubleshoot issues, and generate audit evidence.

## Monitoring Compliance

### Policy Reporter Dashboard

Access compliance dashboard:

```bash
kubectl port-forward -n policy-reporter svc/policy-reporter-ui 8080:8080
```

**Metrics displayed**:

- Pass/Fail by policy
- Violations by namespace
- Trend over time
- Top violating resources

### Prometheus Metrics

Query policy metrics:

```promql
# Total violations
sum(policy_report_result{status="fail"})

# Violations by policy
sum(policy_report_result{status="fail"}) by (policy)

# Compliance rate
sum(policy_report_result{status="pass"}) / sum(policy_report_result)
```

### Slack Alerts

Configure critical policy alerts:

```yaml
# policy-reporter-values.yaml
targets:
  slack:
    webhook: "https://hooks.slack.com/services/XXX"
    minimumPriority: "critical"
    channels:
      - name: "#security-alerts"
        filter:
          policies:
            include:
              - "disallow-privileged"
              - "require-network-policy"
          namespaces:
            include: ["production"]
```

**Alert format**:

```text
🚨 Policy Violation in production
Policy: disallow-privileged
Resource: Deployment/nginx
Namespace: production
Message: Privileged containers not allowed
```

!!! tip "Alert on Critical Policies Only"
    Don't alert on every policy violation. Reserve alerts for security-critical policies in production. Use dashboards for everything else.

---

## Exception Management

### Temporary Exceptions

Allow specific resources to bypass policies:

```yaml
apiVersion: kyverno.io/v2beta1
kind: PolicyException
metadata:
  name: allow-legacy-app-no-limits
  namespace: kyverno
spec:
  exceptions:
    - policyName: require-resource-limits
      ruleNames:
        - check-cpu-memory
  match:
    any:
      - resources:
          kinds: [Deployment]
          namespaces: [legacy]
          names: [old-app]
  # Temporary - expires in 90 days
  validUntil: "2025-03-08T00:00:00Z"
```

**Track exceptions**:

```bash
# List all exceptions
kubectl get policyexception -A

# Check expiration dates
kubectl get policyexception -A \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.validUntil}{"\n"}{end}'
```

### Exception Governance

**Policy for exceptions**:

1. Must have expiration date
2. Require JIRA ticket reference
3. Approval from security team
4. Quarterly review

**Annotation pattern**:

```yaml
metadata:
  annotations:
    jira.ticket: "SEC-1234"
    approved-by: "security-team"
    reason: "Legacy application, migration planned"
```

!!! warning "Exceptions Must Expire"
    Every PolicyException must have `validUntil` set. Exceptions without expiration dates create permanent security gaps.

---

## Troubleshooting

### Policy Not Enforcing

**Problem**: Resource deployed despite policy violation

**Debug steps**:

```bash
# 1. Check policy exists
kubectl get clusterpolicy require-resource-limits

# 2. Check validation failure action
kubectl get clusterpolicy require-resource-limits \
  -o jsonpath='{.spec.validationFailureAction}'

# Expected: Enforce
# If Audit: Policy warns only

# 3. Check if exception exists
kubectl get policyexception -A \
  | grep require-resource-limits
```

**Solution**: Ensure `validationFailureAction: Enforce`

### PolicyReports Not Generating

**Problem**: No PolicyReports for namespace

**Debug steps**:

```bash
# 1. Check background controller
kubectl logs -n kyverno \
  -l app.kubernetes.io/component=background-controller \
  --tail=100

# 2. Verify background scanning enabled
kubectl get clusterpolicy require-resource-limits \
  -o jsonpath='{.spec.background}'

# Expected: true

# 3. Check resource filters
kubectl get configmap -n kyverno kyverno \
  -o jsonpath='{.data.resourceFilters}'
```

**Solution**: Enable background scanning, check namespace not excluded

### Admission Webhook Timeout

**Problem**: `context deadline exceeded` during deployment

**Debug steps**:

```bash
# Check admission controller pods
kubectl get pods -n kyverno -l app.kubernetes.io/component=admission-controller

# Check logs for errors
kubectl logs -n kyverno \
  -l app.kubernetes.io/component=admission-controller \
  --tail=50

# Test webhook directly
kubectl run test-pod --image=nginx --dry-run=server
```

**Solution**: Scale admission controller, check network policies

!!! tip "Timeout Usually Means Resource Starvation"
    Webhook timeouts indicate the admission controller is overwhelmed. Scale replicas or increase resource limits.

---

## Audit and Compliance

### Generating Compliance Reports

**Monthly compliance report**:

```bash
# Export all PolicyReports
kubectl get policyreport -A -o yaml > compliance-report-$(date +%Y-%m).yaml

# Summary by namespace
kubectl get policyreport -A \
  -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.summary.pass}{"\t"}{.summary.fail}{"\n"}{end}' \
  | column -t
```

**Output**:

```text
NAMESPACE     PASS  FAIL
default       245   12
production    523   3
staging       189   8
```

### Audit Trail

Track policy changes:

```bash
# Policy deployment history
helm history security-policy -n kyverno

# Git history of policy changes
cd /repos/security-policy
git log --oneline -- charts/security-policy/templates/
```

### SOC 2 Evidence

**What auditors need**:

1. **Policy definitions** - Export ClusterPolicies
2. **Enforcement proof** - Show `validationFailureAction: Enforce`
3. **Violation history** - PolicyReports from past months
4. **Exception tracking** - PolicyExceptions with approvals

**Evidence collection**:

```bash
# 1. Export all policies
kubectl get clusterpolicy -o yaml > policies-$(date +%Y-%m-%d).yaml

# 2. Export policy reports (3 months)
for month in {1..3}; do
  kubectl get policyreport -A -o yaml > reports-2025-0${month}.yaml
done

# 3. Export exceptions
kubectl get policyexception -A -o yaml > exceptions-$(date +%Y-%m-%d).yaml
```

---

## Next Steps

- **[Workflows](workflows.md)** - Policy updates, backup, performance tuning
- **[Runtime Deployment](../runtime-deployment/index.md)** - Kyverno deployment guide
- **[Policy Lifecycle](index.md)** - Adding and updating policies
