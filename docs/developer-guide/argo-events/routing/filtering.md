# Simple Filtering

Filters determine which events trigger actions. Well-designed filters reduce noise, prevent unnecessary workflow executions, and keep automation targeted. For the complete filter reference, see the [official Filters documentation](https://argoproj.github.io/argo-events/sensors/filters/intro/).

---

## Filter Types

Argo Events supports multiple filter types that can be combined:

| Filter Type | Purpose | Argo Docs |
|-------------|---------|-----------|
| `data` | Match event payload fields | [Data Filters](https://argoproj.github.io/argo-events/sensors/filters/data/) |
| `context` | Match CloudEvents context | [Context Filters](https://argoproj.github.io/argo-events/sensors/filters/context/) |
| `time` | Match time windows | [Time Filters](https://argoproj.github.io/argo-events/sensors/filters/time/) |
| `expr` | Complex expressions | [Expr Filters](https://argoproj.github.io/argo-events/sensors/filters/expr/) |

---

## Data Filters

Data filters match against the event payload. They're the most common filter type:

```yaml
dependencies:
  - name: github-push
    eventSourceName: github
    eventName: push
    filters:
      data:
        - path: body.ref
          type: string
          value:
            - "refs/heads/main"
            - "refs/heads/release/*"
```

**Filter fields:**

- `path`: JSONPath to the field in the event payload
- `type`: Data type (`string`, `bool`, `number`)
- `value`: List of acceptable values (OR logic)
- `comparator`: Comparison operator (`=`, `!=`, `>=`, `<=`, `>`, `<`)

Multiple data filters use AND logic—all must match for the event to trigger.

---

## Negation Filters

Exclude events that match certain patterns:

```yaml
filters:
  data:
    - path: body.pusher.name
      type: string
      value:
        - "dependabot[bot]"
        - "renovate[bot]"
      comparator: "!="
```

This filters out automated bot pushes, only triggering on human commits.

---

## Expression Filters

For complex logic that data filters can't express, use expr filters:

```yaml
filters:
  exprs:
    - expr: body.commits != nil && len(body.commits) > 0
      fields:
        - name: body.commits
          path: body.commits
```

Expression filters support CEL (Common Expression Language) for powerful matching:

```yaml
filters:
  exprs:
    - expr: >-
        body.action == "opened" &&
        body.pull_request.draft == false &&
        body.pull_request.base.ref == "main"
      fields:
        - name: body.action
          path: body.action
        - name: body.pull_request
          path: body.pull_request
```

This triggers only for non-draft PRs opened against main.

---

## Time Filters

Restrict events to specific time windows:

```yaml
filters:
  time:
    start: "08:00"
    stop: "18:00"
    timezone: "Europe/Zurich"
```

Events outside the window are dropped. Useful for preventing deployments during off-hours.

---

## Combining Filters

Filters can be combined for precise control:

```yaml
dependencies:
  - name: prod-deploy
    eventSourceName: registry
    eventName: push
    filters:
      # AND: all data filters must match
      data:
        - path: body.tag
          type: string
          value:
            - "v*"
        - path: body.repository
          type: string
          value:
            - "example-registry/production-app"
      # AND: time filter must also match
      time:
        start: "09:00"
        stop: "17:00"
        timezone: "Europe/Zurich"
```

This triggers only for:

- Production app images (`AND`)
- With version tags (`AND`)
- During business hours

---

!!! warning "Silent Drops"
    Filtered events are dropped silently. No logs, no errors, no indication that an event was received and rejected. Start with permissive filters and add restrictions incrementally. The [Sensor troubleshooting guide](../troubleshooting/sensors.md) covers debugging filter issues.

---

## Related

- [Multi-Trigger Actions](multi-trigger.md) - Multiple actions from one event
- [Event Transformation](transformation.md) - Modify payloads before triggering
- [Troubleshooting Sensors](../troubleshooting/sensors.md) - Debug filter issues
- [Official Filters Docs](https://argoproj.github.io/argo-events/sensors/filters/intro/) - Complete reference
