---
description: >-
  Assertion patterns: runtime assertions, contract validation, invariant checks, and type guards for fail fast validation.
tags:
  - fail-fast
  - assertions
  - contracts
---

# Assertion Patterns

Validate assumptions and fail if they're wrong.

!!! note "Assertions Document Invariants"
    Assertions make implicit assumptions explicit. They serve as executable documentation that validates preconditions, postconditions, and invariants that must hold true.

---

## Runtime Assertions

```go
func withdraw(account *Account, amount int) error {
    // Precondition assertions
    assert(account != nil, "account cannot be nil")
    assert(amount > 0, "amount must be positive")
    assert(account.Balance >= amount, "insufficient balance")

    // Postcondition assertion
    oldBalance := account.Balance
    account.Balance -= amount

    assert(account.Balance == oldBalance - amount,
        "balance invariant violated")

    return nil
}

func assert(condition bool, message string) {
    if !condition {
        panic(fmt.Sprintf("assertion failed: %s", message))
    }
}
```

---

## Contract Validation (Pre/Post Conditions)

```go
type TransferRequest struct {
    FromAccount string
    ToAccount   string
    Amount      int
}

func (r *TransferRequest) ValidatePreconditions() error {
    // Pre-conditions: what must be true before operation
    if r.FromAccount == "" {
        return errors.New("from_account required")
    }
    if r.ToAccount == "" {
        return errors.New("to_account required")
    }
    if r.FromAccount == r.ToAccount {
        return errors.New("cannot transfer to same account")
    }
    if r.Amount <= 0 {
        return errors.New("amount must be positive")
    }
    return nil
}

func Transfer(req *TransferRequest) error {
    // Validate pre-conditions
    if err := req.ValidatePreconditions(); err != nil {
        return fmt.Errorf("precondition failed: %w", err)
    }

    // Execute transfer
    // ...

    // Validate post-conditions
    if err := validatePostConditions(); err != nil {
        return fmt.Errorf("postcondition failed: %w", err)
    }

    return nil
}
```

---

## Invariant Checks

```go
type BankAccount struct {
    balance int
    mu      sync.Mutex
}

func (a *BankAccount) checkInvariants() error {
    // Invariants: properties that must always be true
    if a.balance < 0 {
        return fmt.Errorf("invariant violated: balance is negative (%d)", a.balance)
    }
    return nil
}

func (a *BankAccount) Withdraw(amount int) error {
    a.mu.Lock()
    defer a.mu.Unlock()

    // Check invariants before operation
    if err := a.checkInvariants(); err != nil {
        return err
    }

    if a.balance < amount {
        return errors.New("insufficient funds")
    }

    a.balance -= amount

    // Check invariants after operation
    if err := a.checkInvariants(); err != nil {
        return err
    }

    return nil
}
```

---

## Type Guards (TypeScript)

```typescript
interface User {
  id: string;
  name: string;
}

interface Admin extends User {
  permissions: string[];
}

// Type guard function
function isAdmin(user: User): user is Admin {
  return 'permissions' in user;
}

function deleteUser(actor: User, targetId: string) {
  // Type guard ensures actor is Admin before dangerous operation
  if (!isAdmin(actor)) {
    throw new Error('only admins can delete users');
  }

  // TypeScript knows actor is Admin here
  console.log(`Admin ${actor.name} deleting user ${targetId}`);
  // ... delete logic
}
```

---

## Back to Fail Fast

- [Fail Fast Overview](../index.md)
- [Early Termination](early-termination.md)
- [Strict Mode](strict-mode.md)
- [Error Escalation](error-escalation.md)
- [Timeouts](timeouts.md)
