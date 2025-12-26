---
description: >-
  Timeout enforcement: operation timeouts, job timeouts, circuit breaker timeouts, and deadlock detection for fail fast patterns.
tags:
  - fail-fast
  - timeouts
  - circuit-breakers
---

# Timeout Enforcement

Prevent operations from running indefinitely.

!!! tip "Always Set Timeouts"
    Operations without timeouts can hang indefinitely, blocking resources and hiding failures. Set reasonable timeouts based on expected operation duration plus buffer for network latency.

---

## Operation Timeouts (Go)

```go
func fetchWithTimeout(ctx context.Context, url string) ([]byte, error) {
    // Create timeout context
    ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel()

    req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
    if err != nil {
        return nil, err
    }

    resp, err := http.DefaultClient.Do(req)
    if err != nil {
        if ctx.Err() == context.DeadlineExceeded {
            return nil, fmt.Errorf("request timed out after 5s: %w", err)
        }
        return nil, err
    }
    defer resp.Body.Close()

    return io.ReadAll(resp.Body)
}
```

---

## Job Timeouts (GitHub Actions)

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 10  # Fail fast if build hangs
    steps:
      - run: make build

  test:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - run: npm test
```

---

## Circuit Breaker Timeouts

```go
type CircuitBreaker struct {
    timeout      time.Duration
    openDuration time.Duration
    openUntil    time.Time
}

func (cb *CircuitBreaker) CallWithTimeout(fn func() error) error {
    // Check if circuit is open
    if time.Now().Before(cb.openUntil) {
        return fmt.Errorf("circuit breaker open until %v", cb.openUntil)
    }

    // Execute with timeout
    done := make(chan error, 1)
    go func() {
        done <- fn()
    }()

    select {
    case err := <-done:
        if err != nil {
            cb.openUntil = time.Now().Add(cb.openDuration)
            return fmt.Errorf("operation failed, circuit open for %v: %w",
                cb.openDuration, err)
        }
        return nil

    case <-time.After(cb.timeout):
        cb.openUntil = time.Now().Add(cb.openDuration)
        return fmt.Errorf("operation timed out after %v, circuit open for %v",
            cb.timeout, cb.openDuration)
    }
}
```

---

## Deadlock Detection

```go
func performWithDeadlockDetection(fn func()) error {
    done := make(chan struct{})

    go func() {
        fn()
        close(done)
    }()

    select {
    case <-done:
        return nil

    case <-time.After(30 * time.Second):
        return fmt.Errorf("potential deadlock: operation did not complete within 30s")
    }
}

// Example usage
err := performWithDeadlockDetection(func() {
    mutex1.Lock()
    defer mutex1.Unlock()

    mutex2.Lock()
    defer mutex2.Unlock()

    // ... critical section
})
```

---

## Back to Fail Fast

- [Fail Fast Overview](../index.md)
- [Early Termination](early-termination.md)
- [Strict Mode](strict-mode.md)
- [Assertions](assertions.md)
- [Error Escalation](error-escalation.md)
