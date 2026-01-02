---
description: >-
  Deploy pre-commit hooks with TruffleHog secrets detection, linting, and policy enforcement to block bad code from entering git history across your organization.
tags:
  - pre-commit
  - secrets-detection
  - git-hooks
  - trufflehog
  - linting
---

# Phase 1: Pre-commit Hooks

Block bad code from ever entering git history.

!!! success "Real-World Impact"
    A fintech client deployed pre-commit hooks across 200 repositories in 2 weeks. Within 48 hours, the hooks blocked 14 attempted commits containing AWS keys, GCP service account tokens, and database credentials. None entered git history.

---

## Secrets Detection

### Install TruffleHog

- [ ] **Install TruffleHog in `.pre-commit-config.yaml`**

  ```yaml
  repos:
    - repo: https://github.com/trufflesecurity/trufflehog
      rev: v3.63.0
      hooks:
        - id: trufflehog
          name: TruffleHog
          entry: trufflehog filesystem --fail --no-update
          language: system
  ```

  **How to validate**:

  ```bash
  cd your-repo
  pip install pre-commit
  pre-commit install
  # Attempt to commit AWS key in a file
  echo "gcp_service_account_key=AKIAIOSFODNN7EXAMPLE" > .env
  git add .env
  git commit -m "test"  # Should be blocked

  ```

  **Why it matters**: Credentials in git history are permanent. Rotation doesn't help if the entire history is exposed. Pre-commit catches them before they enter the repository.

!!! tip "Detection Patterns"
    TruffleHog uses entropy analysis and regex patterns. It catches API keys, private keys, tokens, and passwords. False positives are rare with v3.63.0+ entropy tuning.

---

## Linting and Format Checks

### Standard Linting Hooks

- [ ] **Add standard linting hooks**

  ```yaml
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-json
      - id: check-merge-conflict
  ```

  **How to validate**:

  ```bash
  # Test YAML validation
  echo "invalid: [yaml" > test.yaml
  git add test.yaml
  git commit -m "test"  # Should be blocked
  ```

  **Why it matters**: Format violations waste CI time and create noise in diffs. Catch them locally before pushing.

---

## Language-Specific Linters

### Go and Python Linters

- [ ] **Add Go, Python, or language-specific linters**

  ```yaml
  - repo: https://github.com/golangci/golangci-lint
    rev: v1.55.0
    hooks:
      - id: golangci-lint

  - repo: https://github.com/psf/black
    rev: 23.12.0
    hooks:
      - id: black
        language_version: python3

  ```

  **How to validate**:

  ```bash
  # Make a linting violation
  echo "x=1" >> main.go  # Missing formatting
  git add main.go
  git commit -m "test"  # Should fail linting
  ```

  **Why it matters**: Code quality standards are enforced locally before they waste CI cycles or reach code review.

---

## Policy Enforcement Hooks

### Custom Organizational Policies

- [ ] **Add custom hooks to enforce organizational policies**

  ```yaml
  - repo: local
    hooks:
      - id: check-forbidden-tech
        name: Block forbidden technologies
        entry: scripts/check-forbidden-tech.sh
        language: script
        files: \.(md|yaml|yml|sh|tf|Dockerfile|Containerfile)$

      - id: check-license-headers
        name: Require license headers
        entry: scripts/check-license-headers.sh
        language: script
        files: \.(go|py|js|ts)$

  ```

  **How to validate**:

  ```bash
  # Create forbidden technology reference
  echo "UNAPPROVED_LIBRARY=1.0" > config.yaml
  git add config.yaml
  git commit -m "test"  # Should fail if forbidden
  ```

  **Why it matters**: Organizational policies (vendor choices, license compliance, architecture standards) are enforced before code reaches review.

!!! example "Custom Policy Example"
    A healthcare client created a hook that blocks commits containing PHI regex patterns (SSN, patient IDs). No PHI in git history = automatic HIPAA compliance evidence.

---

## Organization-Wide Rollout

### Distribute Pre-commit Config

- [ ] **Distribute `.pre-commit-config.yaml` to all repositories**

  ```yaml
  # .github/workflows/distribute-pre-commit.yml
  name: Distribute Pre-commit Config
  on:
    schedule:
      - cron: '0 0 * * 0'  # Weekly
  jobs:
    distribute:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - name: Copy to all repos
          env:
            GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          run: |
            for repo in $(gh repo list org --limit 1000 --json name --jq '.[].name'); do
              gh api repos/org/$repo/contents/.pre-commit-config.yaml \
                --method PUT \
                --field message="chore: sync pre-commit config" \
                --field content="$(base64 .pre-commit-config.yaml)" 2>/dev/null || true
            done

  ```

  **How to validate**:

  ```bash
  # Check that N repositories have the config
  gh repo list org --limit 1000 --json nameWithOwner | \
    jq -r '.[].nameWithOwner' | while read repo; do
      gh api repos/$repo/contents/.pre-commit-config.yaml >/dev/null 2>&1 && echo "✅ $repo"
    done | wc -l
  ```

  **Why it matters**: Undeployed controls don't enforce anything. Automation ensures consistency across the organization.

---

## Common Issues and Solutions

**Issue**: Pre-commit hooks don't run for some developers

**Solution**: Add to repository README:

```markdown
## Setup

pip install pre-commit
pre-commit install

Run manually before first commit: pre-commit run --all-files
```

**Issue**: Developers complain about "too many checks"

**Solution**: Show the evidence. One blocked secret key saves the company from breach notification costs, regulatory fines, and reputation damage. The friction is intentional.

---

## Related Patterns

- **[Branch Protection →](branch-protection.md)** - GitHub repository protection
- **[Phase 1 Overview →](index.md)** - Foundation phase summary
- **[Implementation Roadmap](index.md)** - Complete roadmap

---

*Pre-commit hooks deployed. Secrets blocked at source. Code quality enforced locally.*
