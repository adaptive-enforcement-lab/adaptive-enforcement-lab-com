---
date: 2025-12-24
authors:
  - mark
categories:
  - CI/CD
  - GitHub Actions
  - DevSecOps
description: >-
  Codecov worked in CI. Failed in release. Same token, different context. One missing line broke everything.
slug: one-line-secrets-inherit
---

# One Line: `secrets: inherit`

`CODECOV_TOKEN` worked perfectly in `ci.yml`.

Called `ci.yml` from `release.yml` as a reusable workflow. Codecov failed:

```text
Error: Token required - not valid tokenless upload
```

Same token. Same workflow. Different result.

<!-- more -->

---

## The Setup

Coverage reporting worked in the CI workflow:

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Run tests
        run: go test -coverprofile=coverage.out ./...

      - name: Upload coverage
        uses: codecov/codecov-action@v5
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
          files: ./coverage.out
```

**Result**: ✅ Coverage uploaded to Codecov successfully

---

## The Reusable Workflow

We made `ci.yml` reusable to call from `release.yml`:

```yaml
# .github/workflows/ci.yml
on:
  workflow_call:  # Make it reusable

jobs:
  test:
    # ... same as before
```

Then called it from the release workflow:

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    branches: [main]

jobs:
  ci:
    uses: ./.github/workflows/ci.yml
```

**Result**: ❌ Codecov upload failed

```text
Error: Token required - not valid tokenless upload
```

---

## The Confusion

The token was configured in repository secrets. It worked in direct workflow invocation.

Why did it fail when called as a reusable workflow?

Checked:

- ✅ Token exists in repository secrets
- ✅ Token has correct permissions
- ✅ Token value unchanged
- ✅ Workflow syntax valid
- ✅ Job permissions correct

Everything looked right. Codecov still failed.

---

## The Discovery

GitHub's security model for reusable workflows: **secrets don't inherit by default**.

When workflow A calls workflow B:

- Workflow B runs in isolated context
- Workflow B cannot access calling workflow's secrets
- Explicit permission required to pass secrets

**By design.** Security isolation prevents leaking secrets to untrusted reusable workflows.

The solution: **One line.**

```yaml
# .github/workflows/release.yml
jobs:
  ci:
    uses: ./.github/workflows/ci.yml
    secrets: inherit  # This was missing
```

**That's it.** `secrets: inherit` passes all secrets from the calling workflow to the reusable workflow.

---

## The Pattern

### Before (Broken)

```yaml
# release.yml
jobs:
  ci:
    uses: ./.github/workflows/ci.yml
    # Secrets NOT passed
```

### After (Working)

```yaml
# release.yml
jobs:
  ci:
    uses: ./.github/workflows/ci.yml
    secrets: inherit  # Pass all secrets
```

### Alternative (Selective)

```yaml
# release.yml
jobs:
  ci:
    uses: ./.github/workflows/ci.yml
    secrets:
      CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}
      # Only specific secrets passed
```

---

## The Security Implication

**Why secrets don't inherit by default:**

Reusable workflows could be from:

- External repositories (`org/repo/.github/workflows/reusable.yml@main`)
- Third-party actions
- Untrusted sources

Auto-inheriting secrets would expose them to potentially malicious code.

**`secrets: inherit` means**: "I trust this workflow with all my secrets."

Use it for:

- ✅ Internal reusable workflows (same repo)
- ✅ Workflows from trusted organization repos
- ⚠️ External workflows (understand what they do first)

---

## The Debugging Journey

1. **Codecov fails**: "Token required"
2. **Check token**: Token exists, valid
3. **Check permissions**: Workflow permissions correct
4. **Re-read documentation**: Found "reusable workflows" section
5. **Discovery**: Secrets isolation by default
6. **Fix**: Add `secrets: inherit`
7. **Test**: ✅ Works

Time wasted: 2 hours
Fix: 1 line
Lesson: Read the security model documentation first

---

## The Related Cases

This pattern applies to any secret used in reusable workflows:

**Deployment tokens**:

```yaml
jobs:
  deploy:
    uses: ./.github/workflows/deploy.yml
    secrets: inherit  # Pass GCP credentials
```

**Registry credentials**:

```yaml
jobs:
  publish:
    uses: ./.github/workflows/publish.yml
    secrets: inherit  # Pass GHCR token
```

**API keys**:

```yaml
jobs:
  notify:
    uses: ./.github/workflows/notify.yml
    secrets: inherit  # Pass Slack webhook
```

Same problem. Same solution.

---

## The Lesson

**Security by default is correct.** Secrets shouldn't leak to untrusted code.

But the error message doesn't help:

```text
Error: Token required - not valid tokenless upload
```

It should say:

```text
Error: CODECOV_TOKEN not found in workflow context.
Hint: When calling reusable workflows, use 'secrets: inherit' or pass secrets explicitly.
```

The security model is sound. The debugging experience could be better.

---

## What Changed

**Before**: "The token works in CI but fails in release. Codecov must be broken."

**After**: "Reusable workflows have isolated secret context. Pass secrets explicitly with `secrets: inherit`."

The difference is understanding the security model.

One line fixes it. But only if you know the line exists.

!!! tip "Implementation Guide"
    See [Zero-Vulnerability Pipelines](../../blog/posts/2025-12-15-zero-vulnerability-pipelines.md) for complete GitHub Actions workflow patterns including reusable workflow configuration and secrets management.

---

## Related Patterns

- **[Zero-Vulnerability Pipelines](2025-12-15-zero-vulnerability-pipelines.md)** - Reusable workflow context for security scanning
- **[SDLC Hardening](2025-12-12-harden-sdlc-before-audit.md)** - CI/CD patterns for compliance

---

*Codecov worked. Then failed. Same token, different context. Reusable workflows isolate secrets. One line fixed everything: `secrets: inherit`. Security by default is correct. Better error messages would help.*
