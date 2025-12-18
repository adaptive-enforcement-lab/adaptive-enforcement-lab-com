---
description: >-
  Production-grade Go CLI patterns, automated release workflows with Release Please, versioned docs, and coverage enforcement for DevSecOps build pipelines.
tags:
  - ci-cd
  - automation
  - testing
  - developers
  - github-actions
---

# Build

Development tools and release processes.

!!! abstract "Build with Intent"

    Building secure, tested, versioned software requires more than writing code. It requires **architecture**, **testing discipline**, **release automation**, and **documentation workflows** that scale from prototype to production.

## Overview

This section covers the development practices, tooling choices, and automation patterns that turn code into deployable, documented, versioned artifacts.

## What You'll Find Here

### Go CLI Architecture

Comprehensive guidance for building production-grade Go CLIs with Kubernetes integration, robust testing, and operational packaging.

**Why it matters**: CLIs are the interface to your automation. Poor CLI design creates operational friction. Good CLI design makes complex operations simple.

**Key topics**:

- Framework selection (Cobra vs others)
- Viper configuration management
- Kubernetes client integration
- Client-go patterns (list, watch, patch, rollout restart)
- RBAC setup for service accounts
- Command architecture (orchestrator pattern, subcommands, I/O contracts)
- Packaging (containers, Helm charts, GitHub Actions)
- Testing strategies (unit, integration, E2E)

**Content**: 21 pages covering the full lifecycle from framework selection to release automation.

### Coverage Patterns

Testing strategies, coverage measurement, and enforcement patterns that maintain code quality without slowing down development.

**Why it matters**: Code without tests is code that breaks in production. But chasing 100% coverage wastes time on low-value tests. These patterns optimize for meaningful coverage.

**Key topics**:

- Coverage thresholds (when 80% is enough, when 95% is required)
- Differential coverage (new code only)
- Testing pyramid (unit vs integration vs E2E ratios)
- Mocking strategies
- Test quality metrics (not just coverage percentage)

### Release Pipelines

Automated release workflows using Release Please for conventional commits, semantic versioning, and changelog generation.

**Why it matters**: Manual releases are error-prone, time-consuming, and don't scale. Automated releases with Release Please turn commits into releases with zero human intervention.

**Key topics**:

- Release Please configuration
- Release types (simple, go, python, node, helm)
- Extra-files pattern (update multiple files on release)
- Workflow integration (trigger deployments on release)
- Change detection (monorepo support)
- Protected branch workflows

**Content**: 8 pages covering Release Please setup, configuration, and troubleshooting.

### Versioned Documentation

Documentation versioning with Mike for maintaining docs across multiple software versions without duplication.

**Why it matters**: Users running v1.0 need v1.0 docs, not v2.0 docs. Versioned docs prevent confusion and reduce support burden.

**Key topics**:

- Mike configuration and integration
- Version strategy (semver, latest, stable)
- CI/CD pipeline integration
- GitHub Pages deployment
- Version switcher UI

## Common Workflows

### 1. Go CLI with Kubernetes Integration

```go
// Command orchestration pattern
func NewRolloutRestartCmd() *cobra.Command {
    return &cobra.Command{
        Use:   "rollout-restart",
        Short: "Restart deployments",
        RunE: func(cmd *cobra.Command, args []string) error {
            // Load config
            cfg, err := LoadConfig()
            if err != nil {
                return fmt.Errorf("config load failed: %w", err)
            }

            // Create K8s client
            client, err := kubernetes.NewForConfig(cfg)
            if err != nil {
                return fmt.Errorf("client creation failed: %w", err)
            }

            // Execute operation
            return rolloutRestart(client, args[0])
        },
    }
}
```

### 2. Release Please Configuration

```json
{
  "release-type": "go",
  "packages": {
    ".": {
      "release-type": "go",
      "extra-files": [
        "helm/Chart.yaml",
        "README.md"
      ]
    }
  }
}
```

### 3. Versioned Docs Pipeline

```yaml
# .github/workflows/docs.yml
name: Deploy Versioned Docs
on:
  release:
    types: [published]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Need full history for mike
      - uses: actions/setup-python@v4
        with:
          python-version: 3.x
      - run: pip install mkdocs-material mike
      - name: Deploy version
        run: |
          git config user.name ci-bot
          git config user.email ci-bot@example.com
          mike deploy --push --update-aliases ${{ github.ref_name }} latest
```

### 4. Coverage Enforcement

```yaml
# .github/workflows/test.yml
- name: Run tests with coverage
  run: go test -v -coverprofile=coverage.out ./...

- name: Enforce coverage threshold
  run: |
    coverage=$(go tool cover -func=coverage.out | grep total | awk '{print $3}' | sed 's/%//')
    threshold=80
    if (( $(echo "$coverage < $threshold" | bc -l) )); then
      echo "Coverage $coverage% is below threshold $threshold%"
      exit 1
    fi
```

## Integration with Secure and Enforce

Build processes integrate with security and enforcement:

1. **Build artifacts** (Build) → **Scan for vulnerabilities** ([Secure](../secure/index.md)) → **Block vulnerable images** ([Enforce](../enforce/index.md))
2. **Run tests** (Build) → **Enforce coverage** ([Enforce](../enforce/index.md)) → **Gate PR merge** ([Enforce](../enforce/index.md))
3. **Generate SBOM** ([Secure](../secure/index.md)) → **Attach to release** (Build) → **Require in deployment** ([Enforce](../enforce/index.md))
4. **Create release** (Build) → **Generate SLSA provenance** ([Enforce](../enforce/index.md)) → **Verify in deployment** ([Enforce](../enforce/index.md))

## Development Workflow

Typical development flow using these patterns:

```mermaid
graph LR
    A[Write Code] --> B[Pre-commit Hooks]
    B --> C[Commit]
    C --> D[Push to PR]
    D --> E[CI: Tests + Coverage]
    E --> F[CI: Security Scan]
    F --> G[Status Checks Pass]
    G --> H[Peer Review]
    H --> I[Merge to Main]
    I --> J[Release Please PR]
    J --> K[Merge Release PR]
    K --> L[GitHub Release]
    L --> M[Deploy Artifacts]
```

## Getting Started

### For New Go Projects

1. **Choose CLI framework**: Start with Cobra for rich CLIs, flag for simple tools
2. **Set up testing**: Unit tests first, integration tests second, E2E tests last
3. **Add coverage enforcement**: 80% threshold for most projects
4. **Configure Release Please**: Automate versioning and changelogs
5. **Add SBOM generation**: Attach to releases for supply chain transparency

### For Existing Projects

1. **Add coverage measurement**: Establish baseline
2. **Automate releases**: Replace manual releases with Release Please
3. **Improve test quality**: Focus on meaningful tests, not coverage percentage
4. **Version your docs**: Add Mike for multi-version documentation

## Common Challenges

### "100% coverage is impossible"

**Reality**: 100% coverage is rarely the right goal. Some code (error handling for impossible conditions, generated code) doesn't need tests.

**Solution**: Target 80-90% coverage. Focus on testing critical paths and business logic.

### "Release automation is too complex"

**Reality**: Manual releases are more complex (and error-prone) than automation.

**Solution**: Start with Release Please for conventional commits. Expand to SLSA provenance and SBOM generation incrementally.

### "Our docs are too complex to version"

**Reality**: Complex docs benefit the most from versioning.

**Solution**: Start with Mike for simple version switching. Use version warnings for deprecated features.

## Testing Strategy

### Unit Tests (70% of tests)

- Fast (< 1ms per test)
- No external dependencies
- Test business logic, algorithms, data transformations

### Integration Tests (20% of tests)

- Moderate speed (< 100ms per test)
- Real dependencies (databases, APIs in containers)
- Test component interactions

### E2E Tests (10% of tests)

- Slow (seconds per test)
- Full system deployment
- Test critical user journeys only

**Why this ratio?** Fast tests give fast feedback. Slow tests catch integration issues. Most bugs are found in unit tests, not E2E tests.

## Release Checklist

Before every release:

- [ ] Tests pass (unit, integration, E2E)
- [ ] Coverage threshold met (80%+)
- [ ] Security scan passes (no high/critical CVEs)
- [ ] SBOM generated
- [ ] SLSA provenance generated (if required)
- [ ] Changelog updated (Release Please automates this)
- [ ] Version bumped (Release Please automates this)
- [ ] Documentation versioned (if public API changed)

## Related Content

- [Secure](../secure/index.md): Security scanning and SBOM generation
- [Enforce](../enforce/index.md): Testing enforcement and compliance
- [Patterns](../patterns/index.md): CI/CD patterns and architecture

## Tags

Browse all content tagged with:

- [ci-cd](/tags/#ci-cd) - All CI/CD content
- [automation](/tags/#automation) - Automated build workflows
- [testing](/tags/#testing) - Testing strategies
- [go](/tags/#go) - Go development
