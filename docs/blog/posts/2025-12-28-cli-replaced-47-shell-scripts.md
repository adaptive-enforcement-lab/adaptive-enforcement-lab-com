---
title: The CLI That Replaced 47 Shell Scripts
date: 2025-12-28
authors:
  - mark
categories:
  - Go
  - Kubernetes
  - Engineering Patterns
description: >-
  When kubectl isn't enough and shell scripts become unmaintainable. The architecture decisions that make CLIs testable, deployable, and debuggable.
slug: cli-replaced-47-shell-scripts
provenance: human
---
# The CLI That Replaced 47 Shell Scripts

47 shell scripts. 12 CronJobs. Zero test coverage. One production incident that forced a rebuild.

The kubectl plugin pattern couldn't handle our complexity. Shell scripts worked until they didn't. No type safety. No testing. Debugging meant reading logs after failures.

Then came the rewrite: One CLI. 89% test coverage. Runs in CronJobs and Argo Workflows. Distroless container. Multi-arch binaries. Production deployments via Helm.

<!-- more -->

## The Accumulation

It started innocently. A bash script to rollout restart deployments. Another to watch resources. One more to handle ConfigMap updates.

Each solved a real problem. Each lived in its own file. Each got its own CronJob.

**Month 1**: 5 scripts
**Month 3**: 15 scripts
**Month 6**: 27 scripts
**Month 12**: 47 scripts

The pattern was always the same.

`kubectl get pods -o json`, piped through `jq` to the names of running pods, then a `while read` loop that did something with each one.

Copy. Paste. Modify. Deploy.

---

## The Breaking Point

The incident happened at 3am on a Tuesday.

A deployment rollout script failed silently. No error. No alert. The logs showed:

```text
./rollout.sh: line 47: syntax error near unexpected token `fi'
```

Someone had edited the script directly on the server. Added a condition. Forgot the closing `fi`. The script failed. Deployments froze.

**Root cause**: No version control enforcement. No syntax validation. No testing.

**Impact**: 4-hour outage. Manual rollback. Incident review.

**Decision**: Rewrite everything. Build it right.

---

## The Requirements

The incident review produced clear requirements:

1. **Type safety** - Compile-time errors, not runtime failures
2. **Testing** - Unit tests, integration tests, mocks
3. **Consistency** - One codebase, one pattern, one deployment method
4. **Local + In-cluster** - Same binary works on laptop and in Kubernetes
5. **Observability** - Structured logging, error context, exit codes

Shell scripts failed all five requirements.

The kubectl plugin pattern got us halfway. Plugins gave us consistency and kubectl-style commands. But they still required bash wrappers, had no built-in testing framework, and debugging remained painful.

We needed something better.

---

## The Discovery: Go + Cobra + client-go

**Go** gave us type safety and testing infrastructure.

**Cobra** gave us the command tree pattern. Every kubectl command uses Cobra. We'd use the same pattern.

**client-go** gave us the Kubernetes API. The same library kubectl uses. Official. Maintained. Well-documented.

The architecture emerged naturally.

Three layers: Cobra commands on top, business logic in `pkg/`, and client-go underneath.

Cobra handles flags, help text, subcommands. Business logic stays pure: inputs → outputs. client-go talks to Kubernetes.

The separation made testing trivial. Mock the Kubernetes client. Pass it to business logic. Assert outputs.

---

## The Orchestrator Pattern

47 scripts meant 47 distinct operations. CronJobs ran them individually. Argo Workflows triggered them on events.

The insight: **Every operation shares the same entry point**.

Instead of this:

Twelve separate CronJobs, each running its own script: `rollout-restart.sh`, `configmap-update.sh`, `pod-cleanup.sh` and more.

We built this:

```bash
# Single binary, multiple subcommands
kubectl-ops rollout restart --deployment nginx
kubectl-ops configmap update --name cache
kubectl-ops pod cleanup --namespace production
```

One binary. One Docker image. One Helm chart. CronJobs call different subcommands instead of different scripts.

The orchestrator pattern unified everything. Same logging. Same error handling. Same RBAC. Same deployment method.

See [Orchestrator Pattern](../../build/go-cli-architecture/command-architecture/orchestrator-pattern.md) for implementation details.

---

## The Testing Victory

Shell scripts had zero test coverage. Bash testing frameworks exist, but nobody used them. Manual testing was the norm.

Go changed that.

**Fake clients** made testing trivial.

A test creates `fake.NewSimpleClientset()`, passes it to `RolloutRestart`, and asserts that exactly one `patch` call reached the API.
The [unit testing guide](../../build/go-cli-architecture/testing/unit-testing.md) has the test.

No real Kubernetes cluster needed. No complex mocking libraries. client-go provides fake clients out of the box.

**The result**: 89% test coverage. CI fails on untested code. Regressions caught before deployment.

Testing patterns detailed in [CLI Testing Guide](../../build/go-cli-architecture/testing/index.md).

---

## The Deployment Story

Shell scripts lived in git. CronJobs pulled them via initContainers. Updates required restarting all CronJobs.

Go CLI deployments became boring (in the best way):

1. **Build**: `go build -o kubectl-ops`
2. **Container**: Distroless base image, single binary, 15MB total
3. **Multi-arch**: arm64 + amd64 builds via GoReleaser
4. **Helm**: One chart deploys all CronJobs with same image, different args

Each CronJob passes different `args` to the same image: `rollout restart --deployment nginx`, `configmap update --name cache`, `pod cleanup --namespace production`.

Same container. Different subcommands. One version. One deployment.

See [Packaging Guide](../../build/go-cli-architecture/packaging/index.md) for container builds and Helm charts.

---

## The Metrics

**Before** (47 shell scripts):

- Test coverage: 0%
- Deployment time: 2 hours (update all CronJobs individually)
- Debug time: 30-60 minutes per incident (read logs, guess context)
- Production incidents: 3-4 per quarter
- Lines of code: ~5,000 bash
- Maintenance burden: High

**After** (Single Go CLI):

- Test coverage: 89%
- Deployment time: 5 minutes (Helm upgrade)
- Debug time: 5-10 minutes (structured logs, stack traces)
- Production incidents: 0 in 6 months
- Lines of code: ~8,000 Go (better structure, more features)
- Maintenance burden: Low

The CLI handles more operations than the original 47 scripts. The codebase is larger, but maintainability improved dramatically.

---

## The Unexpected Wins

### Win 1: In-cluster and Local Work Identically

The same binary works on laptops and in Kubernetes. Kubeconfig authentication for local. ServiceAccount authentication in-cluster. client-go handles both.

`./kubectl-ops rollout restart --deployment nginx` on a laptop reads `~/.kube/config`. The same command in a pod uses the ServiceAccount.

Development and production use identical code paths.

### Win 2: Exit Codes and Automation

Shell scripts returned 0 on success. Go CLI returns semantic exit codes:

- `0`: Success
- `1`: Validation error (bad flags, missing config)
- `2`: API error (cluster unreachable, auth failure)
- `3`: Resource error (not found, already exists)

Argo Workflows use exit codes to determine retry strategies. Different errors get different handling.

### Win 3: Structured Logging

Shell scripts echoed text. Go CLI logs JSON.

A rollout restart logs one JSON line with `level`, `msg`, `deployment`, `namespace` and `duration_ms`.

Grafana queries structured logs. Alerts trigger on specific fields. Debugging becomes data analysis, not text parsing.

---

## The Decision Matrix

When to build a Go CLI vs use shell scripts:

!!! success "Build a Go CLI When..."
    - Operations run in production (reliability matters)
    - Multiple operations share logic (avoid duplication)
    - Testing is required (compliance, audits)
    - Error handling needs context (not just "failed")
    - Operations are complex (multi-step workflows)

!!! warning "Shell Scripts Are Fine When..."
    - One-off scripts (run once, discard)
    - Simple glue between tools (pipe outputs)
    - No error recovery needed (fail fast is acceptable)
    - Local development only (not deployed)

The cutoff for us was 10 scripts. Beyond that, the CLI pattern wins.

---

## The Architecture Guide

This post covered the journey. The architecture guide covers the implementation:

**Command Architecture**:

- [Command Architecture Overview](../../build/go-cli-architecture/command-architecture/index.md) - Meta-architecture and separation of concerns
- [Orchestrator Pattern](../../build/go-cli-architecture/command-architecture/orchestrator-pattern.md) - Single entry point for all operations
- [Subcommand Design](../../build/go-cli-architecture/command-architecture/subcommand-design.md) - Command tree patterns

**Kubernetes Integration**:

- [Client Configuration](../../build/go-cli-architecture/kubernetes-integration/client-configuration.md) - In-cluster vs out-of-cluster auth
- [Common Operations](../../build/go-cli-architecture/kubernetes-integration/common-operations/index.md) - ConfigMaps, rollouts, watches
- [RBAC Setup](../../build/go-cli-architecture/kubernetes-integration/rbac-setup.md) - ServiceAccount permissions

**Testing**:

- [Testing Overview](../../build/go-cli-architecture/testing/index.md) - Unit, integration, e2e patterns
- [Unit Testing](../../build/go-cli-architecture/testing/unit-testing.md) - Fake clients and mocks
- [Integration Testing](../../build/go-cli-architecture/testing/integration-testing.md) - Kind clusters and build tags

**Packaging**:

- [Container Builds](../../build/go-cli-architecture/packaging/container-builds.md) - Distroless images and multi-arch
- [Helm Charts](../../build/go-cli-architecture/packaging/helm-charts.md) - Deployment patterns
- [Release Automation](../../build/go-cli-architecture/packaging/release-automation.md) - GoReleaser and GitHub Actions

---

## The Lessons

**Lesson 1**: Shell scripts work until they don't. The breaking point is unpredictable. Build for reliability before the incident.

**Lesson 2**: Testing isn't optional. The first production bug with no tests is more expensive than writing tests upfront.

**Lesson 3**: Cobra + client-go is the Kubernetes ecosystem standard. Don't fight the ecosystem. Use what kubectl uses.

**Lesson 4**: The orchestrator pattern (single binary, multiple subcommands) scales better than many binaries. One deployment. One version. One image.

**Lesson 5**: Separation of concerns (CLI layer vs business logic) makes testing trivial. Pure functions are easy to test. API clients are easy to mock.

---

## Related Patterns

- **[Go CLI Architecture](../../build/go-cli-architecture/index.md)** - Complete implementation guide
- **[Pre-commit Hooks for Go](../../build/go-cli-architecture/packaging/pre-commit-hooks.md)** - Local validation patterns
- **[Release Pipelines](../../build/release-pipelines/index.md)** - Automated releases with GoReleaser

---

*47 shell scripts became one CLI. Zero test coverage became 89%. 4-hour outages became zero incidents. The production incident forced the rebuild. The Go CLI made it sustainable. kubectl plugin pattern wasn't enough. Cobra + client-go + orchestrator pattern was exactly right.*
