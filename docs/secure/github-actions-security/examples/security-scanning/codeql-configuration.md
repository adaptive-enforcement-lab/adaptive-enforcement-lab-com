---
title: CodeQL Configuration
description: >-
  Custom CodeQL configuration for enhanced SAST analysis
---

## CodeQL Configuration

### Custom CodeQL Configuration

Advanced CodeQL configuration for fine-tuned SAST analysis.

```yaml
# .github/codeql/codeql-config.yml
# SECURITY: Custom CodeQL configuration for enhanced analysis

name: "Custom CodeQL Config"

# SECURITY: Disable default query suites, use explicit queries
disable-default-queries: false

# SECURITY: Additional query packs for comprehensive scanning
queries:
  - name: "Security Extended Queries"
    uses: security-extended
  - name: "Security and Quality Queries"
    uses: security-and-quality

# SECURITY: Query filters to reduce false positives
query-filters:
  # Exclude specific queries that generate noise
  - exclude:
      id: js/unused-local-variable

# SECURITY: Path filters to exclude test files and vendor code
paths-ignore:
  - 'node_modules/**'
  - 'vendor/**'
  - 'test/**'
  - 'tests/**'
  - '**/*.test.js'
  - '**/*.spec.ts'

# SECURITY: Explicitly include critical paths
paths:
  - 'src/**'
  - 'lib/**'
  - 'app/**'

# SECURITY: External repositories for reusable CodeQL queries
external-repository-token: ${{ secrets.GITHUB_TOKEN }}
```

### Language-Specific CodeQL Workflow

```yaml
name: CodeQL SAST
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 8 * * 1'

permissions:
  contents: read

jobs:
  codeql:
    name: CodeQL Analysis (${{ matrix.language }})
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write
      actions: read
    strategy:
      fail-fast: false
      matrix:
        # SECURITY: Add all languages in your repository
        language: ['javascript', 'python', 'go']
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      - uses: github/codeql-action/init@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          languages: ${{ matrix.language }}
          queries: security-and-quality
          config-file: ./.github/codeql/codeql-config.yml

      # SECURITY: Language-specific setup
      - name: Setup Python
        if: matrix.language == 'python'
        uses: actions/setup-python@0a5c61591373683505ea898e09a3ea4f39ef2b9c  # v5.0.0
        with:
          python-version: '3.11'

      - name: Setup Node.js
        if: matrix.language == 'javascript'
        uses: actions/setup-node@5e21ff4d9bc1a8cf6de233a3057d20ec6b3fb69d  # v3.8.1
        with:
          node-version: '20'

      - name: Setup Go
        if: matrix.language == 'go'
        uses: actions/setup-go@93397bea11091df50f3d7e59dc26a7711a8bcfbe  # v4.1.0
        with:
          go-version: '1.22'

      - uses: github/codeql-action/autobuild@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4

      - uses: github/codeql-action/analyze@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          category: "/language:${{ matrix.language }}"
          # SECURITY: Upload results even if analysis finds issues
          upload: true
```
