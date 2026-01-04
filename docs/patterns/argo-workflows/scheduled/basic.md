---
title: Basic CronWorkflow
description: >-
  Run workflows on cron schedules with timezone handling, starting deadlines, and WorkflowTemplateRef. Reliable time-based automation without manual intervention.
---
# Basic CronWorkflow

A CronWorkflow runs a workflow on a cron schedule. It's the Argo Workflows equivalent of a Kubernetes CronJob, but with full workflow capabilities: multi-step execution, sophisticated retry logic, and visual debugging.

---

## Why CronWorkflows?

Many automation tasks are time-based. Cache rebuilds every 6 hours. Database backups every night. Report generation every Monday morning. These need to run reliably, on schedule, without manual intervention.

CronWorkflows make scheduled execution a first-class concern. Define the schedule, configure failure handling, and let the system run. When things go wrong, the Argo UI shows exactly what happened and when.

---

## Basic Configuration

```yaml
apiVersion: argoproj.io/v1alpha1
kind: CronWorkflow
metadata:
  name: cache-rebuild
  namespace: argo-workflows
spec:
  schedule: "0 */6 * * *"
  workflowSpec:
    entrypoint: rebuild
    templates:
      - name: rebuild
        script:
          image: example-registry/workflows-cli:v1.0.0
          command: [bash]
          source: |
            workflows rebuild-cache --namespace argo-workflows
        serviceAccountName: cache-rebuilder
```

This runs every 6 hours. The workflow rebuilds a cache used by other automation. Simple, reliable, unattended.

---

## Configuration Fields

| Field | Purpose | Example |
| ------- | --------- | --------- |
| `schedule` | Cron expression for when to run | `"0 */6 * * *"` |
| `timezone` | Timezone for schedule interpretation | `"Europe/Zurich"` |
| `startingDeadlineSeconds` | Grace period to start after scheduled time | `60` |
| `workflowSpec` | The workflow to run (inline or reference) | See below |

---

## Timezone Handling

CronWorkflows default to UTC. For local time scheduling, specify a timezone:

```yaml
spec:
  schedule: "0 9 * * *"
  timezone: "America/New_York"
```

This runs at 9am New York time, automatically handling daylight saving time transitions.

!!! warning "DST Transitions"
    During daylight saving time changes, 2am local time might not exist (spring forward) or occur twice (fall back). Schedule critical jobs at times that don't overlap with DST transitions, like 3am or later.

---

## Starting Deadline

The `startingDeadlineSeconds` field specifies how late a job can start after its scheduled time:

```yaml
spec:
  schedule: "0 0 * * *"
  startingDeadlineSeconds: 60
```

If the controller can't start the workflow within 60 seconds of midnight, it's skipped. This prevents backlog accumulation during outages. You don't want 24 missed jobs all starting at once when the system recovers.

Without a starting deadline, missed jobs might start late (depending on `concurrencyPolicy`). Set a reasonable deadline for time-sensitive work.

---

## Using WorkflowTemplateRef

For complex workflows, reference a WorkflowTemplate instead of defining inline:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: CronWorkflow
metadata:
  name: nightly-pipeline
spec:
  schedule: "0 2 * * *"
  timezone: "Europe/Zurich"
  workflowSpec:
    workflowTemplateRef:
      name: full-pipeline
    arguments:
      parameters:
        - name: environment
          value: production
        - name: mode
          value: full
```

This approach:

- Keeps the CronWorkflow definition small
- Reuses the same WorkflowTemplate for manual runs
- Allows template updates without modifying the CronWorkflow

---

## Monitoring Schedules

Check CronWorkflow status:

```bash
# List CronWorkflows and their schedules
kubectl get cronworkflows -n argo-workflows

# View last run and next scheduled run
kubectl get cronworkflow cache-rebuild -o yaml | grep -A 5 status
```

The status shows:

- `lastScheduledTime`: When the last workflow was triggered
- `active`: Currently running workflows (if any)

---

## Related

- [Concurrency Policies](concurrency-policy.md): Handling overlapping runs
- [Orchestration](orchestration.md): Complex scheduled pipelines
- [TTL Strategy](../concurrency/ttl.md): Cleaning up completed runs
