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
  Stricter errcheck rules break most Go projects. Here's the fix pattern that keeps your code clean, and the migration path from golangci-lint v1 to v2.
slug: golangci-lint-v2-migration
provenance: human
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

For files with many write operations, create a wrapper.

A small `mw` type wraps the `io.Writer` and exposes `println` and `printf` methods that discard the write error in one place.
Callers write `m.println("# Report")` instead of handling each return value.

**Pros**: Clean code, centralized decision
**Cons**: Requires refactoring

### Pattern 3: Error Accumulator

When you want to track the first error.

An `errWriter` keeps the first write error, skips every later write, and returns it from `Err()`.

**Pros**: Captures errors for logging
**Cons**: More complex than needed for stdout

---

## Configuration-Based Solutions

### Exclude Specific Functions

`linters-settings.errcheck.exclude-functions` lists `fmt.Fprintln`, `fmt.Fprintf`, `fmt.Fprint` and `(io.Writer).Write`.

**Pros**: No code changes
**Cons**: May hide legitimate issues

### Exclude by Path

An `issues.exclude-rules` entry turns off `errcheck` for `pkg/output/`, matched on the `fmt` print error text.
The [golangci-lint v2 errcheck guide](../../secure/go-security/golangci-lint-v2-errcheck.md) has the code and both configs.

---

## Migration Workflow

### Step 1: Run Locally First

Install the latest `golangci-lint` with `go install`, then run `golangci-lint run ./...`.

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

Run `golangci-lint run ./...`, then `go build ./...`, then push.

---

## Common errcheck Patterns

### Standard Library I/O

`fmt.Println`, `fmt.Fprintf`, `io.WriteString` and `w.Write` all return `(int, error)`, and all need handling.

### File Operations

`defer f.Close()` fails errcheck. For read-only files, `defer func() { _ = f.Close() }()` passes.

### JSON Encoding

A bare `enc.Encode(data)` fails. Check its error and return it.
The [golangci-lint v2 errcheck guide](../../secure/go-security/golangci-lint-v2-errcheck.md) lists each case.

---

## Rollback Strategy

If you need more time, pin the old version.

Pin `golangci/golangci-lint-action@v6` with `version: v1.59.1`, the last v1 release.

This gives you time. But v1 will not get updates.

---

## Troubleshooting

### Different Local vs CI Results

Ensure same version.

Compare `golangci-lint --version` locally with an explicit `version` pinned in the CI action.

### Cached Results

Clear cache if seeing stale results.

Run `golangci-lint cache clean`.

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
