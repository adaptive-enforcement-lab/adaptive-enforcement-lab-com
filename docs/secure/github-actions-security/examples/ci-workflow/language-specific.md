---
title: Language-Specific CI Workflows
description: >-
  Hardened CI workflows for Node.js, Python, and Go with security controls
---

```

### Go CI

Hardened CI for Go projects with static analysis and vulnerability scanning.

```yaml
name: Go CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  test:
    name: Test on Go ${{ matrix.go-version }}
    runs-on: ubuntu-latest
    permissions:
      contents: read
    strategy:
      fail-fast: true
      matrix:
        go-version: ['1.21', '1.22']
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      - uses: actions/setup-go@93397bea11091df50f3d7e59dc26a7711a8bcfbe  # v4.1.0
        with:
          go-version: ${{ matrix.go-version }}
          cache: true

      # SECURITY: Download dependencies with verification
      - name: Download dependencies
        run: go mod download

      # SECURITY: Verify dependencies match go.sum
      - name: Verify dependencies
        run: go mod verify

      # SECURITY: Run Go security checker
      - name: Run govulncheck
        run: |
          go install golang.org/x/vuln/cmd/govulncheck@latest
          govulncheck ./...

      # SECURITY: Run staticcheck for code quality and security issues
      - name: Run staticcheck
        run: |
          go install honnef.co/go/tools/cmd/staticcheck@latest
          staticcheck ./...

      - name: Run tests
        run: go test -race -coverprofile=coverage.out -covermode=atomic ./...

      - name: Upload coverage
        uses: codecov/codecov-action@e0b68c6749509c5f83f984dd99a76a1c1a231044  # v4.0.1
        with:
          files: ./coverage.out
          fail_ci_if_error: false

  security-scan:
    name: Security Scanning
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      # SECURITY: CodeQL for Go static analysis
      - uses: github/codeql-action/init@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          languages: go
          queries: security-extended

      - uses: github/codeql-action/autobuild@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4

      - uses: github/codeql-action/analyze@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4

      # SECURITY: Gosec for Go-specific security issues
      - name: Run Gosec
        uses: securego/gosec@c6131d00402c4f9b60c815179b03bdad482e62c4  # v2.18.2
        with:
          args: '-no-fail -fmt sarif -out gosec.sarif ./...'

      - name: Upload Gosec results
        uses: github/codeql-action/upload-sarif@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          sarif_file: gosec.sarif
```

## Advanced Security Patterns

### Fork PR Security with Two-Stage Workflow

Safely handle fork PRs with staged execution: tests run on untrusted code, deployment requires approval.

```yaml
name: Fork PR CI
on:
  pull_request:
    # SECURITY: pull_request runs fork code in isolated context
    # Fork PRs get read-only token, no secrets
    branches: [main]

permissions:
  contents: read

jobs:
  # Stage 1: Run untrusted code from forks with minimal permissions
  test-fork:
    runs-on: ubuntu-latest
    permissions:
      contents: read  # Read-only access
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          # SECURITY: Check out PR head (untrusted code)
          ref: ${{ github.event.pull_request.head.sha }}
          persist-credentials: false

      - uses: actions/setup-node@5e21ff4d9bc1a8cf6de233a3057d20ec6b3fb69d  # v3.8.1
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci

      # SECURITY: Run tests without secrets or write permissions
      - name: Run tests
        run: npm test

      # SECURITY: Save test results for trusted workflow
      - name: Save test results
        uses: actions/upload-artifact@c7d193f32edcb7bfad88892161225aeda64e9392  # v4.0.0
        with:
          name: test-results
          path: test-results/
```

### Post PR comment with test results (separate workflow)

```yaml
# .github/workflows/fork-pr-comment.yml
# SECURITY: workflow_run trigger runs in repository context (trusted)
# This workflow can access secrets and write to PRs
name: Post Fork PR Results
on:
  workflow_run:
    workflows: ["Fork PR CI"]
    types:
      - completed

permissions:
  pull-requests: write
  actions: read

jobs:
  comment:
    runs-on: ubuntu-latest
    if: github.event.workflow_run.conclusion == 'success'
    steps:
      - name: Download test results
        uses: actions/github-script@60a0d83039c74a4aee543508d2ffcb1c3799cdea  # v7.0.1
        with:
          script: |
            const artifacts = await github.rest.actions.listWorkflowRunArtifacts({
              owner: context.repo.owner,
              repo: context.repo.repo,
              run_id: ${{ github.event.workflow_run.id }},
            });
            const artifact = artifacts.data.artifacts.find(a => a.name === 'test-results');
            if (artifact) {
              const download = await github.rest.actions.downloadArtifact({
                owner: context.repo.owner,
                repo: context.repo.repo,
                artifact_id: artifact.id,
                archive_format: 'zip',
              });
              // Process and post results
            }
```

### Secret Scanning Prevention

Prevent credential leaks before they reach the repository.

```yaml
name: Pre-commit Secret Scanning
on:
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  secret-scan:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          # SECURITY: Fetch full history to scan all commits in PR
          fetch-depth: 0
          persist-credentials: false

      # SECURITY: gitleaks scans for hardcoded secrets
      - name: Run gitleaks
        uses: gitleaks/gitleaks-action@cb7149a9c69f0f7c6a0c5b7b094889a91831ff7f  # v2.3.2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GITLEAKS_ENABLE_COMMENTS: false  # Don't expose findings in PR comments

      # SECURITY: Fail workflow if secrets detected
      - name: Fail on secret detection
        if: steps.gitleaks.outputs.exitcode == 1
        run: |
          echo "::error::Secrets detected in commit history. Remove before merging."
          exit 1
```

## Security Checklist

Use this checklist to verify your CI workflow follows security best practices.

### Action Security

- [ ] All third-party actions pinned to full SHA-256 commit hashes
- [ ] Version comments added for human readability (`# vX.Y.Z`)
- [ ] Dependabot configured to update action pins
- [ ] Actions from verified publishers or GitHub-maintained only
- [ ] No community actions without security review

### Permission Security

- [ ] Workflow-level permissions set to minimal (`contents: read`)
- [ ] Job-level permissions escalate only when required
- [ ] No `permissions: write-all` or default write permissions
- [ ] `security-events: write` only on security scan jobs
