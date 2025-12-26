---
description: >-
  Early termination techniques: shell strict mode, matrix fail-fast, error propagation, and circuit breakers for fail fast patterns.
tags:
  - fail-fast
  - early-termination
  - techniques
---

# Early Termination

Stop execution immediately when errors occur.

!!! warning "When NOT to Use Fail-Fast"
    Don't use fail-fast when you need results from all operations even if some fail (e.g., comprehensive test suites, migration validation). Use fail-fast when fast feedback matters more than complete results.

---

## Shell Strict Mode

```bash
#!/bin/bash
set -euo pipefail

# set -e: Exit on first error
# set -u: Error on undefined variables
# set -o pipefail: Fail if any command in pipeline fails

deploy() {
    # Will exit immediately if any command fails
    kubectl apply -f deployment.yaml
    kubectl rollout status deployment/app
    kubectl get pods
}

deploy
```

---

## GitHub Actions Matrix Fail-Fast

```yaml
jobs:
  test:
    strategy:
      fail-fast: true  # Stop all jobs on first failure
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        node: [18, 20, 22]
    runs-on: ${{ matrix.os }}
    steps:
      - run: npm test
```

**Use when**: Fast feedback matters more than complete results.

**Don't use when**: You need results from all matrix combinations even if some fail.

---

## Go Error Propagation

```go
func processData() error {
    // Propagate errors immediately, don't swallow
    data, err := fetchData()
    if err != nil {
        return fmt.Errorf("fetch failed: %w", err)
    }

    transformed, err := transform(data)
    if err != nil {
        return fmt.Errorf("transform failed: %w", err)
    }

    if err := save(transformed); err != nil {
        return fmt.Errorf("save failed: %w", err)
    }

    return nil
}

// Bad: swallows errors
func processDataBad() error {
    data, _ := fetchData()  // Ignores error
    transformed, _ := transform(data)
    save(transformed)
    return nil
}
```

---

## Circuit Breakers

```go
type CircuitBreaker struct {
    failures   int
    threshold  int
    state      string // "closed", "open", "half-open"
}

func (cb *CircuitBreaker) Call(fn func() error) error {
    if cb.state == "open" {
        return fmt.Errorf("circuit breaker open, failing fast")
    }

    if err := fn(); err != nil {
        cb.failures++
        if cb.failures >= cb.threshold {
            cb.state = "open"
            return fmt.Errorf("circuit breaker tripped after %d failures: %w",
                cb.threshold, err)
        }
        return err
    }

    cb.failures = 0
    cb.state = "closed"
    return nil
}
```

---

## Back to Fail Fast

- [Fail Fast Overview](../index.md)
- [Strict Mode](strict-mode.md)
- [Assertions](assertions.md)
- [Error Escalation](error-escalation.md)
- [Timeouts](timeouts.md)
