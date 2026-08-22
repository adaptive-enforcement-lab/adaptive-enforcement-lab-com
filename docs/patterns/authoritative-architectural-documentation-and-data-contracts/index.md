---
title: Authoritative Architectural Documentation and Data Contracts
description: >-
  Make architecture docs the enforced source of truth for data flows, backed by schema validation in CI that rejects any payload that violates the data contract.
---

# Authoritative Architectural Documentation and Data Contracts

!!! warning "Documentation Drift Is a Critical Risk"
    Docs that drift from the deployed system cause bad calls, broken integrations, and debugging sessions that start from a false map. Treat architecture documentation as a living artifact, enforced with the same rigor as code.

## Intent

**Make architectural documentation the enforced source of truth for data flows, and make the boundary between strict data contracts and flexible components explicit and checkable.**

Most systems mix two kinds of data structure: contracts that external consumers depend on, and internal shapes a team can change on its own schedule. When documentation does not draw that line clearly, both sides lose.

Consumers build against internals that shift under them. Teams stop iterating because they are not sure what is safe to touch.

## Motivation

Use this pattern when:

- **Multiple teams or services consume the same data.** A schema change from one team breaks another team's pipeline without warning.
- **Docs and code have already drifted once.** If it happened once, it will happen again without enforcement.
- **Onboarding requires guessing which fields are safe to change.** New engineers should not have to read consumer code to find out.
- **Data crosses a trust boundary.** Ingestion pipelines, message buses, and public APIs all need a documented, validated shape at the edge.

Skip the heavyweight version of this pattern for single-service internal state that never crosses a boundary. Enforce it wherever data moves between components owned by different teams.

## Structure

A contract has three parts: the schema, the enforcement gate, and the documentation that points at both.

| Characteristic | Data Contracts | Flexible Components |
| --------------- | -------------- | -------------------- |
| Purpose | Guarantee compatibility, block breaking changes | Enable fast internal iteration |
| Enforcement | Automated schema validation at the boundary | Team convention, code review |
| Blast radius of a change | High, requires coordinated update across consumers | Low, contained to one component |
| Examples | API schemas, message bus payloads, public data models | Internal structs, scratch queues, UI state |
| Doc focus | Formal schema, version history, changelog | High-level behavior, not field-by-field detail |

Documentation for a contracted domain states three things:

1. **Contracted nature**: this domain is governed by a schema, not by convention.
2. **Enforcement gate**: where validation runs and what it blocks (schema registry, API gateway, CI check).
3. **Consumer guarantee**: what shape a consumer can rely on, and what constitutes a breaking change.

Documentation for a flexible component states that it is unconstrained internally, as long as it still satisfies any contract it exposes outward.

## Implementation

### Define the contract as a schema, not a paragraph

A schema is testable. A paragraph is not.

```json title="schemas/order-created.schema.json"
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://example.internal/schemas/order-created.schema.json",
  "title": "OrderCreated",
  "type": "object",
  "required": ["order_id", "customer_id", "amount_cents", "currency", "created_at"],
  "properties": {
    "order_id": { "type": "string", "format": "uuid" },
    "customer_id": { "type": "string", "format": "uuid" },
    "amount_cents": { "type": "integer", "minimum": 0 },
    "currency": { "type": "string", "pattern": "^[A-Z]{3}$" },
    "created_at": { "type": "string", "format": "date-time" }
  },
  "additionalProperties": false
}
```

`additionalProperties: false` is the enforcement teeth. It turns an undocumented field into a rejected payload instead of a silent addition nobody reviewed.

### Validate every payload against the schema, in CI

The schema is worthless if nothing checks payloads against it before merge.

```bash title="scripts/validate-contract.sh"
#!/usr/bin/env bash
set -euo pipefail

SCHEMA="schemas/order-created.schema.json"
SAMPLES_DIR="samples/order-created"

for sample in "${SAMPLES_DIR}"/*.json; do
  echo "Validating ${sample} against ${SCHEMA}"
  check-jsonschema --schemafile "${SCHEMA}" "${sample}"
done
```

Wire the script into the pipeline so a schema violation fails the build, not just a code review comment:

```yaml title=".github/workflows/validate-data-contracts.yml"
name: Validate Data Contracts

on:
  pull_request:
    paths:
      - "schemas/**"
      - "samples/**"

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install validator
        run: pip install check-jsonschema
      - name: Validate contract samples
        run: bash scripts/validate-contract.sh
```

Point the documentation for this domain directly at the schema file and this workflow. A reader should be able to jump from the doc to the exact gate that enforces it, not take the doc's word for it.

### Keep the doc close to the gate

- **Version the schema in the same repo as the docs**, so a schema change and its doc update land in the same pull request.
- **Link the doc section to the schema file path and the CI job name**, not to a description of them.
- **Review schema changes like API changes.** A required field added to `required` is a breaking change for every consumer.

## Consequences

### Benefits

| Benefit | Impact |
| ------- | ------ |
| Enforced compatibility | Consumers build against a guarantee, not a guess |
| Faster onboarding | New engineers read one schema instead of tracing consumer code |
| Caught drift | A payload that violates the contract fails CI before it reaches production |
| Clear iteration boundary | Teams know exactly which fields they can change freely |

### Trade-offs

| Trade-off | Mitigation |
| --------- | ---------- |
| Schema maintenance overhead | Only apply to boundaries with real external consumers |
| Slower changes to contracted fields | That friction is the point: coordinate before breaking consumers |
| Docs can still drift from the schema file itself | Link, don't duplicate. The doc should reference the schema, not restate it |

## Related Patterns

- **[Secure-by-Design Pattern Library](../security/secure-by-design/index.md)**: Enforcing properties at admission time rather than trusting convention
- **[Fail Fast](../error-handling/fail-fast/index.md)**: Rejecting bad input before it enters the pipeline
- **[Three-Stage Design](../index.md#pattern_categories)**: Validation as a discrete stage before processing
