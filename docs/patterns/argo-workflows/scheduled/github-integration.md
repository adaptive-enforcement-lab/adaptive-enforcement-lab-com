---
description: >-
  Trigger GitHub Actions from Argo Workflows via repository dispatch. Bidirectional integration between Kubernetes automation and GitHub CI/CD with App auth.
---

# GitHub Integration

Argo Workflows can trigger GitHub Actions workflows and repository dispatches, enabling bidirectional integration between Kubernetes automation and GitHub CI/CD.

---

## Why Integrate with GitHub?

Some automation belongs in Kubernetes (deployment orchestration, cluster management, scheduled jobs). Other automation belongs in GitHub Actions (code testing, artifact building, release management).

Integration enables:

- Scheduled Argo workflows that trigger GitHub builds
- Kubernetes events that notify GitHub
- Hybrid pipelines spanning both platforms

---

## Repository Dispatch from Workflow

Trigger GitHub Actions workflows using the repository dispatch API:

```yaml
templates:
  - name: github-dispatch
    script:
      image: ghcr.io/cli/cli:latest
      command: [bash]
      source: |
        export HOME=/tmp
        source /secrets/github-authenticate.sh
        gh api --method POST \
          -H "Accept: application/vnd.github+json" \
          -H "X-GitHub-Api-Version: 2022-11-28" \
          /repos/my-org/my-repo/dispatches \
          -f "event_type=build-triggered" \
          -f "client_payload[artifact]={{workflow.parameters.artifact}}" \
          -f "client_payload[trigger]=scheduled"
      env:
        - name: GITHUB_APP_ID
          valueFrom:
            secretKeyRef:
              name: github-app-credentials
              key: appId
        - name: GITHUB_APP_SECRET_PATH
          value: /secrets/private-key.pem
      volumeMounts:
        - name: github-credentials
          mountPath: /secrets
          readOnly: true
```

The `/dispatches` endpoint sends a custom event to the repository. GitHub Actions workflows can listen for this event type and run in response.

---

## GitHub Actions Workflow Receiver

On the GitHub side, configure a workflow to respond to dispatches:

```yaml
# .github/workflows/on-dispatch.yml
name: Kubernetes Trigger

on:
  repository_dispatch:
    types: [build-triggered]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Log trigger info
        run: |
          echo "Triggered by: ${{ github.event.client_payload.trigger }}"
          echo "Artifact: ${{ github.event.client_payload.artifact }}"

      - name: Run build
        run: |
          # Your build logic here
```

The `client_payload` from the Argo workflow becomes available in the GitHub Actions context.

---

## GitHub App Authentication

For production use, authenticate with a GitHub App rather than personal tokens:

**Authentication script (`github-authenticate.sh`):**

```bash
#!/bin/bash
set -euo pipefail

# Generate JWT from App credentials
JWT=$(generate-jwt --app-id "$GITHUB_APP_ID" --key-path "$GITHUB_APP_SECRET_PATH")

# Exchange JWT for installation token
INSTALLATION_TOKEN=$(curl -s -X POST \
  -H "Authorization: Bearer $JWT" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/app/installations/$GITHUB_INSTALLATION_ID/access_tokens" \
 | jq -r '.token')

# Configure gh CLI
echo "$INSTALLATION_TOKEN" | gh auth login --with-token
```

Store this script in a ConfigMap and source it before using `gh` commands.

**Required permissions:**

- Repository: Contents (read), Actions (write)
- Organization: Members (read) if triggering org-wide

---

## Scheduled Dispatch Pattern

Combine CronWorkflow with GitHub dispatch for scheduled triggers:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: CronWorkflow
metadata:
  name: nightly-github-build
spec:
  schedule: "0 2 * * *"
  timezone: "UTC"
  concurrencyPolicy: Replace
  workflowSpec:
    entrypoint: main
    templates:
      - name: main
        steps:
          - - name: prepare-build
              template: prepare-artifacts
          - - name: trigger-github
              template: github-dispatch

      - name: prepare-artifacts
        container:
          image: builder:latest
          # Prepare whatever GitHub needs

      - name: github-dispatch
        script:
          image: ghcr.io/cli/cli:latest
          command: [bash]
          source: |
            export HOME=/tmp
            source /secrets/github-authenticate.sh
            gh api --method POST \
              -H "Accept: application/vnd.github+json" \
              /repos/my-org/my-repo/dispatches \
              -f "event_type=nightly-build"
          # ... authentication config
```

Every night at 2am UTC, Argo prepares artifacts and triggers a GitHub Actions build.

---

## Workflow Status Notification

Send workflow status back to GitHub as a commit status or check run:

```yaml
templates:
  - name: notify-github-status
    inputs:
      parameters:
        - name: sha
        - name: status  # pending, success, failure, error
        - name: description
    script:
      image: ghcr.io/cli/cli:latest
      command: [bash]
      source: |
        export HOME=/tmp
        source /secrets/github-authenticate.sh
        gh api --method POST \
          /repos/my-org/my-repo/statuses/{{inputs.parameters.sha}} \
          -f "state={{inputs.parameters.status}}" \
          -f "description={{inputs.parameters.description}}" \
          -f "context=argo-workflow"
```

This creates commit statuses that appear in GitHub PRs and commit views, showing whether the Argo workflow passed or failed.

---

## Security Considerations

| Concern | Mitigation |
| --------- | ------------ |
| Token exposure | Use GitHub App, not PAT; rotate credentials |
| Broad permissions | Request minimal scopes in App manifest |
| Secret leakage | Mount secrets read-only; don't log tokens |
| Rate limits | Cache tokens; batch operations; respect limits |

!!! warning "Never Log Tokens"
    GitHub tokens in logs can be scraped and abused. Use `set +x` around authentication code. Redirect sensitive output to `/dev/null`.

---

## Related

- [Basic CronWorkflow](basic.md): Scheduling fundamentals
- [RBAC Configuration](../templates/rbac.md): Secret access permissions
- [Cross-Workflow Communication](../composition/communication.md): Other integration patterns
