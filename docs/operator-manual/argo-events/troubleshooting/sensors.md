# Sensor Troubleshooting

Sensors receive events from the EventBus and trigger actions. When events arrive but workflows don't start, the problem is usually in the Sensor—filters, conditions, or trigger configuration.

---

## Diagnostic Steps

### 1. Check Sensor Status

```bash
kubectl get sensors -n argo-events

# Example output:
# NAME              STATUS    AGE
# deploy-sensor     True      5d
# notify-sensor     False     2h    # Problem here
```

### 2. Check Sensor Logs

```bash
kubectl logs -n argo-events -l sensor-name=deploy-sensor --tail=50
```

Look for:

- Event received messages
- Filter evaluation results
- Trigger execution attempts
- Error messages

### 3. Enable Debug Logging

```yaml
spec:
  template:
    container:
      env:
        - name: DEBUG_LOG
          value: "true"
```

---

## Common Issues

### Events Received But Not Triggering

**Symptom**: Sensor logs show events arriving, but no workflows created.

**Most common cause**: Filters don't match.

```bash
# Check what's actually in the event
kubectl logs -n argo-events -l sensor-name=deploy-sensor | grep "event data"
```

Compare event structure with your filter paths:

```yaml
# Your filter
filters:
  data:
    - path: body.tag
      type: string
      value:
        - "v*"

# But actual event has
# body:
#   repository:
#     tag: "v1.0.0"  # Path is body.repository.tag, not body.tag
```

**Fix**: Correct the JSON path to match actual event structure.

---

### Filter Silently Drops Events

**Symptom**: No errors, no triggers, events just disappear.

Filters that don't match produce no output. Add a catch-all debug trigger:

```yaml
triggers:
  # Your real trigger
  - template:
      name: deploy
      conditions: matches-filter
      argoWorkflow:
        # ...

  # Debug trigger - always fires
  - template:
      name: debug-log
      log:
        intervalSeconds: 0

conditions:
  matches-filter:
    expr: body.tag matches "^v[0-9]+"
```

The debug trigger fires for every event, showing you exactly what's arriving.

---

### Condition Never Evaluates True

**Symptom**: Sensor receives events, logs show condition evaluation, trigger never fires.

```bash
# Look for condition evaluation in logs
kubectl logs -n argo-events -l sensor-name=deploy-sensor | grep -i condition
```

**Common causes**:

1. **Type mismatch**: String vs number comparison

    ```yaml
    # Wrong - comparing string to number
    expr: body.count > 5  # body.count is "5" (string)

    # Fix - convert type
    expr: int(body.count) > 5
    ```

2. **Null field access**: Accessing field that doesn't exist

    ```yaml
    # Fails if commits is null
    expr: len(body.commits) > 0

    # Safe - check existence first
    expr: body.commits != nil && len(body.commits) > 0
    ```

3. **Case sensitivity**: Field names are case-sensitive

    ```yaml
    # Wrong
    expr: body.Repository.Name == "my-repo"

    # Correct (check actual JSON)
    expr: body.repository.name == "my-repo"
    ```

---

### Trigger Submits But Workflow Fails

**Symptom**: Sensor triggers, but workflow never appears or immediately fails.

```bash
# Check for failed workflow creation
kubectl get workflows -n argo-workflows --sort-by=.metadata.creationTimestamp | tail -10

# Check Argo Workflows controller logs
kubectl logs -n argo-workflows -l app=workflow-controller --tail=50
```

**Common causes**:

1. **Parameter injection fails**: Event data not mapping to workflow parameters

    ```yaml
    # Check parameter paths
    parameters:
      - src:
          dependencyName: image-push
          dataKey: body.image  # Does this path exist?
        dest: spec.arguments.parameters.0.value
    ```

2. **RBAC insufficient**: Sensor ServiceAccount can't create workflows

    ```bash
    # Check if sensor SA can create workflows
    kubectl auth can-i create workflows -n argo-workflows \
      --as=system:serviceaccount:argo-events:sensor-sa
    ```

3. **Invalid workflow spec**: Malformed YAML in trigger

    ```bash
    # Extract and validate workflow spec
    kubectl get sensor deploy-sensor -o yaml | \
      yq '.spec.triggers[0].template.argoWorkflow.source.resource' | \
      kubectl apply --dry-run=client -f -
    ```

---

### Multiple Dependencies Not Triggering

**Symptom**: Sensor has multiple dependencies but never triggers.

All dependencies must receive events before the trigger fires:

```yaml
dependencies:
  - name: event-a
    eventSourceName: source-a
    eventName: event
  - name: event-b
    eventSourceName: source-b
    eventName: event
```

Both `event-a` AND `event-b` must arrive. Check each dependency:

```bash
# Check which dependencies have received events
kubectl logs -n argo-events -l sensor-name=multi-dep | grep "dependency"
```

**Fix**: If you want OR logic (either event triggers), use separate Sensors.

---

### ServiceAccount Permissions

**Symptom**: Trigger executes but fails with permission error.

```text
Error creating workflow: forbidden: User "system:serviceaccount:argo-events:sensor-sa"
cannot create resource "workflows" in namespace "argo-workflows"
```

**Fix**: Grant workflow creation permissions:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: sensor-workflow-creator
  namespace: argo-workflows
rules:
  - apiGroups: ["argoproj.io"]
    resources: ["workflows"]
    verbs: ["create", "get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: sensor-workflow-creator
  namespace: argo-workflows
subjects:
  - kind: ServiceAccount
    name: sensor-sa
    namespace: argo-events
roleRef:
  kind: Role
  name: sensor-workflow-creator
  apiGroup: rbac.authorization.k8s.io
```

---

## Event Structure Discovery

When you don't know the event structure, capture it:

```yaml
# Minimal Sensor that logs everything
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: event-logger
spec:
  dependencies:
    - name: any-event
      eventSourceName: your-source
      eventName: your-event
  triggers:
    - template:
        name: log-event
        log:
          intervalSeconds: 0
```

Then check logs:

```bash
kubectl logs -n argo-events -l sensor-name=event-logger --tail=20 | jq .
```

This shows you exactly what fields exist and their paths.

---

!!! tip "Incremental Debugging"
    Start with a Sensor that triggers on everything. Then add one filter at a time, verifying each works before adding the next. This isolates which filter causes the problem.

---

## Related

- [Sensor Configuration](../setup/sensors.md) - Setup reference
- [Filtering](../../../developer-guide/argo-events/routing/filtering.md) - Filter patterns
- [EventSource Issues](eventsources.md) - Previous debugging step
- [Official Sensor Docs](https://argoproj.github.io/argo-events/sensors/intro/) - Complete reference
