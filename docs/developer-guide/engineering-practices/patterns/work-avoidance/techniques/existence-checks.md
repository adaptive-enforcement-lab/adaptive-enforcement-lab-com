# Existence Checks

Skip creation when the resource already exists.

---

## The Technique

Before creating a resource, check if it already exists. If it does, skip creation entirely.

```python
def ensure_branch(repo, branch_name: str, base_sha: str) -> None:
    try:
        repo.get_branch(branch_name)
        log(f"Branch {branch_name} exists, skipping creation")
    except GithubException as e:
        if e.status == 404:
            repo.create_git_ref(f"refs/heads/{branch_name}", base_sha)
        else:
            raise
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

### Cloud Resources (Terraform-style)

```python
def ensure_bucket(name: str, region: str) -> None:
    try:
        s3.head_bucket(Bucket=name)
        log(f"Bucket {name} exists")
    except ClientError as e:
        if e.response['Error']['Code'] == '404':
            s3.create_bucket(Bucket=name, ...)
        else:
            raise
```

---

## Check Methods by Platform

| Platform | Resource | Check Method |
|----------|----------|--------------|
| GitHub | Branch | `git ls-remote --heads` |
| GitHub | PR | `gh pr list --head X --json number` |
| GitHub | Issue | `gh issue list --search "title"` |
| Kubernetes | Any | `kubectl get TYPE NAME` |
| AWS S3 | Bucket | `head_bucket()` |
| AWS EC2 | Instance | `describe_instances(Filters=...)` |
| Docker | Image | `docker image inspect` |
| Docker | Container | `docker container inspect` |

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

```python
# BAD: Race condition possible
if not resource_exists():
    create_resource()  # Might fail if created between check and create

# BETTER: Use atomic operations where available
try:
    create_resource_if_not_exists()  # Single atomic operation
except AlreadyExistsError:
    pass

# OR: Handle conflict gracefully
try:
    create_resource()
except AlreadyExistsError:
    log("Resource created by another process, continuing")
```

---

## Soft Existence

Some resources can exist in multiple states:

| State | Behavior |
|-------|----------|
| Active | Skip creation |
| Deleted/Archived | May need recreation |
| Pending | Wait or skip |
| Failed | May need cleanup first |

```python
def ensure_resource(name: str) -> None:
    resource = get_resource(name)

    if resource is None:
        create_resource(name)
    elif resource.status == 'deleted':
        # Restore or recreate
        restore_resource(name)
    elif resource.status == 'failed':
        # Cleanup and recreate
        delete_resource(name)
        create_resource(name)
    else:
        # Active or pending - skip
        log(f"Resource {name} exists with status {resource.status}")
```

---

## Related

- [Content Hashing](content-hashing.md) - Verify state, not just existence
- [Idempotency: Check-Before-Act](../../idempotency/patterns/check-before-act.md) - Related idempotency pattern
- [Techniques Overview](index.md) - All work avoidance techniques
