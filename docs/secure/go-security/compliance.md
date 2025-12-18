---
description: >-
  Map Go security tools to OpenSSF Best Practices and Go Report Card criteria. Document
  compliance evidence for audits using standard automated tooling and verification.
---

# Compliance

Go's standard toolkit satisfies multiple compliance frameworks. OpenSSF Best Practices and Go Report Card both validate these tools.

!!! note "Audit Evidence"
    This table maps Go tools to OpenSSF Best Practices criteria. Use it to document compliance during audits.

## OpenSSF Best Practices Alignment

| OpenSSF Criterion | Tool | Evidence |
| ----------------- | ---- | -------- |
| `static_analysis` | golangci-lint | Runs every commit |
| `static_analysis_common_vulnerabilities` | gosec (via golangci-lint) | Enabled with medium severity |
| `dynamic_analysis` | Race detector | Enabled in all test runs |
| `dynamic_analysis_enable_assertions` | go test | Built-in assertions via testing package |
| `test_most` | go test with coverage | 95%+ coverage enforced |
| `no_leaked_credentials` | TruffleHog | Scans all commits |

---

## Go Report Card Compliance

The [Go Report Card](https://goreportcard.com/) grades Go projects on:

- **gofmt**: Code is formatted
- **go vet**: Static analysis passes
- **golint**: Code follows conventions
- **gocyclo**: Complexity is reasonable
- **ineffassign**: No ineffectual assignments
- **license**: Project has a license

All tools above contribute to achieving **A+** grade.
