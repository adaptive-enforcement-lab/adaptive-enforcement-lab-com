---
title: CONTRIBUTING.md Template
description: >-
  Production-ready CONTRIBUTING.md template with development setup, code style, testing requirements, and PR process. Includes real example from readability project.
tags:
  - open-source
  - templates
  - contributing
  - openssf
  - developers
---

# CONTRIBUTING.md Template

Production-ready CONTRIBUTING.md template for open source projects. Annotated with placeholders for project-specific details, plus real example from OpenSSF-certified project.

!!! tip "Copy and Customize"
    Replace `[PROJECT_NAME]`, `[LANGUAGE]`, `[ORG]` and other placeholders with your project details. Update commands to match your tech stack.

---

## Template

````markdown
# Contributing to [PROJECT_NAME]

We welcome contributions! Here's how to get started.

## Reporting Bugs

Before creating a bug report, please check existing issues to avoid duplicates.

When reporting bugs, include:

- **Summary**: Brief description of the issue
- **Steps to Reproduce**: Minimal steps to reproduce the behavior
- **Expected vs Actual**: What should happen vs what actually happens
- **Environment**: OS, language version, project version
- **Logs/Screenshots**: Error messages or visual evidence

Use the [Bug Report template](.github/ISSUE_TEMPLATE/bug_report.yml) for structured reporting.

## Suggesting Features

Feature requests are welcome. When suggesting features:

- **Use Case**: Explain the problem this feature solves
- **Alternatives**: Describe alternatives you've considered
- **Implementation Ideas**: (Optional) Suggest how it could work

Use the [Feature Request template](.github/ISSUE_TEMPLATE/feature_request.yml).

## Development Setup

### Prerequisites

- [LANGUAGE] [VERSION] or higher
- [TOOL_1], [TOOL_2] (installation instructions link)
- [OPTIONAL_DEPENDENCY] (if applicable)

### Installation

```bash
# Clone repository
git clone https://github.com/[ORG]/[PROJECT_NAME].git
cd [PROJECT_NAME]

# Install dependencies
[INSTALL_COMMAND]  # e.g., npm install, pip install -r requirements.txt, go mod download

# Run tests to verify setup
[TEST_COMMAND]  # e.g., npm test, pytest, go test ./...
```

## Code Style

This project follows [STYLE_GUIDE] conventions.

- **Linter**: [LINTER_NAME] (config: [CONFIG_FILE])
- **Formatter**: [FORMATTER_NAME] (config: [CONFIG_FILE])
- **Pre-commit hooks**: Run `[PRECOMMIT_SETUP_COMMAND]` to install

Before committing:

```bash
[LINT_COMMAND]    # e.g., npm run lint, golangci-lint run
[FORMAT_COMMAND]  # e.g., npm run format, black ., gofmt -w .
```

## Testing Requirements

All contributions must include tests.

- **Unit tests**: Test individual functions/modules
- **Integration tests**: Test component interactions (if applicable)
- **Coverage threshold**: [XX]% minimum (enforced in CI)

Run tests:

```bash
[TEST_COMMAND]           # e.g., npm test, pytest, go test ./...
[COVERAGE_COMMAND]       # e.g., npm run test:coverage, pytest --cov
```

CI will fail if tests don't pass or coverage drops below threshold.

## Pull Request Process

1. **Fork and branch**: Create a feature branch from `main`
2. **Write tests**: Add tests for new functionality
3. **Ensure tests pass**: Run full test suite locally
4. **Update documentation**: Update README, docs, or code comments as needed
5. **Submit PR**: Reference related issues in PR description
6. **Wait for review**: Maintainers will review within [TIMEFRAME]

### PR Checklist

- [ ] Tests added for new functionality
- [ ] All tests pass
- [ ] Linter passes
- [ ] Coverage threshold met
- [ ] Documentation updated
- [ ] Commit messages are clear

## Commit Messages

Use clear, descriptive commit messages:

- **Format**: `type(scope): subject` (e.g., `fix(auth): resolve token expiry bug`)
- **Types**: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`
- **Subject**: Imperative mood, lowercase, no period

Example:

```text
feat(api): add pagination to user endpoint

- Add limit and offset query parameters
- Update tests for pagination
- Document new parameters in README
```

## Code Review

All PRs require:

- [ ] [NUMBER] approving review(s) from maintainers
- [ ] All status checks passing
- [ ] No unresolved review comments

Expect feedback within [TIMEFRAME]. We aim for constructive, respectful reviews.

## License

By contributing, you agree that your contributions will be licensed under the [LICENSE_NAME] License.

See [LICENSE](LICENSE) for details.
````

---

## Real Example from readability Project

````markdown
# Contributing to readability

Bug reports, feature requests, and pull requests are welcome.

## Reporting Bugs

Before creating a bug report, check existing issues to avoid duplicates.

When reporting bugs:

- **Summary**: Brief description
- **Steps to Reproduce**: Minimal steps
- **Expected vs Actual**: What should happen vs what happens
- **Environment**: OS, Go version, readability version
- **Logs**: Error messages or stack traces

Use the [Bug Report template](.github/ISSUE_TEMPLATE/bug_report.yml).

## Suggesting Features

Feature requests are welcome. Include:

- **Use Case**: Problem this solves
- **Alternatives**: Other approaches considered

Use the [Feature Request template](.github/ISSUE_TEMPLATE/feature_request.yml).

## Development Setup

### Prerequisites

- Go 1.23 or higher
- golangci-lint

### Installation

```bash
git clone https://github.com/adaptive-enforcement-lab/readability.git
cd readability
go mod download
go test ./...
```

## Code Style

- **Linter**: golangci-lint (config: `.golangci.yml`)
- **Formatter**: gofmt
- **Pre-commit**: `.pre-commit-config.yaml`

Before committing:

```bash
golangci-lint run
gofmt -w .
```

## Testing Requirements

All contributions require tests.

- **Unit tests**: `go test ./...`
- **Coverage**: 90% minimum (enforced in CI)

Run tests:

```bash
go test ./...
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out
```

## Pull Request Process

1. Fork and branch from `main`
2. Write tests
3. Ensure tests pass
4. Submit PR referencing related issues

### PR Checklist

- [ ] Tests added
- [ ] All tests pass
- [ ] golangci-lint passes
- [ ] Coverage ≥90%
- [ ] Docs updated

## License

Contributions licensed under MIT License. See [LICENSE](LICENSE).
````

---

## Customization Tips

**Language-Specific Commands**:

- **Go**: `go mod download`, `go test ./...`, `golangci-lint run`, `gofmt -w .`
- **Python**: `pip install -r requirements.txt`, `pytest`, `black .`, `pylint`
- **Node.js**: `npm install`, `npm test`, `npm run lint`, `npm run format`
- **Rust**: `cargo build`, `cargo test`, `cargo clippy`, `cargo fmt`

**Coverage Thresholds**:

- 90% is realistic for libraries
- 80% is acceptable for applications
- Lower is fine for prototypes

**Review Timeframes**:

- Active projects: "within 3 business days"
- Side projects: "within 1 week"
- Hobby projects: "when maintainers have time"

---

## Related Patterns

- [Open Source Templates](index.md) - Main overview
- [SECURITY Template](security-template.md) - Security disclosure template
- [Issue Templates](issue-templates.md) - GitHub issue form templates

---

*CONTRIBUTING.md closes the documentation gap. Development setup. Testing requirements. PR process. Code review expectations. Copy this template. Customize the placeholders. Commit. OpenSSF Badge criterion satisfied.*
