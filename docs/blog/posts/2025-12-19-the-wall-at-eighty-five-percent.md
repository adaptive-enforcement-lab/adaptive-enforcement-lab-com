---
title: "The Wall at 85%: When Tests Aren't the Problem"
date: 2025-12-19
authors:
  - mark
categories:
  - Testing
  - Go
  - Quality Assurance
description: >-
  85% coverage. Comprehensive tests. Couldn't go higher. The blocker wasn't tests. It was code. Refactoring for testability broke through to 99%.
slug: wall-at-eighty-five-percent
provenance: human
---
# The Wall at 85%: When Tests Aren't the Problem

The test suite was comprehensive. Table-driven tests. Error paths covered. Race detector enabled.

Coverage: **85.8%**. Stuck.

We needed 95%. The team wrote more tests. Coverage stayed at 85%.

The problem wasn't the tests. It was the code.

<!-- more -->

---

## The Comprehensive Test Suite

The project had 200+ tests across all packages:

- ✅ Table-driven tests for variations
- ✅ Error path coverage
- ✅ Race detector in every run
- ✅ Integration tests for CLI
- ✅ Mocked file I/O

Coverage by package:

| Package | Coverage |
| ------- | -------- |
| cmd/readability | 80.0% |
| pkg/analyzer | 94.7% |
| pkg/config | 89.8% |
| pkg/markdown | 95.1% |
| pkg/output | 99.6% |
| **Total** | **85.8%** |

The CLI package dragged down the total. At 80%, it needed work.

But adding more tests didn't move the needle.

---

## The Complexity Discovery

`gocyclo` revealed the problem:

```text
cmd/readability/main.go:45: main.run() complexity = 35 (limit: 15)
pkg/markdown/parser.go:78: Parse() complexity = 21 (limit: 15)
```

Cyclomatic complexity measures decision points. A complexity of 35 means 35 different execution paths through one function.

Testing all 35 paths in a monolithic function is impossible without:

- Setting up all flag combinations
- Mocking file I/O for every branch
- Handling errors at multiple depths
- Verifying output for each path

The tests would be unmaintainable. The code needed to change first.

---

## The Refactoring

`main.run()` did everything in one function:

- Parse flags (+5 complexity)
- Load config or auto-detect (+8 complexity)
- Apply flag overrides (+4 complexity)
- Analyze files (+6 complexity)
- Format output (+7 complexity)
- Check thresholds (+5 complexity)

Total: 35 decision points in one function.

We extracted 11 focused functions:

- `loadConfig()` - complexity 5
- `applyFlagOverrides()` - complexity 5
- `analyzeTarget()` - complexity 5
- `outputResults()` - complexity 7
- `checkResults()` - complexity 3
- `countFailures()` - complexity 8
- `printFailureGuidance()` - complexity 4
- Four more guidance functions - complexity 1 each

New `run()` complexity: **6** (was 35).

Each extracted function: testable independently.

---

## The Breakthrough

After refactoring:

**Before tests:**

One test for `run()` had to cover every combination of config source, flag overrides, input type, output format, thresholds and errors: 50+ cases, each with complex setup.

**After tests:**

Table-driven tests for `LoadConfig`, plus separate tests that cover only flag overrides and only output formatting.
The [coverage patterns guide](../../enforce/testing-enforcement/coverage-patterns.md) has both versions.

Each function tested independently. Coverage jumped.

**Final coverage:**

| Package | Before | After |
| ------- | ------ | ----- |
| cmd/readability | 80.0% | **97.5%** |
| pkg/analyzer | 94.7% | **99.1%** |
| pkg/config | 89.8% | **100.0%** |
| pkg/markdown | 95.1% | **98.8%** |
| pkg/output | 99.6% | **99.6%** |
| **Total** | **85.8%** | **99.0%** |

From 85% to 99% without adding exotic test infrastructure. By making code testable.

---

## The Lesson: Complexity Blocks Coverage

High cyclomatic complexity makes comprehensive testing impractical:

- **Complexity 35**: 35 paths to test. Requires combinatorial setup.
- **Complexity 6**: 6 paths to test. Table-driven tests work.

The wall wasn't about writing more tests. It was about making code simple enough to test.

Refactoring for testability came first. Coverage followed.

---

## The Enforcement

We raised the threshold from 80% to 95% and made `codecov.yml` the single source of truth.

Both CI and pre-commit hooks read from it:

```bash
THRESHOLD=$(grep -A2 "project:" codecov.yml | grep "target:" | head -1 | sed "s/.*target: *\([0-9]*\).*/\1/")
```

One definition. Zero drift. Pre-push hook blocks commits below threshold.

This satisfied OpenSSF Best Practices criteria for testing (95%+ coverage, race detection, CI enforcement).

---

## What Changed

**Before**: "We need more tests to hit 95%."

**After**: "We need to refactor so tests are possible."

The wall wasn't about test quantity. It was about code quality.

Coverage reached 99% when code became simple enough to test.

!!! tip "Implementation Patterns"
    See [Test Coverage Patterns](../../enforce/testing-enforcement/coverage-patterns.md) for refactoring techniques, Codecov configuration, and single-source-of-truth threshold management.

---

## Related Patterns

- **[OpenSSF Best Practices Badge](2025-12-17-openssf-badge-two-hours.md)** - High coverage made badge criteria trivial
- **[Always Works QA](2025-12-08-always-works-qa-methodology.md)** - Coverage as quality gate
- **[SDLC Hardening](2025-12-12-harden-sdlc-before-audit.md)** - Testing in audit context

---

*The coverage was stuck. More tests didn't help. Refactoring broke the wall. Code became testable. Coverage reached 99%. The blocker wasn't tests. It was complexity.*
