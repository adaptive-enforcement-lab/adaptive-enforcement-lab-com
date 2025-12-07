# EventSource Configuration

EventSources connect to external systems and normalize events for the EventBus.

---

## Pub/Sub EventSource

Connect to Google Cloud Pub/Sub:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: gar-image-push
  namespace: argo-events
spec:
  pubsub:
    image-pushed:
      projectID: example-gcp-project
      topicProjectID: example-gcp-project
      topic: gar-image-notifications
      credentialSecret:
        name: gcp-pubsub-credentials
        key: service-account.json
      jsonBody: true
      deleteSubscriptionOnFinish: false
```

**Key settings:**

| Setting | Value | Purpose |
|---------|-------|---------|
| `jsonBody` | `true` | Parse Pub/Sub messages as JSON |
| `deleteSubscriptionOnFinish` | `false` | Keep subscription across pod restarts |
| `credentialSecret` | secret reference | GCP service account with `pubsub.subscriber` role |

!!! warning "Silent Failures"
    Without `jsonBody: true`, events arrive but fail to parse. No errors appear in logs. The EventSource marks messages as delivered, then discards them.

---

## GitHub Webhook EventSource

Connect to GitHub repositories via webhooks with GitHub App authentication:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: github
  namespace: argo-events
spec:
  service:
    ports:
      - name: push
        port: 12000
        targetPort: 12000
  github:
    github:
      repositories:
        - owner: my-org
          names:
            - repo-one
            - repo-two
      githubApp:
        privateKey:
          name: github-app-credentials
          key: private-key.pem
        appID: 123456
        installationID: 12345678
      webhook:
        endpoint: /push
        port: "12000"
        method: POST
        url: https://webhooks.example.com/github
      events:
        - push
      contentType: json
      active: true
```

**Key settings:**

| Setting | Purpose |
|---------|---------|
| `githubApp` | GitHub App auth (preferred over personal tokens) |
| `webhook.url` | External URL where GitHub sends events |
| `events` | GitHub event types to listen for |
| `service.ports` | Internal service for ingress routing |

!!! tip "Ingress Required"
    The EventSource runs an internal HTTP server. You need an Ingress or Gateway to expose `webhook.url` to GitHub. The service name follows the pattern `<eventsource-name>-eventsource-svc`.

---

## Dynamic Repository Lists with Helm

When managing many repositories, use Helm templating to generate the EventSource dynamically:

```yaml
# values.yaml
github:
  repositories:
    - owner: my-org
      names:
        - api-service
        - web-frontend
        - worker-backend
    - owner: other-org
      names:
        - shared-library
```

```yaml
# templates/github-eventsource.yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: github
spec:
  github:
    github:
      repositories:
        {{- range .Values.github.repositories }}
        - owner: {{ .owner }}
          names:
            {{- range .names }}
            - {{ . }}
            {{- end }}
        {{- end }}
      # ... rest of config
```

This pattern allows you to:

- Add repositories by updating `values.yaml` instead of editing templates
- Use different repository lists per environment
- Keep EventSource configuration DRY across multiple deployments

---

## Resource Limits

Always set resource limits on EventSource pods:

```yaml
spec:
  template:
    container:
      resources:
        requests:
          cpu: 50m
          memory: 1Gi
        limits:
          cpu: 200m
          memory: 1Gi
      env:
        - name: LOG_LEVEL
          value: error  # Reduce log noise in production
    serviceAccountName: eventsource-sa
  replicas: 1
```

---

## Related

- [EventBus Configuration](event-bus.md) - Message delivery between EventSource and Sensor
- [Sensor Configuration](sensors.md) - Event filtering and workflow triggers
