# Queue Cleanup

Delete pending workflows before execution when only the latest run matters.

!!! tip "Self-Aware Deletion"
    The running workflow must never delete itself. Check the current workflow name before deleting others.

---

## The Technique

When workflows queue behind a mutex lock and process identical data, intermediate workflows are wasteful. Delete all pending workflows except the current one before executing the main operation.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: idempotent-workflow
spec:
  entrypoint: main
  synchronization:
    mutexes:
      - name: workflow-lock
  templates:
    - name: main
      steps:
        - - name: cleanup-pending
            template: cleanup-pending
        - - name: main-work
            template: main-work

    - name: cleanup-pending
      container:
        image: bash-utils:latest
        command: ["/bin/bash", "-c"]
        args:
          - |
            CURRENT="{{workflow.name}}"

            PENDING=$(kubectl get workflows -n argo -o json | \
              jq -r '.items[] |
                select(.metadata.name | startswith("idempotent-workflow-")) |
                select(.status.phase == "Pending") |
                .metadata.name')

            for wf in ${PENDING}; do
              if [ "${wf}" != "${CURRENT}" ]; then
                kubectl delete workflow ${wf} -n argo
              fi
            done
```

---

## When to Use

Queue cleanup applies to workflows that are:

!!! success "Good Fit"
    - **Idempotent**: Same result regardless of run count
    - **Source-pulling**: Fetches all data (not incremental)
    - **Mutex-locked**: Only one instance runs at a time
    - **Frequently triggered**: Multiple triggers in short windows
    - **Resource intensive**: Wasteful to run unnecessarily

### Example Scenarios

| Workflow Type | Why Queue Cleanup Helps | Expected Savings |
|---------------|------------------------|------------------|
| Documentation builds | Pulls all markdown from git | 70-90% queue reduction |
| Static site generation | Rebuilds entire site | 60-80% queue reduction |
| Full database backups | Dumps entire database | 50-70% queue reduction |
| Container image builds | Builds from Dockerfile | 40-60% queue reduction |
| Deployment sync | Syncs to latest state | 60-80% queue reduction |

!!! danger "Anti-Patterns (Do NOT Use)"
    ❌ **Incremental workflows**: Each run processes unique data
    ❌ **Stateful workflows**: Execution order matters
    ❌ **Transactional workflows**: Each trigger represents discrete work
    ❌ **Parallel workflows**: Multiple instances should run simultaneously

---

## Implementation Requirements

### RBAC Permissions

The ServiceAccount must have `delete` permission on workflows:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: workflow-cleanup
rules:
  - apiGroups: [argoproj.io]
    resources: [workflows]
    verbs: [list, get, delete]
```

### Image Requirements

The cleanup container needs:

- **bash shell**: For script execution
- **kubectl CLI**: For Kubernetes API access
- **jq**: For JSON parsing

Use a full image, not distroless. Example: `bash-utils:latest` or build your own.

### Workflow Name Pattern

Workflows must follow a consistent naming pattern for cleanup filtering:

```yaml
metadata:
  generateName: idempotent-workflow-  # Generates: idempotent-workflow-abc123
```

Cleanup script matches by prefix:

```bash
select(.metadata.name | startswith("idempotent-workflow-"))
```

---

## Safety Mechanisms

### Self-Deletion Prevention

Always check the current workflow name before deleting:

```bash
CURRENT="{{workflow.name}}"

for wf in ${PENDING}; do
  if [ "${wf}" != "${CURRENT}" ]; then
    kubectl delete workflow ${wf}
  fi
done
```

The `{{workflow.name}}` template variable expands at runtime. The current workflow always skips itself.

### Status Filtering

Only delete workflows in Pending state:

```bash
select(.status.phase == "Pending")
```

This avoids deleting:

- Running workflows (might be about to complete)
- Succeeded workflows (historical data)
- Failed workflows (debugging information)

### Timeout Protection

Set `activeDeadlineSeconds` to prevent runaway cleanup:

```yaml
spec:
  activeDeadlineSeconds: 1200  # 20 minutes max
```

If cleanup hangs (API issues, permission problems), the workflow terminates instead of consuming resources indefinitely.

---

## Operational Patterns

### Monitoring Cleanup

Watch cleanup execution in real time:

```bash
kubectl logs -n argo \
  -l workflows.argoproj.io/workflow=idempotent-workflow \
  -c cleanup-pending \
  --tail=50 \
  -f
```

### Metrics to Track

| Metric | Purpose | Alert Threshold |
|--------|---------|----------------|
| Workflows deleted per run | Queue buildup indicator | > 10 |
| Cleanup execution time | API performance | > 10 seconds |
| Queue depth after cleanup | Mutex release check | > 1 |
| Cleanup failure rate | RBAC or API issues | > 5% |

### Troubleshooting

**Symptom**: Cleanup step fails with permission denied

**Fix**: Verify ClusterRole includes `delete` verb for workflows resource

---

**Symptom**: Cleanup deletes workflows from other workflow types

**Fix**: Make workflow name prefix more specific (`static-build-` vs `build-`)

---

**Symptom**: Cleanup takes too long

**Fix**: Add namespace filter to kubectl query to reduce API load

---

## Comparison to Other Techniques

| Technique | Question | Best For |
|-----------|----------|----------|
| **Queue Cleanup** | "Should queued work execute?" | Mutex-locked workflows |
| [Content Hashing](content-hashing.md) | "Is the content different?" | File comparisons, config sync |
| [Cache-Based Skip](cache-based-skip.md) | "Is output already built?" | Build artifacts, dependencies |
| [Existence Checks](existence-checks.md) | "Does it already exist?" | Resource creation (PRs, branches) |

Queue cleanup is unique because it operates on the **workflow queue itself**, not on the data the workflow processes. Use it in combination with other work avoidance techniques.

---

## Production Validation

**Test scenario**: 8 pending workflows, 1 running workflow

**Cleanup execution**: 2 seconds

**Result**: 7 workflows deleted, 0 wasteful builds

**Metrics**:

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Average queue depth | 8 | 0-1 | 87% reduction |
| Average wait time | 16 min | 0-2 min | 87% reduction |
| Wasteful builds | 70% | 0% | 100% elimination |

See [The Queue That Deleted Itself](../../../../blog/posts/2025-12-26-queue-deleted-itself-argo-workflows.md) for the full implementation story.

---

## Reusable Template

Extract as a Helm template for use across workflows:

```yaml
{{- define "work-avoidance.cleanup-pending" -}}
image: bash-utils:latest
command: ["/bin/bash", "-c"]
args:
  - |
    CURRENT="{{`{{workflow.name}}`}}"

    PENDING=$(kubectl get workflows -n {{ .namespace }} -o json | \
      jq -r '.items[] |
        select(.metadata.name | startswith("{{ .prefix }}")) |
        select(.status.phase == "Pending") |
        .metadata.name')

    DELETED=0
    for wf in ${PENDING}; do
      if [ "${wf}" != "${CURRENT}" ]; then
        kubectl delete workflow ${wf} -n {{ .namespace }}
        DELETED=$((DELETED + 1))
      fi
    done

    echo "Deleted ${DELETED} pending workflows"
{{- end -}}
```

Usage:

```yaml
- name: cleanup
  container:
    {{- include "work-avoidance.cleanup-pending"
        (dict "prefix" "my-workflow-" "namespace" .Values.namespace)
        | nindent 4 }}
```

---

## Related

- [Work Avoidance Overview](../index.md): Core concepts and other techniques
- [Argo Workflows Mutex](../../../argo-workflows/concurrency/mutex.md): Mutex locking patterns
- [Idempotency Patterns](../../idempotency/index.md): Making operations safe to repeat
- [The Queue That Deleted Itself](../../../../blog/posts/2025-12-26-queue-deleted-itself-argo-workflows.md): Production implementation story
