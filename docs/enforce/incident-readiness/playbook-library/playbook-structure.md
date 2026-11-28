---
title: Playbook Structure and Tooling
description: >-
  Structure an incident playbook as a decision tree: severity, immediate actions, diagnosis order, decision rules, runbook layout, alert links and a postmortem.
provenance: human
---
# Playbook Structure and Tooling

A playbook for a 3am incident is a decision tree, not a document. Every decision point is
made in advance, so the responder executes instead of improvising.

!!! tip "Decide at 2pm"
    Write every if-then rule during business hours. Each one saves minutes of confused thinking at 3am.

---

## Decision Tree

```text
Incident Alert
├── Severity Classification
│   ├── SEV-1: User-facing outage
│   ├── SEV-2: Degraded performance
│   └── SEV-3: Single service issue
│
├── Immediate Actions (Do this first, no debate)
│   ├── Start the incident thread
│   ├── Notify on-call leadership
│   ├── Enable verbose logging
│   └── Open the runbook
│
├── Diagnosis Phase (Follow this order)
│   ├── Check dashboard (Is it real?)
│   ├── Check metrics (What's the pattern?)
│   ├── Check logs (When did it start?)
│   ├── Check recent changes (What touched it?)
│   └── Form hypothesis
│
├── Response Phase (Execute, don't improvise)
│   ├── Does the fix exist in the playbook?
│   │   ├── Yes → Execute step-by-step
│   │   └── No → Escalate, but document what you try
│   └── Monitor recovery metrics
│
└── Resolution (Close deliberately)
    ├── Verify metrics return to baseline
    ├── Run rollback if fix wasn't stable
    ├── Document exactly what happened
    └── Schedule postmortem
```

---

## Diagnostic Checklist

Pre-written commands per symptom:

```bash
# Pod restart storms: check node status
kubectl get nodes -o wide
kubectl describe node <unhealthy-node>

# API latency spike: check goroutine count
curl http://service:9090/metrics | grep goroutine

# Database issue: check connection pool
SELECT count(*) FROM pg_stat_activity;

# Recent deployment: check rollout status
kubectl rollout history deployment/api --revision=<latest>
kubectl rollout undo deployment/api --to-revision=<previous>
```

---

## Decision Rules

One rule per symptom, no branching on "but what if":

```text
If: Pod restart storms + Node in NotReady state
Then:
  1. Don't try to debug the pod
  2. Cordon the node immediately
  3. Page infrastructure team
  4. Scale up 2 additional nodes
  5. Wait for pods to migrate
  6. Proceed to recovery check
```

---

## Runbook Repository

Runbooks live in git, versioned and updated in every postmortem:

```text
runbooks/
├── kubernetes/node-recovery.md
├── postgres/connection-pool.md
└── observability/alert-validation.md
```

## Alert to Runbook Linking

```yaml
alert: PodRestartStorm
annotations:
  runbook_url: https://runbooks.example.com/kubernetes/pod-crashloop.md
```

## Incident Thread Template

```text
SEV-1 | Pod Restart Storms | Started 3:17am
Symptoms: Error rate 12%, pod restart loop
Actions: Cordoned node-07, scaled cluster up
Result: Stable at 3:26am
```

---

## Postmortem Template

When the incident is documented live, the postmortem is mostly written:

```markdown
# Incident: Pod Restart Storms - 2026-01-08

Timeline: 3:17am alert, 3:20am node identified, 3:26am closed

Root Cause: Kubelet memory leak after 45-day uptime

Fixes:
1. Add kubelet memory alerting
2. Enable node auto-restart after 40 days
3. Add kubelet memory to pre-incident checks

Impact: 9 minutes, ~50 affected requests
```

---

## Related

- [Incident Response Playbook Templates](index.md) - The playbook library
- [The 3am Incident That Followed the Playbook](../../../blog/posts/2026-01-01-3am-incident-followed-playbook.md) - The story behind the structure
