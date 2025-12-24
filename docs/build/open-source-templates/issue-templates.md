---
title: GitHub Issue Templates
description: >-
  YAML form templates for bug reports and feature requests with structured fields and validation. Production-ready templates for GitHub issue forms.
tags:
  - open-source
  - templates
  - github
  - issues
  - developers
---

# GitHub Issue Templates

YAML form templates for structured bug reports and feature requests. Ensure reporters provide necessary information with required fields and validation.

!!! tip "Structured Reporting"
    YAML forms replace blank issues with structured fields. Required fields ensure reporters provide environment details, reproduction steps, and logs.

---

## Bug Report Template

`.github/ISSUE_TEMPLATE/bug_report.yml`:

```yaml
name: Bug Report
description: Report a bug or unexpected behavior
title: "[Bug]: "
labels: ["bug", "triage"]
body:
  - type: markdown
    attributes:
      value: |
        Thanks for taking the time to report a bug! Fill out the form below to help us reproduce and fix it.

  - type: textarea
    id: summary
    attributes:
      label: Bug Summary
      description: Brief description of what went wrong
      placeholder: "When I do X, Y happens instead of Z"
    validations:
      required: true

  - type: textarea
    id: reproduce
    attributes:
      label: Steps to Reproduce
      description: Minimal steps to reproduce the behavior
      placeholder: |
        1. Run command `...`
        2. With input `...`
        3. See error
    validations:
      required: true

  - type: textarea
    id: expected
    attributes:
      label: Expected Behavior
      description: What should have happened?
    validations:
      required: true

  - type: textarea
    id: actual
    attributes:
      label: Actual Behavior
      description: What actually happened?
    validations:
      required: true

  - type: textarea
    id: environment
    attributes:
      label: Environment
      description: OS, language version, project version
      placeholder: |
        - OS: macOS 14.0
        - [LANGUAGE] version: [VERSION]
        - Project version: v1.2.3
    validations:
      required: true

  - type: textarea
    id: logs
    attributes:
      label: Logs or Screenshots
      description: Paste relevant error messages or attach screenshots
      render: shell

  - type: textarea
    id: additional
    attributes:
      label: Additional Context
      description: Any other relevant information
```

---

## Feature Request Template

`.github/ISSUE_TEMPLATE/feature_request.yml`:

```yaml
name: Feature Request
description: Suggest a new feature or enhancement
title: "[Feature]: "
labels: ["enhancement"]
body:
  - type: markdown
    attributes:
      value: |
        Thanks for suggesting a feature! Fill out the form to help us understand your use case.

  - type: textarea
    id: problem
    attributes:
      label: Problem Description
      description: What problem does this feature solve?
      placeholder: "I'm frustrated when..."
    validations:
      required: true

  - type: textarea
    id: solution
    attributes:
      label: Proposed Solution
      description: How should this feature work?
      placeholder: "I think the tool should..."
    validations:
      required: true

  - type: textarea
    id: alternatives
    attributes:
      label: Alternatives Considered
      description: What other approaches have you considered?
      placeholder: "I tried using X, but..."

  - type: textarea
    id: additional
    attributes:
      label: Additional Context
      description: Any other relevant information (mockups, examples, etc.)
```

---

## Template Config

`.github/ISSUE_TEMPLATE/config.yml`:

```yaml
blank_issues_enabled: false
contact_links:
  - name: Security Vulnerability
    url: https://github.com/[ORG]/[PROJECT_NAME]/security/advisories/new
    about: Please report security vulnerabilities through GitHub Security Advisories, not public issues
```

**Key Settings**:

- `blank_issues_enabled: false` - Forces users to use templates
- `contact_links` - Redirects security reports to Security Advisories

---

## Customization Tips

**Labels**:

Adjust labels to match your project:

- Bug reports: `["bug", "triage"]`
- Feature requests: `["enhancement"]`
- Documentation: `["documentation"]`

**Environment Placeholder**:

Update the environment field placeholder to match your tech stack:

```yaml
placeholder: |
  - OS: macOS 14.0
  - Go version: 1.23.1
  - readability version: v1.7.0
```

**Optional vs Required**:

Make fields required only when necessary:

- Bug Summary: required
- Steps to Reproduce: required
- Environment: required
- Logs: optional (not all bugs have logs)
- Additional Context: optional

---

## Related Patterns

- [Open Source Templates](index.md) - Main overview
- [CONTRIBUTING Template](contributing-template.md) - Contribution guidelines template
- [SECURITY Template](security-template.md) - Security disclosure template

---

*YAML forms replace blank issues. Required fields ensure quality reports. Structured data enables triage automation. Copy these templates. Update placeholders. Commit. OpenSSF Badge criterion satisfied.*
