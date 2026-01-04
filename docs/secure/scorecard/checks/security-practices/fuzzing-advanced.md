---
title: Advanced Fuzzing Techniques
description: >-
  Advanced fuzzing techniques for OpenSSF Scorecard. Write effective fuzz
  targets, manage corpus, and implement continuous fuzzing strategies.
tags:

  - scorecard
  - fuzzing
  - testing

---
# Advanced Fuzzing Techniques

!!! tip "Key Insight"
    Advanced fuzzing techniques uncover complex security vulnerabilities.

This guide covers advanced fuzzing practices for the Scorecard Fuzzing check.

**Prerequisites**: Read [Fuzzing check](./fuzzing.md) first for setup and integration.

## Writing Effective Fuzz Targets

**Principles**:

1. **Fast**: Fuzz targets should execute in microseconds
2. **Deterministic**: Same input always produces same behavior
3. **No state**: Each fuzz iteration should be independent
4. **Comprehensive**: Cover all parsing/input handling code

**Good fuzz target**:

```go
func FuzzParse(f *testing.F) {
    f.Fuzz(func(t *testing.T, data []byte) {
        // Fast, stateless, deterministic
        _, _ = Parse(data)
    })
}

```bash
**Bad fuzz target**:

```go
func FuzzParse(f *testing.F) {
    f.Fuzz(func(t *testing.T, data []byte) {
        // BAD: Network I/O (slow, non-deterministic)
        resp, _ := http.Post("http://example.com", "application/json", bytes.NewReader(data))

        // BAD: File system access (slow, stateful)
        os.WriteFile("/tmp/fuzz", data, 0644)
    })
}

```bash
### Corpus Management

**Seed corpus**: Initial inputs that fuzzer mutates.

**Location**: Store in `testdata/fuzz/` directory:

```text
testdata/
  fuzz/
    FuzzParse/
      valid-input-1
      edge-case-2
      regression-3

```bash
**Benefits**:

- Fuzzer starts from known-good inputs
- Regression test for previously-found crashes
- Faster coverage of interesting code paths

**Add to git**: Yes, commit seed corpus for reproducibility.

### Continuous Fuzzing Strategy

**Daily fuzzing**:

```yaml
on:
  schedule:

    - cron: '0 2 * * *'  # 2 AM daily

```bash
**Longer fuzz time for scheduled runs**:

```yaml

- name: Long fuzz run

  if: github.event_name == 'schedule'
  run: go test -fuzz=Fuzz -fuzztime=1h ./...

```bash
**PR validation**:

```yaml
on:
  pull_request:

```bash
**Shorter fuzz time for PRs**:

```yaml

- name: Quick fuzz check

  if: github.event_name == 'pull_request'
  run: go test -fuzz=Fuzz -fuzztime=30s ./...

```bash
### Troubleshooting

#### Fuzzing not detected by Scorecard

**Check**: Is fuzzing configuration in `.github/workflows/`?

**Check**: Does workflow name or step name contain "fuzz"?

**Scorecard detection**: Searches for keywords like "fuzz", "libfuzzer", "oss-fuzz" in workflows.

#### Fuzzing is too slow for CI

**Solution**: Reduce fuzz time for CI, use scheduled runs for comprehensive fuzzing:

```yaml
# PR: 30 seconds

fuzz-seconds: 30

# Scheduled: 1 hour

fuzz-seconds: 3600

```bash
#### Fuzzing finds crashes in third-party dependencies

**Upstream the finding**:

1. Minimize crashing input
2. Report to upstream project
3. Get CVE assigned
4. Wait for patch or workaround

**Your responsibility**: If fuzzing finds crash in your dependency, report it responsibly.

#### Should we implement fuzzing if we score 0/10?

**Decision framework**:

- **Does your project parse untrusted input?** → Yes, fuzz it
- **Is your project business logic only?** → Fuzzing low value, accept 0/10
- **Are you handling security-critical data?** → Fuzz it
- **Is this a library used by other projects?** → Fuzz it

**Reality**: Most projects score 0/10 on Fuzzing. Only implement if it genuinely adds security value.

---

---

## Related Content

**Back to basics**:

- [Fuzzing Check](./fuzzing.md) - Setup and integration guide

**Other Security Practices checks**:

- [Security-Policy](./security-policy.md) - Vulnerability disclosure process
- [Vulnerabilities](./vulnerabilities.md) - Known CVE detection and remediation

---

*Effective fuzzing requires fast, deterministic targets with comprehensive corpus coverage.*
