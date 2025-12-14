# Existence Checks

Skip creation when the resource already exists.

!!! note "Existence vs State"
    Existence checks verify **presence**, not **correctness**. For state validation, combine with content hashing.

---

## The Technique

Before creating a resource, check if it already exists. If it does, skip creation entirely.

```go
package main

import (
    "context"
    "log"

    "github.com/google/go-github/v57/github"
)

func ensureBranch(ctx context.Context, client *github.Client, owner, repo, branchName, baseSHA string) error {
    _, _, err := client.Repositories.GetBranch(ctx, owner, repo, branchName, 0)
    if err == nil {
        log.Printf("Branch %s exists, skipping creation", branchName)
        return nil
    }

    // Branch doesn't exist, create it
    ref := &github.Reference{
        Ref:    github.String("refs/heads/" + branchName),
        Object: &github.GitObject{SHA: github.String(baseSHA)},
    }
    _, _, err = client.Git.CreateRef(ctx, owner, repo, ref)
    return err
}
```

---

## When to Use

- Creating resources that should only exist once
- PR/branch/issue creation
- Cloud resource provisioning
- User/account creation
- Any "create if not exists" scenario

---

## Implementation Patterns

### GitHub Branch

```bash
# Check if branch exists before creating
if git ls-remote --heads origin "$BRANCH_NAME" | grep -q "$BRANCH_NAME"; then
  echo "Branch exists, skipping creation"
else
  git push origin "HEAD:refs/heads/$BRANCH_NAME"
fi
```

### GitHub Pull Request

```bash
# Check if PR exists before creating
PR_COUNT=$(gh pr list \
  --head "$BRANCH_NAME" \
  --base "$BASE_BRANCH" \
  --json number \
  --jq 'length')

if [ "$PR_COUNT" -gt 0 ]; then
  echo "PR already exists"
else
  gh pr create --head "$BRANCH_NAME" --base "$BASE_BRANCH" ...
fi
```

### Kubernetes Resource

```bash
# Check if resource exists before applying
if kubectl get deployment "$NAME" -n "$NAMESPACE" &>/dev/null; then
  echo "Deployment exists, skipping creation"
else
  kubectl apply -f deployment.yaml
fi
```

### Cloud Resources (GCS)

```go
package main

import (
    "context"
    "errors"
    "log"

    "cloud.google.com/go/storage"
)

func ensureBucket(ctx context.Context, client *storage.Client, projectID, bucketName string) error {
    bucket := client.Bucket(bucketName)
    _, err := bucket.Attrs(ctx)
    if err == nil {
        log.Printf("Bucket %s exists", bucketName)
        return nil
    }

    // Check if error is "not found"
    if !errors.Is(err, storage.ErrBucketNotExist) {
        return err // Some other error
    }

    // Bucket doesn't exist, create it
    return bucket.Create(ctx, projectID, nil)
}
```

---

## Check Methods by Platform

| Platform | Resource | Check Method |
| ---------- | ---------- | -------------- |
| GitHub | Branch | `git ls-remote --heads` |
| GitHub | PR | `gh pr list --head X --json number` |
| GitHub | Issue | `gh issue list --search "title"` |
| Kubernetes | Any | `kubectl get TYPE NAME` |
| GCS | Bucket | `bucket.Attrs()` |
| GCE | Instance | `instances.Get()` |
| OCI | Image | `crane manifest IMAGE` |
| OCI | Container | `crictl inspect` |

---

## Existence vs State

Existence checks only verify **presence**, not **correctness**:

```bash
# This checks existence
if kubectl get deployment myapp &>/dev/null; then
  echo "Exists"
fi

# This checks state (replicas, image, etc.)
CURRENT=$(kubectl get deployment myapp -o json)
if [ "$CURRENT" = "$DESIRED" ]; then
  echo "State matches"
fi
```

For state validation, combine with [Content Hashing](content-hashing.md).

---

## Race Conditions

Existence checks have a time-of-check-to-time-of-use (TOCTOU) gap:

```go
// BAD: Race condition possible
if !resourceExists(name) {
    createResource(name) // Might fail if created between check and create
}

// BETTER: Handle conflict gracefully
err := createResource(name)
if errors.Is(err, ErrAlreadyExists) {
    log.Println("Resource created by another process, continuing")
    return nil
}
return err
```

---

## Soft Existence

Some resources can exist in multiple states:

| State | Behavior |
| ------- | ---------- |
| Active | Skip creation |
| Deleted/Archived | May need recreation |
| Pending | Wait or skip |
| Failed | May need cleanup first |

```go
func ensureResource(ctx context.Context, name string) error {
    resource, err := getResource(ctx, name)
    if errors.Is(err, ErrNotFound) {
        return createResource(ctx, name)
    }
    if err != nil {
        return err
    }

    switch resource.Status {
    case StatusDeleted:
        return restoreResource(ctx, name)
    case StatusFailed:
        if err := deleteResource(ctx, name); err != nil {
            return err
        }
        return createResource(ctx, name)
    default:
        // Active or pending - skip
        log.Printf("Resource %s exists with status %s", name, resource.Status)
        return nil
    }
}
```

---

## Related

- [Content Hashing](content-hashing.md) - Verify state, not just existence
- [Idempotency: Check-Before-Act](../../idempotency/patterns/check-before-act.md) - Related idempotency pattern
- [Techniques Overview](index.md) - All work avoidance techniques
