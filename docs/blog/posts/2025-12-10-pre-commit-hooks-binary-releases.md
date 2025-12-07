---
date: 2025-12-10
authors:
  - mark
categories:
  - DevSecOps
  - Go
  - CI/CD
description: >-
  Binary releases eliminate the 30-second cold start penalty. Ship pre-commit
  hooks developers actually want to use.
slug: pre-commit-hooks-binary-releases
---

# Pre-commit Hooks That Don't Make You Wait

Your first commit after cloning a repo takes 30 seconds. Why? Pre-commit is compiling Go from source.

Binary releases fix this. Ship hooks backed by pre-built binaries.

<!-- more -->

## The Problem with `language: golang`

What happens with `language: golang` hooks:

1. First commit runs `go install` from source
2. User waits 30+ seconds to compile
3. Go version mismatches break builds
4. Network issues fail the install

The result: developers disable pre-commit hooks.

!!! danger "Friction Kills Adoption"
    Every second of delay makes bypass more likely. Developers disable slow hooks.

---

## Binary Release Advantages

| Aspect | Source Build | Binary Release |
|--------|--------------|----------------|
| First run | 30+ seconds | ~1 second |
| Go required | Yes | No |
| Version issues | Depends on user's Go | Same binary for all |
| Network needs | Fetch modules | One file download |

---

## The .pre-commit-hooks.yaml File

Define hooks in your tool repo:

```yaml
# .pre-commit-hooks.yaml
- id: readability
  name: readability
  description: Check documentation readability metrics
  entry: readability --check
  language: golang
  files: \.md$
  pass_filenames: true
  types: [markdown]

- id: readability-docs
  name: readability (docs only)
  description: Check only docs/ directory
  entry: readability --check docs/
  language: golang
  files: ^docs/.*\.md$
  pass_filenames: false
  types: [markdown]
```

!!! tip "Two Hook Variants"
    Offer both file-based and directory-based hooks. Projects have different needs.

---

## Key Hook Definition Fields

| Field | Purpose |
|-------|---------|
| `id` | Name users put in their config |
| `entry` | Command to execute |
| `language` | Runtime: golang, system, python |
| `files` | Regex to match files |
| `pass_filenames` | Pass matched files as args or not |
| `types` | File type filter |

---

## CLI Design for Pre-commit

### Exit Codes

Pre-commit checks exit codes:

- `0`: All files pass
- `1`: One or more files failed
- Other: Error (config issues, crashes)

```go
func run() error {
    // Analyze files...

    if checkFlag && failed > 0 {
        return fmt.Errorf("%d file(s) failed", failed)
    }
    return nil
}

func main() {
    if err := run(); err != nil {
        fmt.Fprintf(os.Stderr, "Error: %v\n", err)
        os.Exit(1)
    }
}
```

### The --check Flag Pattern

Always implement `--check` that:

1. Shows results to the user
2. Exits with code 1 on failure
3. Used by default in hook entry

```yaml
entry: my-tool --check  # Always use --check in hooks
```

### Accepting Multiple Files

With `pass_filenames: true`, pre-commit passes files as args:

```bash
my-tool --check file1.md file2.md docs/guide.md
```

Your CLI must handle this:

```go
func run(cmd *cobra.Command, args []string) error {
    paths := args
    if len(paths) == 0 {
        paths = []string{"."}
    }

    var allResults []*Result
    for _, path := range paths {
        results, err := analyze(path)
        if err != nil {
            return err
        }
        allResults = append(allResults, results...)
    }

    return processResults(allResults)
}
```

---

## GoReleaser Configuration

Build for all platforms:

```yaml
# .goreleaser.yml
version: 2

builds:
  - id: my-tool
    main: ./cmd/my-tool
    binary: my-tool_{{ .Os }}_{{ .Arch }}
    env:
      - CGO_ENABLED=0
    goos: [linux, darwin, windows]
    goarch: [amd64, arm64]
    ldflags:
      - -s -w
      - -X main.version={{ .Version }}

archives:
  - id: my-tool
    builds: [my-tool]
    format: tar.gz
    name_template: "my-tool_{{ .Os }}_{{ .Arch }}"
```

---

## Consumer Configuration

In repos that use your hook:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/owner/my-tool
    rev: v1.0.0
    hooks:
      - id: readability
```

### With Arguments

```yaml
repos:
  - repo: https://github.com/owner/my-tool
    rev: v1.0.0
    hooks:
      - id: readability
        args: ['--config', '.readability.yml']
```

### Excluding Files

```yaml
repos:
  - repo: https://github.com/owner/my-tool
    rev: v1.0.0
    hooks:
      - id: readability
        exclude: '^CHANGELOG\.md$|^vendor/'
```

---

## Floating Version Tags

Keep floating tags for easy updates:

```bash
# In release workflow
VERSION=${GITHUB_REF#refs/tags/}
MAJOR=$(echo $VERSION | cut -d. -f1)

git tag -f $MAJOR
git push -f origin $MAJOR
```

Users can then reference:

```yaml
rev: v1  # Always gets latest v1.x.x
```

---

## Testing Pre-commit Hooks

### Local Testing

```bash
# Build the tool
go build -o my-tool ./cmd/my-tool

# Test with specific files
./my-tool --check README.md docs/

# Test exit code
./my-tool --check bad-file.md; echo "Exit: $?"
```

### Pre-commit Testing

```bash
# Install hooks
pre-commit install

# Run on all files
pre-commit run my-tool --all-files

# Run on specific files
pre-commit run my-tool --files README.md

# Verbose output
pre-commit run my-tool --all-files --verbose
```

---

## Helpful Error Messages

Design output for humans and AI agents:

```go
if failed > 0 {
    if tooLong > 0 {
        fmt.Fprintln(os.Stderr, "")
        fmt.Fprintln(os.Stderr, "IMPORTANT: Split files, don't delete content.")
        fmt.Fprintln(os.Stderr, "")
    }
    return fmt.Errorf("%d file(s) failed", failed)
}
```

See [CLI UX Patterns for AI Agents](2025-12-07-cli-ux-patterns-for-ai-agents.md) for more.

---

## Troubleshooting

### Hook Not Found

```text
[ERROR] Repository owner/my-tool does not contain a .pre-commit-hooks.yaml file
```

Make sure `.pre-commit-hooks.yaml` is in your repo.

### Wrong Version Running

Clear pre-commit cache:

```bash
pre-commit clean
pre-commit install
```

### Slow First Run

This is normal for `language: golang`. Users can install the binary globally.

---

## The Payoff

Binary-backed pre-commit hooks provide:

- **Fast**: No compile wait
- **Consistent**: Same binary for all users
- **High adoption**: Devs keep hooks on
- **Better CI**: Same tool runs everywhere

The setup pays off. Better experience for devs. Better code.

---

## Related

- [Building GitHub Actions in Go](2025-12-09-building-github-actions-in-go.md) - Same patterns for GitHub Actions
- [CLI UX Patterns for AI Agents](2025-12-07-cli-ux-patterns-for-ai-agents.md) - Design error messages AI can use
- [golangci-lint v2 Migration](2025-12-11-golangci-lint-v2-migration.md) - Keep your linting current
- [Shipping a GitHub Action the Right Way](2025-12-06-shipping-a-github-action-the-right-way.md) - The action that uses these patterns
