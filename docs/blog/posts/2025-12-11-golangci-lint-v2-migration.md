---
title: "golangci-lint v2: What Broke and How to Fix It"
date: 2025-12-11
authors:
  - mark
categories:
  - Go
  - Linting
  - Code Quality
description: >-
  Stricter errcheck rules break most Go projects. Here's the fix pattern
  that keeps your code clean.
slug: golangci-lint-v2-migration
---
# golangci-lint v2: What Broke and How to Fix It

You updated `golangci/golangci-lint-action` to v9. CI failed. Welcome to golangci-lint v2.

The new version has stricter `errcheck` rules by default. Functions that return errors need handling. Yes, even `fmt.Fprintln`.

Here's how to fix it properly.

<!-- more -->

## The Breaking Change

Action v9 bundles golangci-lint v2. It has stricter error checking:

```text
pkg/output/markdown.go:28:14: Error return value of `fmt.Fprintln` is not checked (errcheck)
    fmt.Fprintln(w, "| Metric | Value |")
                ^
```

This affects most Go projects. Any code that writes to stdout is hit.

!!! info "Why This Matters"
    I/O errors can hide disk-full or broken pipe issues. But for stdout in CLI tools, these errors rarely recover anyway.

---

## Solution Patterns

### Pattern 1: Explicit Ignore

The simplest fix. Mark the ignored return value:

```go
// Before
fmt.Fprintln(w, "Hello")

// After
_, _ = fmt.Fprintln(w, "Hello")
```

**Pros**: Minimal change, clear intent
**Cons**: Clutters code when used frequently

### Pattern 2: Writer Wrapper (Recommended)

For files with many write operations, create a wrapper:

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

**Pros**: Clean code, centralized decision
**Cons**: Requires refactoring

### Pattern 3: Error Accumulator

When you want to track the first error:

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

**Pros**: Captures errors for logging
**Cons**: More complex than needed for stdout

---

## Configuration-Based Solutions

### Exclude Specific Functions

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

**Pros**: No code changes
**Cons**: May hide legitimate issues

### Exclude by Path

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

## Migration Workflow

### Step 1: Run Locally First

```bash
# Install latest golangci-lint
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# Run linter
golangci-lint run ./...
```

!!! danger "Never Push Without Local Verification"
    Don't discover linter failures in CI. Run locally first. See [Should Work ≠ Does Work](2025-12-08-always-works-qa-methodology.md).

### Step 2: Categorize Failures

Group by type:

- **errcheck**: Ignored return values (most common)
- **govet**: Suspicious constructs
- **staticcheck**: Bug patterns

### Step 3: Choose a Fix Pattern

For errcheck, decide on:

1. Wrapper type (recommended for output-heavy code)
2. Explicit ignore (for isolated cases)
3. Config exclusion (for specific packages)

Apply the same fix across all files.

### Step 4: Verify

```bash
# Full linter run
golangci-lint run ./...

# Build verification
go build ./...

# Push
git push
```

---

## Common errcheck Patterns

### Standard Library I/O

```go
// All need handling:
fmt.Println("...")          // Returns (int, error)
fmt.Fprintf(w, "...")       // Returns (int, error)
io.WriteString(w, "...")    // Returns (int, error)
w.Write([]byte("..."))      // Returns (int, error)
```

### File Operations

```go
// File.Close returns error
defer f.Close() // Fails errcheck!

// Fix: explicit ignore for read-only operations
defer func() { _ = f.Close() }()
```

### JSON Encoding

```go
// Before (fails)
enc.Encode(data)

// After
if err := enc.Encode(data); err != nil {
    return err
}
```

---

## Rollback Strategy

If you need more time, pin the old version:

```yaml
- uses: golangci/golangci-lint-action@v6
  with:
    version: v1.59.1  # Last v1 release
```

This gives you time. But v1 will not get updates.

---

## Troubleshooting

### Different Local vs CI Results

Ensure same version:

```bash
# Check local version
golangci-lint --version

# Pin in CI
- uses: golangci/golangci-lint-action@v9
  with:
    version: v2.7.1  # Explicit version
```

### Cached Results

Clear cache if seeing stale results:

```bash
golangci-lint cache clean
```

---

## The Payoff

Stricter rules improve code quality. Error handling becomes clear. The wrapper pattern keeps code clean and the linter happy.

Key steps:

1. Update action to v9
2. Run linter locally to discover issues
3. Choose and apply a consistent fix pattern
4. Verify all checks pass
5. Push with confidence

---

## Related

- [Should Work ≠ Does Work](2025-12-08-always-works-qa-methodology.md) - Always verify locally before pushing
- [Building GitHub Actions in Go](2025-12-09-building-github-actions-in-go.md) - CI setup for Go projects
- [Pre-commit Hooks with Binary Releases](2025-12-10-pre-commit-hooks-binary-releases.md) - Local linting enforcement
