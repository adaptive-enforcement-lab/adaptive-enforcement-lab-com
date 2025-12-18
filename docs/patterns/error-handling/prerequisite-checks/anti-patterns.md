---
description: >-
  Avoid scattered checks, silent failures, and incomplete validation. Learn what not to do when implementing prerequisite validation in deployment automation.
---

# Anti-Patterns

Common mistakes when implementing prerequisite checks.

!!! danger "Recognize These Mistakes"
    Each anti-pattern here has caused production incidents. Learn to spot them before they cause problems.

---

## 1. Scattered Prerequisites

Checking prerequisites throughout the code instead of upfront.

```go
// Bad: prerequisites scattered
func Deploy(config Config) error {
    if config.Namespace == "" {
        return errors.New("namespace required")
    }
    client, err := NewClient()
    if err != nil {
        return err
    }
    if config.Image == "" {
        return errors.New("image required")  // Too late!
    }
    // ...
}

// Good: consolidated prerequisites
func Deploy(config Config) error {
    if err := config.Validate(); err != nil {
        return err
    }
    // All prerequisites passed, proceed
    client, err := NewClient()
    // ...
}
```

---

## 2. Silent Prerequisites

Not reporting which prerequisite failed.

```bash
# Bad: which check failed?
check_prerequisites() {
    command -v kubectl >/dev/null && \
    command -v helm >/dev/null && \
    kubectl auth can-i create deployments
}

# Good: report specific failure
check_prerequisites() {
    command -v kubectl >/dev/null || { echo "kubectl not found"; return 1; }
    command -v helm >/dev/null || { echo "helm not found"; return 1; }
    kubectl auth can-i create deployments || { echo "No deploy permission"; return 1; }
}
```

---

## 3. Incomplete Prerequisites

Missing critical checks.

```yaml
# Bad: doesn't check if image exists
- name: Deploy
  run: kubectl set image deployment/app app=$IMAGE

# Good: verify image exists first
- name: Check image exists
  run: |
    docker manifest inspect $IMAGE || {
      echo "Image $IMAGE not found in registry"
      exit 1
    }

- name: Deploy
  run: kubectl set image deployment/app app=$IMAGE
```

---

## 4. Prerequisites That Change State

Prerequisites should be read-only.

```go
// Bad: prerequisite creates resource
func checkNamespace(name string) error {
    _, err := client.GetNamespace(name)
    if err != nil {
        // Creates namespace as side effect!
        return client.CreateNamespace(name)
    }
    return nil
}

// Good: prerequisite only checks
func checkNamespace(name string) error {
    _, err := client.GetNamespace(name)
    if err != nil {
        return fmt.Errorf("namespace %s does not exist", name)
    }
    return nil
}
```
