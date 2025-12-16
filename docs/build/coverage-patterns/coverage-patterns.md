---
tags:
  - testing
  - coverage
  - go
  - ci-cd
  - quality-gates
  - developers
---

# Test Coverage Patterns

High test coverage (95%+) as a quality gate, achieved through complexity management and refactoring for testability.

!!! tip "Coverage Through Simplicity"
    Coverage walls signal code complexity, not test inadequacy. Refactor for testability first, then write tests. See [Coverage Enforcement](../../enforce/testing-enforcement/coverage-enforcement.md) for threshold management.

---

## The Coverage Wall

Coverage stalls when code complexity makes comprehensive testing impractical. The solution is refactoring for testability, not exotic test infrastructure.

### Symptom: Stuck Coverage

```text
| Package | Coverage |
| ------- | -------- |
| cmd/app | 80.0%    |  ← Stuck despite comprehensive tests
| pkg/lib | 94.7%    |
| Total   | 85.8%    |  ← Below 95% target
```

### Root Cause: Complexity

```bash
$ gocyclo -over 15 .
cmd/app/main.go:45: main.run() complexity = 35 (limit: 15)
pkg/lib/parser.go:78: Parse() complexity = 21 (limit: 15)
```

**Cyclomatic complexity 35** = 35 execution paths through one function.

Testing all 35 paths requires:

- Combinatorial setup (flags × config × errors)
- Deep mocking (file I/O at multiple levels)
- Unmaintainable test code

---

## Solution: Refactor for Testability

### Before: Monolithic Function

```go
func run() error {
    // Parse flags (+5 complexity)
    configPath := flag.String("config", "", "config file")
    threshold := flag.Int("threshold", 95, "coverage threshold")
    flag.Parse()

    // Load config or auto-detect (+8 complexity)
    var cfg *Config
    if *configPath != "" {
        cfg, err = loadConfigFile(*configPath)
        if err != nil {
            return err
        }
    } else {
        cfg, err = autoDetectConfig()
        if err != nil {
            return err
        }
    }

    // Apply flag overrides (+4 complexity)
    if *threshold != 95 {
        cfg.Threshold = *threshold
    }

    // Analyze files (+6 complexity)
    var results []Result
    if fileInfo.IsDir() {
        results, err = analyzeDirectory(target)
    } else {
        results, err = analyzeFile(target)
    }

    // Format output (+7 complexity)
    switch *format {
    case "json":
        outputJSON(results)
    case "table":
        outputTable(results)
    case "markdown":
        outputMarkdown(results)
    }

    // Check thresholds (+5 complexity)
    for _, r := range results {
        if r.Coverage < cfg.Threshold {
            failures++
        }
    }

    return exitCode(failures)
}
```

**Complexity**: 35 decision points in one function.

### After: Extracted Functions

```go
func run() error {
    cfg := loadConfig(configPath)
    cfg = applyFlagOverrides(cfg, flags)
    results := analyzeTarget(target, cfg)
    outputResults(results, format)
    return checkResults(results, cfg)
}

func loadConfig(path string) (*Config, error) {
    if path != "" {
        return loadConfigFile(path)
    }
    return autoDetectConfig()
}

func applyFlagOverrides(cfg *Config, flags Flags) *Config {
    if flags.Threshold != 95 {
        cfg.Threshold = flags.Threshold
    }
    return cfg
}

func analyzeTarget(target string, cfg *Config) ([]Result, error) {
    info, err := os.Stat(target)
    if err != nil {
        return nil, err
    }
    if info.IsDir() {
        return analyzeDirectory(target)
    }
    return analyzeFile(target)
}

func outputResults(results []Result, format string) {
    switch format {
    case "json":
        outputJSON(results)
    case "table":
        outputTable(results)
    case "markdown":
        outputMarkdown(results)
    }
}

func checkResults(results []Result, cfg *Config) error {
    failures := countFailures(results, cfg.Threshold)
    if failures > 0 {
        printFailureGuidance(failures)
        return fmt.Errorf("%d files below threshold", failures)
    }
    return nil
}
```

**New `run()` complexity**: 6 (was 35).

Each extracted function: **complexity 3-8**, independently testable.

---

## Testing Strategy

### Before: Combinatorial Setup

```go
func TestRun_AllCombinations(t *testing.T) {
    // Need to test:
    // - Config from file vs auto-detect
    // - Multiple flag override scenarios
    // - File vs directory analysis
    // - JSON vs table vs markdown output
    // - Pass vs fail thresholds
    // - Error at each layer

    // Result: 50+ test cases, each with complex setup
}
```

### After: Focused Tests

```go
func TestLoadConfig(t *testing.T) {
    tests := []struct {
        name    string
        path    string
        want    *Config
        wantErr bool
    }{
        {"explicit file", "test.yml", expectedConfig, false},
        {"auto-detect", "", autoConfig, false},
        {"missing file", "none.yml", nil, true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := loadConfig(tt.path)
            if (err != nil) != tt.wantErr {
                t.Errorf("loadConfig() error = %v, wantErr %v", err, tt.wantErr)
                return
            }
            if !reflect.DeepEqual(got, tt.want) {
                t.Errorf("loadConfig() = %v, want %v", got, tt.want)
            }
        })
    }
}

func TestApplyFlagOverrides(t *testing.T) {
    cfg := &Config{Threshold: 95}
    flags := Flags{Threshold: 80}

    got := applyFlagOverrides(cfg, flags)

    if got.Threshold != 80 {
        t.Errorf("applyFlagOverrides() threshold = %v, want 80", got.Threshold)
    }
}

func TestOutputResults(t *testing.T) {
    tests := []struct {
        name   string
        format string
        want   string
    }{
        {"json format", "json", `[{"file":"test.go","coverage":95}]`},
        {"table format", "table", "FILE | COVERAGE\ntest.go | 95%"},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            var buf bytes.Buffer
            outputResults(testResults, tt.format, &buf)
            if got := buf.String(); got != tt.want {
                t.Errorf("outputResults() = %v, want %v", got, tt.want)
            }
        })
    }
}
```

**Result**: Simple table-driven tests, easy to maintain, high coverage.

---

## Coverage Breakthrough

| Package | Before | After     |
| ------- | ------ | --------- |
| cmd/app | 80.0%  | **97.5%** |
| pkg/lib | 94.7%  | **99.1%** |
| Total   | 85.8%  | **99.0%** |

From 85% to 99% by making code testable, not adding exotic infrastructure.

**For coverage enforcement** (CI, pre-commit hooks, Codecov configuration), see [Coverage Enforcement](../../enforce/testing-enforcement/coverage-enforcement.md).

---

## Anti-Patterns

### ❌ Writing Tests for Untestable Code

```go
// Complexity 35 - impossible to test comprehensively
func TestRun_ComplexMonolith(t *testing.T) {
    // 100+ lines of setup
    // Mocking 5 layers deep
    // Only tests 3 of 35 paths
}
```

### ✅ Refactoring Then Testing

```go
// Complexity 6 - simple table-driven test
func TestLoadConfig(t *testing.T) {
    tests := []struct{ name, path string; want *Config }{ ... }
    // Clean, maintainable, comprehensive
}
```

---

## The Lesson

**Coverage walls are code smells.**

- Complexity 35 → Impossible to test comprehensively
- Complexity 6 → Table-driven tests work

Refactor for testability first. Coverage follows.

---

## Related Patterns

- [Coverage Enforcement](../../enforce/testing-enforcement/coverage-enforcement.md) - CI, pre-commit, Codecov integration
- [OpenSSF Best Practices Badge](../../blog/posts/2025-12-17-openssf-badge-two-hours.md) - High coverage made certification trivial
- [Always Works QA](../../blog/posts/2025-12-08-always-works-qa-methodology.md) - Coverage as quality gate
- [SDLC Hardening](../../blog/posts/2025-12-12-harden-sdlc-before-audit.md) - Testing in audit context

---

*The wall wasn't about writing more tests. It was about making code simple enough to test. Coverage reached 99% when code became testable.*
