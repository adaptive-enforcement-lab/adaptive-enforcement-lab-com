---
title: "golangci-lint v2: errcheck Fixes"
description: >-
  Fix the stricter errcheck defaults in golangci-lint v2: explicit ignores, a writer wrapper, an error accumulator, config exclusions, and a safe migration path.
provenance: human
---
# golangci-lint v2: errcheck Fixes

golangci-lint v2, bundled with `golangci/golangci-lint-action` v9, checks unhandled error
returns by default. Code that writes to stdout with `fmt.Fprintln` fails the build:

```text
pkg/output/markdown.go:28:14: Error return value of `fmt.Fprintln` is not checked (errcheck)
    fmt.Fprintln(w, "| Metric | Value |")
                ^
```

!!! tip "One Pattern per Package"
    Pick one fix pattern per package and apply it everywhere. Mixed patterns make review harder.

---

## Fix Patterns

### Explicit Ignore

Minimal change, clear intent. Clutters code when used often.

```go
// Before
fmt.Fprintln(w, "Hello")

// After
_, _ = fmt.Fprintln(w, "Hello")
```

### Writer Wrapper (Recommended)

For output-heavy files. Centralizes the decision, needs a refactor.

```go
// mw wraps io.Writer to simplify error handling for fmt functions.
// Write errors to stdout are typically unrecoverable.
type mw struct {
    w io.Writer
}

func (m mw) println(a ...any) {
    _, _ = fmt.Fprintln(m.w, a...)
}

func (m mw) printf(format string, a ...any) {
    _, _ = fmt.Fprintf(m.w, format, a...)
}

// Usage
func WriteReport(w io.Writer, data *Report) {
    m := mw{w}
    m.println("# Report")
    m.printf("Total: %d\n", data.Total)
}
```

### Error Accumulator

Keeps the first error for logging. More than stdout usually needs.

```go
type errWriter struct {
    w   io.Writer
    err error
}

func (e *errWriter) println(a ...any) {
    if e.err != nil {
        return
    }
    _, e.err = fmt.Fprintln(e.w, a...)
}

func (e *errWriter) Err() error {
    return e.err
}
```

---

## Configuration-Based Fixes

No code changes, but they can hide real issues.

**Exclude specific functions**:

```yaml
# .golangci.yml
version: "2"

linters-settings:
  errcheck:
    exclude-functions:
      - fmt.Fprintln
      - fmt.Fprintf
      - fmt.Fprint
      - (io.Writer).Write
```

**Exclude by path**:

```yaml
# .golangci.yml
version: "2"

issues:
  exclude-rules:
    - path: pkg/output/
      linters:
        - errcheck
      text: "Error return value of `fmt\\.(Fp|P)rint"
```

---

## Common errcheck Cases

**Standard library I/O**:

```go
// All need handling:
fmt.Println("...")          // Returns (int, error)
fmt.Fprintf(w, "...")       // Returns (int, error)
io.WriteString(w, "...")    // Returns (int, error)
w.Write([]byte("..."))      // Returns (int, error)
```

**File close**:

```go
// File.Close returns error
defer f.Close() // Fails errcheck!

// Fix: explicit ignore for read-only operations
defer func() { _ = f.Close() }()
```

**JSON encoding**:

```go
// Before (fails)
enc.Encode(data)

// After
if err := enc.Encode(data); err != nil {
    return err
}
```

---

## Migration Workflow

1. Run the new version locally before CI does:

    ```bash
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
    golangci-lint run ./...
    ```

2. Group failures by linter: `errcheck` (most common), `govet`, `staticcheck`.
3. Choose one fix pattern per package.
4. Verify, then push:

    ```bash
    golangci-lint run ./...
    go build ./...
    git push
    ```

**Rollback** if you need time. v1 gets no further updates:

```yaml
- uses: golangci/golangci-lint-action@v6
  with:
    version: v1.59.1  # Last v1 release
```

---

## Troubleshooting

**Local and CI results differ**: pin the same version in both.

```bash
golangci-lint --version
```

```yaml
- uses: golangci/golangci-lint-action@v9
  with:
    version: v2.7.1  # Explicit version
```

**Stale results**: `golangci-lint cache clean`.

---

## Related

- [The Standard Toolkit](tools.md) - golangci-lint and the rest of the Go security tools
- [golangci-lint v2: What Broke and How to Fix It](../../blog/posts/2025-12-11-golangci-lint-v2-migration.md) - The migration story
