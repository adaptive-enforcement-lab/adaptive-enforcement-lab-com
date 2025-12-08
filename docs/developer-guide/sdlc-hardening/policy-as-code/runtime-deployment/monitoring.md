# Monitoring and Operations

Monitor policy compliance, handle exceptions, troubleshoot issues, and follow operational best practices.

## Monitoring and Observability

### Policy Reporter Dashboard

Access the Policy Reporter UI:

```bash
kubectl port-forward -n policy-reporter \
  svc/policy-reporter-ui 8080:8080
```

**Dashboard features**:

- Policy compliance by namespace
- Violation trends over time
- Top violating resources
- Policy effectiveness metrics

!!! tip "Dashboard for Compliance Reviews"
    Use the Policy Reporter dashboard during compliance reviews. Export monthly reports showing pass/fail ratios by namespace. This provides auditors with visual proof of enforcement.

### Prometheus Metrics

Policy Reporter exports Prometheus metrics:

```promql
policy_report_result{policy="require-resource-limits", status="fail"} 12
policy_report_result{policy="disallow-latest-tag", status="fail"} 3
policy_report_summary{status="pass"} 245
policy_report_summary{status="fail"} 15
```

**Useful queries**:

```promql
# Compliance rate
sum(policy_report_result{status="pass"}) / sum(policy_report_result)

# Top failing policies
topk(10, sum by (policy) (policy_report_result{status="fail"}))

# Violations by namespace
sum by (namespace) (policy_report_result{status="fail"})
```

**Grafana Dashboard**: Visualize policy compliance trends.

### Slack Notifications

Configure Slack alerts for policy violations:

```yaml
# policy-reporter-values.yaml
targets:
  slack:
    webhook: "https://hooks.slack.com/services/XXX/YYY/ZZZ"
    minimumPriority: "warning"
    skipExistingOnStartup: true
    channels:
      - name: "#security-alerts"
        filter:
          namespaces:
            include: ["production"]
          policies:
            include: ["require-resource-limits", "disallow-latest-tag"]
```

**Alert example**:

```text
🚨 Policy Violation Detected

Policy: require-resource-limits
Resource: Deployment/nginx
Namespace: production
Message: CPU and memory limits required
Severity: medium
```

!!! warning "Alert on Critical Policies Only"
    Don't send Slack alerts for every policy violation. Reserve alerts for critical security policies in production namespaces. Use dashboard for everything else to prevent alert fatigue.

---

## Exception Handling

### Policy Exceptions

Allow specific resources to bypass policies:

```yaml
apiVersion: kyverno.io/v2beta1
kind: PolicyException
metadata:
  name: allow-legacy-app
  namespace: kyverno
spec:
  exceptions:
    - policyName: require-resource-limits
      ruleNames:
        - check-cpu-memory
  match:
    any:
      - resources:
          kinds:
            - Deployment
          namespaces:
            - legacy
          names:
            - old-app
```

**Use sparingly. Exceptions should be temporary.**

### Exception Governance

**Best practices**:

1. **Require expiration dates**:

   ```yaml
   spec:
     validUntil: "2025-03-08T00:00:00Z"  # 90 days from creation
   ```

2. **Add approval annotations**:

   ```yaml
   metadata:
     annotations:
       jira.ticket: "SEC-1234"
       approved-by: "security-team"
       reason: "Legacy application, migration planned Q2 2025"
   ```

3. **Quarterly review**:

   ```bash
   # List all exceptions
   kubectl get policyexception -A

   # Find expiring exceptions
   kubectl get policyexception -A \
     -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.validUntil}{"\n"}{end}'
   ```

!!! danger "Exceptions Must Expire"
    Every PolicyException MUST have `validUntil` set. Permanent exceptions create permanent security gaps. Set expiration, review quarterly, renew only with approval.

---

## Troubleshooting

### Admission Webhook Failures

**Problem**: `admission webhook "validate.kyverno.svc" denied the request`

**Cause**: Policy violation detected

**Solution**: Check policy and resource

```bash
# Get policy details
kubectl get clusterpolicy require-resource-limits -o yaml

# Check resource against policy locally
kyverno apply require-resource-limits.yaml --resource deployment.yaml
```

### Background Scan Not Running

**Problem**: PolicyReports not updating

**Cause**: Background controller not running or disabled

**Solution**: Check background controller

```bash
# Check background controller logs
kubectl logs -n kyverno \
  -l app.kubernetes.io/component=background-controller

# Verify background scan interval
kubectl get deployment -n kyverno kyverno-background-controller \
  -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="BACKGROUND_SCAN_INTERVAL")].value}'
```

### Policy Not Enforced

**Problem**: Resource deployed despite policy violation

**Cause**: Policy in Audit mode instead of Enforce

**Solution**: Check validation failure action

```bash
kubectl get clusterpolicy require-resource-limits \
  -o jsonpath='{.spec.validationFailureAction}'
```

**Expected**: `Enforce`

**If `Audit`**: Policy is warn-only.

**Fix**:

```bash
kubectl patch clusterpolicy require-resource-limits \
  --type merge \
  -p '{"spec":{"validationFailureAction":"Enforce"}}'
```

!!! tip "Always Check Validation Failure Action"
    If policies aren't blocking violations, 99% of the time it's because `validationFailureAction` is set to `Audit` instead of `Enforce`. Check this first.

---

## Best Practices

### 1. Start with Audit Mode

Roll out new policies in Audit mode first:

```yaml
spec:
  validationFailureAction: Audit
  background: true
```

Monitor PolicyReports. Switch to Enforce after validation.

### 2. Exclude System Namespaces

Avoid breaking system components:

```yaml
resourceFilters:
  resourceFiltersExcludeNamespaces:
    - kube-system
    - gmp-system
    - cnrm-system
```

### 3. Use Background Scanning

Detect drift and violations in existing resources:

```yaml
spec:
  background: true
```

### 4. Monitor Policy Reports

Set up alerts for critical violations:

```yaml
targets:
  slack:
    minimumPriority: "critical"
```

### 5. Version Policy Deployments

Use Helm chart versions for rollback capability:

```bash
helm upgrade --install security-policy \
  /repos/security-policy/charts/security-policy \
  --version 1.2.3
```

---

## Operational Checklist

**Weekly**:

- [ ] Review PolicyReports for new violations
- [ ] Check PolicyException expiration dates
- [ ] Verify background scans running

**Monthly**:

- [ ] Generate compliance report
- [ ] Review exception renewals
- [ ] Audit policy effectiveness

**Quarterly**:

- [ ] Review all PolicyExceptions
- [ ] Update policy versions
- [ ] Test disaster recovery procedures

---

## Next Steps

- **[Operations](../operations/index.md)** - Day-to-day policy lifecycle management
- **[Multi-Source Policies](../multi-source-policies/index.md)** - Aggregate policies from multiple repos
- **[Policy Packaging](../policy-packaging/index.md)** - Build policy-platform container
- **[Kyverno Deep Dive](../kyverno/index.md)** - Advanced Kyverno patterns
