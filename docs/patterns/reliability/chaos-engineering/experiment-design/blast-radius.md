---
description: >-
  Blast radius control for chaos experiments. Targeting strategies, progressive intensity, automatic rollback, and safe production chaos patterns.
tags:
  - chaos-engineering
  - blast-radius
  - safety
  - production
---

# Blast Radius Control

Uncontrolled chaos destroys production. Controlled chaos reveals fragility.

!!! example "Real-World Blast Radius"
    A SaaS company started chaos with 1 pod for 30 seconds in staging. After 2 weeks of validation, they progressed to 10% of production pods for 5 minutes. After 6 weeks, they ran continuous steady-state chaos at 5% intensity.

## Targeting Strategies

### Namespace Isolation

Run experiments in dedicated chaos namespaces:

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  namespace: chaos-testing
  name: pod-deletion-staging
spec:
  action: pod-kill
  mode: fixed
  value: 1
  selector:
    namespaces:
      - staging
      - staging-services
    labelSelectors:
      app: api-gateway
```

### Label-Based Scoping

Tag experiments with blast radius constraints:

```yaml
selector:
  labelSelectors:
    app: worker
    chaos-target: "true"
    chaos-window: "business-hours-only"
```

### Time Windows

Restrict chaos to low-impact periods:

```yaml
schedule:
  cron: "0 2 * * 1-4"  # 2 AM, Monday-Thursday only
duration: 5m
```

### Progressive Intensity

Start small, escalate based on observability:

```yaml
# Day 1: Single pod, 30 seconds
mode: fixed
value: 1
duration: 30s

# Day 2: Two pods, 1 minute
mode: fixed
value: 2
duration: 1m

# Day 7: 25% during business hours
mode: percentage
value: 25
duration: 5m
```

## Automatic Rollback

Configure automated rollback to prevent cascade failures:

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: pod-deletion-with-rollback
spec:
  action: pod-kill
  duration: "2m"
  selector:
    namespaces:
      - production
    labelSelectors:
      tier: web
  scheduling:
    # Auto-rollback if error rate exceeds threshold
    backoffBase: 1m
    maxAttempts: 3
```

Monitor error rates and auto-cancel:

```bash
# Example monitoring script
ERROR_RATE=$(curl -s prometheus:9090/api/v1/query \
  --data-urlencode 'query=rate(http_requests_total{status=~"5.."}[1m])' | \
  jq '.data.result[0].value[1] | tonumber')

if (( $(echo "$ERROR_RATE > 0.02" | bc -l) )); then
  kubectl delete podchaos -n chaos-testing pod-deletion-with-rollback
  echo "ROLLBACK: Error rate exceeded 2%"
fi
```

## Blast Radius Constraints

### Development Environment

- **Target**: Individual services, unlimited blast radius
- **Duration**: No restrictions
- **Approval**: Self-service by engineers

### Staging Environment

- **Target**: Up to 50% of instances
- **Duration**: Up to 1 hour
- **Approval**: Team lead approval

### Production Environment

- **Target**: Start with 1 instance, max 10% after validation
- **Duration**: 5 minutes max initially
- **Approval**: Security and SRE approval required

## Production Chaos Rules

!!! warning "Production Chaos Rules"
    - Never run chaos during high-traffic periods
    - Always have rollback plan tested in staging first
    - Start with smallest blast radius possible
    - Monitor continuously during experiment
    - Stop immediately if metrics exceed thresholds

### Pre-Production Validation

Before running chaos in production:

- [ ] Experiment succeeds in staging 3+ times
- [ ] Rollback procedure tested and documented
- [ ] On-call team notified with exact time window
- [ ] Monitoring dashboards prepared
- [ ] Alert thresholds configured
- [ ] Escalation path established

### Production Safeguards

1. **Time Window**: Low-traffic periods only (2-6 AM)
2. **Blast Radius**: Maximum 10% of capacity
3. **Duration**: 5 minutes maximum
4. **Monitoring**: Real-time SLI tracking
5. **Rollback**: Automated based on error rate

## Blast Radius Calculation

### Formula

```text
Blast Radius = (Affected Instances / Total Instances) × User Impact Factor
```

**User Impact Factor**:

- **1.0**: No customer-facing impact
- **2.0**: Indirect customer impact (internal API)
- **5.0**: Direct customer impact (web frontend)
- **10.0**: Payment or authentication systems

### Example Calculations

#### Scenario 1: Background Worker

```text
Affected: 2 of 10 worker pods
Total: 10 workers
User Impact: 1.0 (async processing)
Blast Radius: (2/10) × 1.0 = 0.2 (20%, low risk)
```

#### Scenario 2: API Gateway

```text
Affected: 1 of 3 API pods
Total: 3 pods
User Impact: 5.0 (customer-facing)
Blast Radius: (1/3) × 5.0 = 1.67 (167%, high risk)
```

#### Scenario 3: Payment Processor

```text
Affected: 1 of 5 payment pods
Total: 5 pods
User Impact: 10.0 (critical path)
Blast Radius: (1/5) × 10.0 = 2.0 (200%, critical risk)
```

## Related Topics

- **[Hypothesis Formation](hypothesis.md)** - Define experiment scope
- **[Success Criteria](success-criteria.md)** - Define acceptable impact
- **[SLI Monitoring](sli-monitoring.md)** - Track impact in real-time

---

*Controlled blast radius is the difference between learning and breaking. Start small, validate, then scale.*
