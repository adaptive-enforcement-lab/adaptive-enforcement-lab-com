---
title: Automated On-demand Test Environments for Performance and Size Benchmarking
nav_title: On-Demand Environments
description: >-
  Implement automated, on-demand test environments in CI/CD pipelines. Compare performance and
  resource consumption across application and infrastructure versions for efficiency.
---
Implementing automated, on-demand test environments provides a reliable, repeatable mechanism
for comparing performance characteristics and resource footprints between different versions
of a system. This practice moves beyond simple unit or integration testing to create ephemeral,
full-stack replicas for executing targeted benchmarks within a continuous deployment pipeline.

!!! warning
    On-demand environments can lead to significant cost overruns and resource contention if
    not properly managed. Always implement automated teardown procedures and resource quotas
    as a core part of the design.

## Defining Environments as Code

The foundation of automated environments is treating their configuration as code. All aspects
of an environment, such as the application version, resource allocation, and network policies,
should be defined in version-controlled configuration files, typically YAML or JSON. This
approach, often part of a broader GitOps strategy, ensures that environment creation is
repeatable and auditable.

In a common pattern, a central values file (e.g., `values.qa.yaml`) within an operations
repository defines the state of various environments. Modifying this file becomes the sole
mechanism for spinning up or tearing down a sandbox. For example, to initiate a test, a
pipeline job would update a boolean flag or a version tag in this file and commit the change.
A CD controller then applies this change to the target cluster.

This declarative model simplifies environment management. Instead of running a series of imperative commands (`kubectl apply`, `helm install`), the pipeline's only task is to update a single, well-defined text file.

## Triggering On-Demand Deployments

With environment definitions stored in Git, deployments can be triggered by pull requests. A typical workflow involves a CI/CD platform (like GitLab CI, GitHub Actions, or Jenkins) that watches for changes to specific branches or paths within the operations repository.

When a change is detected, for instance, a platform engineer merging a branch to start a
benchmark, the pipeline executes a predefined job. This job is responsible for updating
the environment's configuration file to deploy the specified version of the application
or infrastructure. These triggers can be configured for various scenarios:

-   **Manual Trigger**: A developer or SRE manually runs a pipeline job to deploy a sandbox
    for ad-hoc testing.
-   **PR-based Trigger**: A pull request to the main application repository automatically
    deploys the changes to a dedicated preview environment.
-   **Scheduled Trigger**: A nightly job spins up an environment to run a comprehensive performance regression suite.

The key is that the trigger is integrated into the existing development workflow, making environment creation a low-friction, automated step rather than a manual chore.

## Isolate Environments for Accurate Benchmarking

For performance and size comparisons to be meaningful, the test environments must be isolated
from each other and from shared, long-lived environments like staging or production. Without
isolation, tests can be skewed by "noisy neighbors"; these are other services competing for
CPU, memory, I/O, or network bandwidth.

This was critical when comparing database index sizes and data loader performance. Two distinct
sandboxes, `sandbox-v1` and `sandbox-v2`, were created in the quality assurance cluster.
Each was a self-contained unit with its own instance of the application, database, and
supporting services. This allowed for a direct, side-by-side comparison of the two versions
under identical conditions, without external interference.

| Environment Type | Isolation Level | Use Case |
| :--- | :--- | :--- |
| **Shared Dev/QA** | Low | General-purpose integration testing; not suitable for benchmarking. |
| **Ephemeral Sandbox** | High | Dedicated, short-lived environment for a single feature or benchmark. |
| **Production Replica** | Complete | A full-scale, isolated copy of production for load testing or disaster recovery drills. |

For most performance and size comparison tasks, ephemeral sandboxes provide the right balance of isolation and cost-effectiveness.

## Automating Performance and Size-Analysis Workflows

Once an environment is running, the benchmark process itself should be fully automated. This involves running a specific workload against the system and collecting the relevant metrics. The commits show two distinct automated workflows:

1.  **Database/Index Size Comparison**: This workflow involves deploying a specific version of the
    application to a dedicated sandbox. After deployment, a script or
    job connects to the database instance, runs a query to measure the on-disk size of key
    tables and indexes, and reports the results. This is crucial for catching unintended
    growth in storage footprint, which can have significant cost and performance
    implications at scale.

2.  **Data Loader Performance Benchmark**: This test focuses on the performance of a specific
    component, a "data loader" service. The workflow deploys the new version of the service
    (`v2`) into its sandbox, then uses a specialized client to execute a load generation
    script. This script simulates a realistic workload, measuring metrics like throughput,
    latency, and error rates.

In both cases, the pipeline orchestrates the entire process: deploying the environment, running the test tooling, and collecting the output.

## Benchmarking Strategies: A Comparative Approach

The goal of these on-demand environments is not just to measure performance, but to compare it
against a known baseline. The `v1` vs. `v2` sandbox model is a classic and effective
strategy. By spinning up two parallel environments: one running the current stable version
(`v1`) and the other running the new version (`v2`), teams can get a clear, immediate signal
on the impact of their changes.

This comparative approach helps answer critical questions:

-   Does the new code introduce a performance regression?
-   Has the change unexpectedly increased the memory footprint or disk usage?
-   Does a new feature scale as expected under load?

The results of these comparisons should be published automatically, either as a comment on the associated pull request or as a report in a metrics dashboard. This makes the performance impact of every change visible to the entire team.

## Automated Teardown and Resource Management

The lifecycle of an on-demand environment is not complete until it has been destroyed. The
commit history clearly shows `start` and `stop` actions for each sandbox, highlighting the
ephemeral nature of these environments. Leaving unused sandboxes running is a common
anti-pattern that leads to wasted resources and increased costs.

The same mechanism used to create the environment, a commit to a `values.yaml` file, should be
used to tear it down. The final stage of the CI/CD pipeline, after the benchmark results have
been collected and reported, should be a job that reverts the configuration change,
effectively setting the `enabled` flag for that sandbox to `false`. This ensures that
resources are released as soon as they are no longer needed, keeping the testing process
efficient and cost-effective.
