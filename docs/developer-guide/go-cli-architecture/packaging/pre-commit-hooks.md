# Pre-commit Hook Distribution

Distribute your Go CLI as a pre-commit hook with binary releases.

!!! tip "Binary Releases"
    Binary releases eliminate the 30-second cold start penalty. Ship hooks developers actually want to use.

---

## Why Binary Releases?

| Traditional (`language: golang`) | Binary Release |
|----------------------------------|----------------|
| 30+ second first run (go install) | ~1 second execution |
| Requires Go on user's machine | Works without Go |
| Go version mismatches cause failures | Same binary everywhere |
| Network issues break installs | Reliable CI/CD |

---

## Repository Setup

```text
my-tool/
├── .pre-commit-hooks.yaml    # Hook definitions
├── .goreleaser.yml           # Binary release config
├── cmd/my-tool/main.go       # CLI entrypoint
├── pkg/                      # Business logic
├── .github/workflows/release.yml
└── go.mod
```

---

## The .pre-commit-hooks.yaml File

```yaml
# .pre-commit-hooks.yaml
- id: my-tool
  name: my-tool
  description: Check documentation quality
  entry: my-tool --check
  language: golang
  files: \.md$
  pass_filenames: true
  types: [markdown]

- id: my-tool-docs
  name: my-tool (docs only)
  entry: my-tool --check docs/
  language: golang
  files: ^docs/.*\.md$
  pass_filenames: false
  types: [markdown]
```

| Field | Description |
|-------|-------------|
| `id` | Unique identifier users reference |
| `entry` | Command to execute |
| `language` | How to install/run (golang, system, python) |
| `files` | Regex pattern for files to check |
| `pass_filenames` | Whether to pass matched files as args |

---

## CLI Design for Pre-commit

### Exit Codes

| Exit Code | Meaning | Hook Result |
|-----------|---------|-------------|
| 0 | All files pass | Hook passes |
| 1 | One or more failed | Hook fails |

```go
func main() {
    if err := run(); err != nil {
        fmt.Fprintf(os.Stderr, "Error: %v\n", err)
        os.Exit(1)
    }
}

func run() error {
    if checkFlag && failed > 0 {
        return fmt.Errorf("%d file(s) failed", failed)
    }
    return nil
}
```

### Accepting Multiple Files

When `pass_filenames: true`, pre-commit passes files as arguments:

```go
func run(cmd *cobra.Command, args []string) error {
    paths := args
    if len(paths) == 0 {
        paths = []string{"."}
    }
    for _, path := range paths {
        results, err := analyze(path)
        // ...
    }
}
```

---

## Consumer Configuration

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/owner/my-tool
    rev: v1.0.0
    hooks:
      - id: my-tool
        args: ['--config', '.my-tool.yml']  # Optional
        exclude: '^CHANGELOG\.md$'          # Optional
```

Use floating tags for automatic updates:

```yaml
rev: v1  # Always gets latest v1.x.x
```

---

## GoReleaser Configuration

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

checksum:
  name_template: 'checksums.txt'
```

Update floating tags in your release workflow:

```bash
VERSION=${GITHUB_REF#refs/tags/}
MAJOR=$(echo $VERSION | cut -d. -f1)
git tag -f $MAJOR && git push -f origin $MAJOR
```

---

## Helpful Error Messages

!!! warning "AI Agents Take Messages Literally"
    Without explicit guidance, AI agents may delete content instead of restructuring.

```go
if failed > 0 && tooLong > 0 {
    fmt.Fprintln(os.Stderr, "IMPORTANT: Split files, don't delete content.")
}
```

See [CLI UX Patterns for AI Agents](/blog/posts/2025-12-07-cli-ux-patterns-for-ai-agents/) for detailed guidance.

---

## Testing Hooks

```bash
# Local testing
go build -o my-tool ./cmd/my-tool
./my-tool --check README.md docs/

# Pre-commit testing
pre-commit install
pre-commit run my-tool --all-files --verbose
```

### CI Integration

```yaml
# .github/workflows/lint.yml
jobs:
  pre-commit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-python@v6
      - uses: pre-commit/action@v3
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Hook not found | Ensure `.pre-commit-hooks.yaml` is committed |
| Wrong version | Run `pre-commit clean && pre-commit install` |
| Slow first run | Normal for `language: golang` (builds from source) |

---

## Best Practices

| Practice | Description |
|----------|-------------|
| **Two hook variants** | File-based and directory-based options |
| **--check flag** | Always fail on issues by default |
| **Multiple file args** | Handle `pass_filenames: true` correctly |
| **Helpful errors** | Guide users toward correct fixes |
| **Floating tags** | `v1` for easy updates |

---

## Related

- [GitHub Actions Distribution](github-actions.md) - Same patterns for GitHub Actions
- [Release Automation](release-automation.md) - GoReleaser and floating tags
- [CLI UX Patterns](/blog/posts/2025-12-07-cli-ux-patterns-for-ai-agents/) - Error messages AI can use

---

*Ship hooks developers keep enabled.*
