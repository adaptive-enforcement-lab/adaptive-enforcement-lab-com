# Queue Cleanup Operations

Operational guidance for running and maintaining queue cleanup patterns in Argo Workflows.

---

## Monitoring

Watch cleanup execution in real time:

```bash
kubectl logs -n production \
  -l workflows.argoproj.io/workflow=build-workflow \
  -c cleanup-pending-workflows \
  --tail=50 \
  -f
```

---

## Metrics to Track

- Number of workflows deleted per cleanup run
- Cleanup execution time
- Queue depth before/after cleanup
- Overall workflow completion time
- Resource utilization trends

!!! tip "Alert Thresholds"
    - Alert if cleanup deletes > 10 workflows (possible queue buildup issue)
    - Alert if cleanup takes > 10 seconds (possible API slowness)
    - Alert if queue depth grows despite cleanup (mutex not releasing)

---

## Troubleshooting

**Symptom**: Cleanup step fails with permission denied

**Check**: ClusterRole includes `delete` verb for workflows

**Fix**: Update RBAC:

```yaml
- apiGroups: [argoproj.io]
  resources: [workflows]
  verbs: [create, patch, delete, watch, list, get]
```

---

**Symptom**: Cleanup deletes wrong workflows

**Check**: Workflow name prefix matching logic

**Fix**: Ensure `startswith("build-workflow-")` matches your naming convention exactly

---

**Symptom**: Current workflow deletes itself

**Check**: `CURRENT_WORKFLOW` variable expansion

**Fix**: Verify `{{workflow.name}}` template syntax is correct (double curly braces, no spaces)

---

## Future Enhancements

### Potential Improvements

1. **Metrics export**: Expose cleanup stats as Prometheus metrics
2. **Configurable retention**: Keep N newest pending workflows (currently keeps only current)
3. **Pattern library**: Extract as reusable Helm chart template
4. **Webhook integration**: Prevent workflow submission when queue exists
5. **Smart throttling**: Rate-limit workflow submissions at source

### Reusable Template

This pattern can be extracted into a reusable Helm template:

```yaml
{{- define "work-avoidance.cleanup-pending" -}}
# Parameters:
#   - .workflow-prefix: Prefix for workflow names to cleanup
#   - .namespace: Kubernetes namespace
# Returns: Container spec for cleanup step
image: bash-utils:latest
command: ["/bin/bash", "-c"]
args:
  - |
    CURRENT_WORKFLOW="{{`{{workflow.name}}`}}"
    PENDING=$(kubectl get workflows -n {{ .namespace }} -o json | \
      jq -r '.items[] |
        select(.metadata.name | startswith("{{ .workflow-prefix }}")) |
        select(.status.phase == "Pending") |
        .metadata.name')

    for wf in ${PENDING}; do
      [ "${wf}" != "${CURRENT_WORKFLOW}" ] && kubectl delete workflow ${wf}
    done
{{- end -}}
```

Usage:

```yaml
- name: cleanup
  container:
    {{- include "work-avoidance.cleanup-pending"
        (dict "workflow-prefix" "my-workflow-" "namespace" .Values.namespace)
        | nindent 4 }}
```

---

## Related

- [Queue Cleanup Technique](../../developer-guide/efficiency-patterns/work-avoidance/techniques/queue-cleanup.md) - Pattern documentation
- [The Queue That Deleted Itself](../../blog/posts/2025-12-26-queue-deleted-itself-argo-workflows.md) - Implementation story
