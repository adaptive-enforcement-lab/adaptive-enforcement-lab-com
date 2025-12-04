# Integration Guide

## Pre-commit Hook

Add to `.pre-commit-config.yaml`:

```yaml
- repo: local
  hooks:
    - id: content-analyzer
      name: check documentation readability
      entry: bash -c 'cd tools/content-analyzer && go run ./cmd/content-analyzer --check ../../docs/'
      language: system
      files: ^docs/.*\.md$
      exclude: ^designs/
      pass_filenames: false
```

This runs the analyzer using `go run` (no binary build required) against all docs
when any markdown file in `docs/` changes.

## GitHub Actions

### Job Summary Output

Use `--format markdown` to write directly to the job summary:

```yaml
name: Documentation Quality

on:
  pull_request:
    paths:
      - 'docs/**/*.md'

jobs:
  readability:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-go@v5
        with:
          go-version: '1.21'

      - name: Analyze documentation
        working-directory: tools/content-analyzer
        run: |
          go run ./cmd/content-analyzer ../../docs/ --format markdown >> $GITHUB_STEP_SUMMARY

      - name: Check thresholds
        working-directory: tools/content-analyzer
        run: |
          go run ./cmd/content-analyzer ../../docs/ --check
```

### With Caching

For faster CI runs, cache the Go modules:

```yaml
- uses: actions/setup-go@v5
  with:
    go-version: '1.21'
    cache-dependency-path: tools/content-analyzer/go.sum
```

### PR Comment (Alternative)

To post as a PR comment instead of job summary:

```yaml
- name: Analyze documentation
  id: analyze
  working-directory: tools/content-analyzer
  run: |
    OUTPUT=$(go run ./cmd/content-analyzer ../../docs/ --format summary)
    echo "report<<EOF" >> $GITHUB_OUTPUT
    echo "$OUTPUT" >> $GITHUB_OUTPUT
    echo "EOF" >> $GITHUB_OUTPUT

- name: Comment on PR
  uses: actions/github-script@v7
  with:
    script: |
      github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: `${{ steps.analyze.outputs.report }}`
      })
```

## Output Formats

| Format | Use Case | Command |
|--------|----------|---------|
| `table` | Local development | `--format table` (default) |
| `json` | Programmatic processing | `--format json` |
| `markdown` | GitHub job summary / PR comments | `--format markdown` |
| `summary` | Compact aggregate view | `--format summary` |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All files pass thresholds (or `--check` not used) |
| 1 | One or more files failed threshold checks |
