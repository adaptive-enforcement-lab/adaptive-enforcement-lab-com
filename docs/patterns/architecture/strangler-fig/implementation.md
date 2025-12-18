---
title: Strangler Fig Implementation
description: >-
  Feature flags for traffic control, parallel run validation, dual-write database migration, and shadow mode testing for incremental system replacement.
---

# Strangler Fig Implementation

Three core implementation patterns enable gradual migration: feature flags for traffic control, parallel run for validation, and dual writes for data migration.

!!! tip "Migration Pattern"
    This guide covers the Strangler Fig pattern for incremental system migration. Review all sections for complete implementation strategy.

---

## Implementation with Feature Flags

Control traffic routing with flags:

```go
func HandleRequest(w http.ResponseWriter, r *http.Request) {
    // Check feature flag
    useNewSystem := featureFlags.IsEnabled("new-api-v2", r.Context())

    if useNewSystem {
        newAPIHandler(w, r)
    } else {
        legacyAPIHandler(w, r)
    }
}

// Feature flag with percentage rollout
type FeatureFlags struct {
    client *launchdarkly.LDClient
}

func (f *FeatureFlags) IsEnabled(flag string, ctx context.Context) bool {
    user := getUserFromContext(ctx)

    // LaunchDarkly, Split.io, or custom implementation
    enabled, _ := f.client.BoolVariation(flag, user, false)
    return enabled
}
```

Feature flag dashboard controls percentage. Start at 1%, increase to 5%, 10%, 50%, 100%.

---

## Parallel Run Validation

Run both systems, compare results:

```go
func HandleRequest(w http.ResponseWriter, r *http.Request) {
    // Always call legacy (production)
    legacyResult := legacyAPIHandler(r)

    // Optionally call new system (shadow)
    if featureFlags.IsEnabled("shadow-new-api", r.Context()) {
        go func() {
            newResult := newAPIHandler(r)

            // Compare results
            if !resultsMatch(legacyResult, newResult) {
                logMismatch(r, legacyResult, newResult)
                metrics.Inc("api.mismatch")
            }
        }()
    }

    // Always return legacy result
    writeResponse(w, legacyResult)
}
```

Shadow mode: Both run, only legacy result returned. Mismatches logged. Fix new system until mismatches drop to zero. Then switch traffic.

---

## Database Migration Strategy

Dual writes during transition:

```go
type UserService struct {
    legacyDB *sql.DB
    newDB    *mongo.Client
    flags    *FeatureFlags
}

func (s *UserService) CreateUser(ctx context.Context, user *User) error {
    // Write to legacy (required)
    if err := s.writeLegacyDB(user); err != nil {
        return fmt.Errorf("legacy write: %w", err)
    }

    // Write to new DB (dual write during migration)
    if s.flags.IsEnabled("dual-write-users", ctx) {
        if err := s.writeNewDB(ctx, user); err != nil {
            // Log but don't fail - new DB is not primary yet
            log.Printf("new DB write failed: %v", err)
            metrics.Inc("newdb.write.error")
        }
    }

    return nil
}

func (s *UserService) GetUser(ctx context.Context, id string) (*User, error) {
    // Read from new DB if enabled
    if s.flags.IsEnabled("read-from-newdb", ctx) {
        user, err := s.readNewDB(ctx, id)
        if err == nil {
            return user, nil
        }

        // Fallback to legacy on error
        log.Printf("new DB read failed, falling back: %v", err)
        metrics.Inc("newdb.read.fallback")
    }

    // Read from legacy
    return s.readLegacyDB(id)
}
```

Phases:

1. Dual write (legacy + new)
2. Read from new, fallback to legacy
3. Read from new only
4. Remove legacy

---

## Related Patterns

- **[Traffic Routing](traffic-routing.md)** - Routing strategies
- **[Monitoring and Rollback](monitoring.md)** - Validation and rollback
- **[Migration Guide](migration-guide.md)** - Step-by-step process

---

*Feature flags controlled the rollout. Shadow mode validated behavior. Dual writes migrated data. Zero production impact.*
