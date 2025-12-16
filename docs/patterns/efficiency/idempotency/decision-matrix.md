---
title: Decision Matrix
description: >-
  When to invest in idempotency and when to skip it.
  A scoring guide for calibrating your investment.
---

# Decision Matrix

!!! tip "Investment Guide"
    Not every workflow needs bulletproof idempotency. Use this matrix to decide how much investment makes sense.

## Visual Guide

```mermaid
%%{init: {
  'theme': 'base',
  'themeVariables': {
    'quadrant1Fill': '#5af78e',
    'quadrant2Fill': '#f3f99d',
    'quadrant3Fill': '#57c7ff',
    'quadrant4Fill': '#ff6ac1',
    'quadrant1TextFill': '#1b1d1e',
    'quadrant2TextFill': '#1b1d1e',
    'quadrant3TextFill': '#1b1d1e',
    'quadrant4TextFill': '#1b1d1e',
    'quadrantPointFill': '#f8f8f3',
    'quadrantPointTextFill': '#1b1d1e',
    'quadrantXAxisTextFill': '#f8f8f3',
    'quadrantYAxisTextFill': '#f8f8f3',
    'quadrantTitleFill': '#f8f8f3'
  }
}}%%
quadrantChart
    title Idempotency Investment Decision Matrix
    x-axis Low Failure Risk --> High Failure Risk
    y-axis Low Recovery Cost --> High Recovery Cost
    quadrant-1 Full Investment
    quadrant-2 Selective Guards
    quadrant-3 Basic Handling
    quadrant-4 Critical Ops Only
    One-off scripts: [0.15, 0.15]
    Dev/test workflows: [0.25, 0.20]
    Simple CI builds: [0.30, 0.35]
    Scheduled reports: [0.55, 0.25]
    API integrations: [0.65, 0.45]
    Multi-repo sync: [0.75, 0.70]
    Deployment pipelines: [0.80, 0.85]
    Compliance automation: [0.85, 0.90]
```

---

## Scoring Factors

| Factor | Low Priority (0 pts) | High Priority (1 pt) |
| -------- | --------------------- | ---------------------- |
| **Failure frequency** | Rarely fails | Fails often (network, APIs, rate limits) |
| **Recovery cost** | Quick manual fix | Hours of manual intervention |
| **Operation count** | Single operation | Many operations (matrix, loops) |
| **Schedule** | Manual trigger only | Cron/scheduled runs |
| **Criticality** | Nice-to-have | Business critical |
| **State complexity** | Simple/stateless | Complex state across systems |

---

## Scoring Guide

**0-2 points**: Minimal idempotency. Basic error handling sufficient.

**3-4 points**: Selective idempotency. Make critical operations idempotent, accept some manual recovery.

**5-6 points**: Full idempotency. Invest in comprehensive guards and state management.

---

## When NOT to Invest

### One-Off Scripts

If you're running something once and throwing away the code, don't over-engineer.

### Fast Manual Recovery

If fixing a failed run takes 30 seconds manually, spending hours on idempotency guards isn't worth it.

### Truly Unique Operations

Some things should only happen once. User signup, payment processing, audit log entries. These need different patterns (exactly-once semantics, transaction logs).

### Development/Testing

Local development scripts don't need production-grade idempotency. Optimize for iteration speed.
