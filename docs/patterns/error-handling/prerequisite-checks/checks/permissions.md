---
title: Permission Checks
description: >-
  Permission validation checks for API tokens, GitHub Apps, Kubernetes RBAC, and cloud IAM roles before operations.
tags:
  - prerequisite-checks
  - permissions
  - rbac
  - iam
---
# Permission Checks

Verify access rights before attempting operations.

!!! tip "Principle of Least Privilege"
    Request only the minimum permissions required. Overly broad permissions increase security risk. Use scoped tokens and role-based access control (RBAC).

---

## API Token Scopes

```yaml
- name: Verify GitHub token permissions
  run: |
    # Check token has required scopes
    gh api user --jq '.permissions' > /tmp/perms.json

    required=(
      "repo"
      "write:packages"
      "workflow"
    )

    for scope in "${required[@]}"; do
      if ! jq -e ".${scope}" /tmp/perms.json >/dev/null; then
        echo "::error::Token missing required scope: $scope"
        exit 1
      fi
    done

    echo "Token permissions verified"
```

---

## GitHub App Permissions

```bash
# Verify GitHub App has required permissions
check_app_permissions() {
    local repo="$1"

    # Get installation permissions
    gh api "repos/${repo}/installation" --jq '.permissions' > /tmp/app_perms.json

    # Required permissions
    local required=(
        "contents:write"
        "pull_requests:write"
        "metadata:read"
    )

    for perm in "${required[@]}"; do
        key="${perm%:*}"
        level="${perm#*:}"

        actual=$(jq -r ".${key}" /tmp/app_perms.json)
        if [[ "$actual" != "$level" && "$actual" != "write" ]]; then
            echo "ERROR: App missing permission: $perm (has: $actual)"
            return 1
        fi
    done

    echo "App permissions verified"
}
```

---

## Kubernetes RBAC

```go
func validateK8sPermissions(ctx context.Context, client *kubernetes.Clientset, namespace string) error {
    // Check if we can create deployments
    sar := &authv1.SelfSubjectAccessReview{
        Spec: authv1.SelfSubjectAccessReviewSpec{
            ResourceAttributes: &authv1.ResourceAttributes{
                Namespace: namespace,
                Verb:      "create",
                Group:     "apps",
                Version:   "v1",
                Resource:  "deployments",
            },
        },
    }

    result, err := client.AuthorizationV1().SelfSubjectAccessReviews().Create(ctx, sar, metav1.CreateOptions{})
    if err != nil {
        return fmt.Errorf("permission check failed: %w", err)
    }

    if !result.Status.Allowed {
        return fmt.Errorf("insufficient permissions: cannot create deployments in namespace %s", namespace)
    }

    return nil
}
```

---

## Cloud IAM Roles

```bash
# Verify GCP service account has required roles
check_gcp_permissions() {
    local project="$1"
    local sa_email="$2"

    required_roles=(
        "roles/storage.objectAdmin"
        "roles/container.developer"
        "roles/cloudkms.cryptoKeyEncrypterDecrypter"
    )

    for role in "${required_roles[@]}"; do
        if ! gcloud projects get-iam-policy "$project" \
            --flatten="bindings[].members" \
            --filter="bindings.role:$role AND bindings.members:serviceAccount:$sa_email" \
            --format="value(bindings.role)" | grep -q "$role"; then
            echo "ERROR: Service account missing role: $role"
            return 1
        fi
    done

    echo "IAM permissions verified"
}
```

---

## Back to Prerequisites

- [Prerequisite Checks](../index.md) - Pattern overview
- [Environment Checks](environment.md) - Tools, variables, connectivity
- [State Checks](state.md) - Resources, health, conflicts
- [Input Validation](input.md) - Required, format, cross-field
- [Dependency Checks](dependencies.md) - Jobs, artifacts, services
- [Implementation Patterns](../implementation.md) - Ordering, patterns, anti-patterns
