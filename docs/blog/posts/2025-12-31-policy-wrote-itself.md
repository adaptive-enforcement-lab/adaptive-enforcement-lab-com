---
title: The Policy That Wrote Itself
date: 2025-12-31
authors:
  - mark
categories:
  - Policy-as-Code
  - Kubernetes
  - Automation
description: >-
  When every team needs pod security policies but nobody wants to write YAML. The template library that turns policy enforcement into fill-in-the-blanks.
slug: policy-wrote-itself
---
# The Policy That Wrote Itself

12 teams. 47 namespaces. 1 security requirement. 0 teams wanted to write policies.

The mandate came down: all workloads need pod security policies. No root containers. No privileged escalation. No host volumes. Standard stuff. Every team got the requirement. Then the work stalled.

Policy-as-Code is powerful. Enforcement at admission time stops bad deployments before they reach etcd. But power has a price: someone has to write YAML.

Team A wrote a policy. 34 lines. Solid.

Team B copy-pasted it. Forgot to update the label selectors. Now it applies to everything, including system services. Everything gets rejected. Team B spends four hours debugging why their monitoring won't deploy.

Team C started from scratch. Different syntax. Nested conditions. Hard to read. Works, mostly.

Team D went with "we'll do it next sprint." Still waiting.

The pattern was obvious: enforcement is easy. Enforcement at scale isn't. Every team writing their own policies means every team makes the same mistakes.

Same mistakes repeated 12 times is an incident waiting to happen.

<!-- more -->

---

## The Problem with Copy-Paste Enforcement

Policy-as-Code works when policies are correct. When they're copy-pasted, mutated, and locally reinterpreted, they become a liability.

Here's what actually happened:

- **Team A's policy**: Targeted only `app=workload` namespaces. Smart, scoped.
- **Team B's policy**: Copy-pasted without understanding the label selectors. Now it fires on all pods. Admission controller rejects everything that doesn't match their specific conditions. Two hours until someone notices.
- **Team C's policy**: Different syntax. `securityContext.runAsNonRoot` in one place, `runAsUser != 0` in another. Are they enforcing the same thing? Nobody knows.
- **Team D's policy**: Doesn't exist yet. Workloads run as root because "we'll add it later."

End result: 4 different enforcement patterns across 12 teams. Some conflict. Some are weaker than others. All are inconsistent.

This is security theater.

!!! warning "Consistency is Enforcement"
    When every team writes policies independently, you don't have enforcement. You have theater. Different policies look like security. They feel like security. They don't actually enforce anything consistently.

---

## The Template Solution

The fix was simple: stop letting teams write policies. Give them templates.

A template library with variables. Teams fill in blanks. Validation ensures correctness. Policy deployment becomes a form, not an art project.

Here's what that looks like in practice:

### Step 1: Define the Template

```text
Template: Pod Security Policy - Standard Workload
Inputs:
  - Namespace label selector (required)
  - Container image registry (required)
  - Allow privileged escalation? (default: false)
  - Allow host networking? (default: false)
```

No writing. Just inputs.

### Step 2: Teams Fill the Blanks

Team A: Namespace selector = `app=accounting`, registry = `registry.company.com`, escalation = false, host networking = false.

Team B: Namespace selector = `app=billing`, registry = `registry.company.com`, escalation = false, host networking = false.

Team C: Namespace selector = `app=ml-training`, registry = `registry.company.com`, escalation = true (for GPU workloads), host networking = false.

Same template. Different inputs. All guaranteed valid.

### Step 3: Validation Before Deployment

The template engine validates inputs before generating YAML:

- Is the namespace selector a valid Kubernetes label?
- Does the registry URL match the allowed pattern?
- Are the boolean flags actually booleans?
- Does the combination of settings create any conflicts?

If any validation fails, the policy doesn't generate. Teams get specific feedback: "Privileged escalation is not allowed in this cluster. Remove that input or use a different template."

No bad YAML ever reaches the cluster.

---

## What Changed

### Before Templates

- **Policy deployment time**: 2 hours per team (write, test, iterate, fix, debug, merge)
- **Policy bugs**: 23 found in production (scope errors, syntax issues, logic conflicts)
- **Team friction**: Every team arguing about their specific use case, needing exceptions, needing special cases
- **Consistency**: 0%

### After Templates

- **Policy deployment time**: 15 minutes per team (fill form, validate, deploy)
- **Policy bugs**: 0 (validation prevents malformed policies)
- **Team friction**: Minimal (templates are pre-approved, no custom write exceptions)
- **Consistency**: 100%

The difference wasn't technology. Templates and validation existed. The difference was removing the write-it-yourself option.

!!! tip "Constraint as Enablement"
    Removing choice doesn't restrict teams. It frees them. They don't have to understand YAML syntax. They don't have to debug policy logic. They fill blanks. Validation ensures correctness. They move on.

---

## Real-World Impact

The 47 namespaces went from 4 different policy patterns to 1 template-based standard.

Kubernetes admission controller now rejects non-root-anything consistently. Image registries validate consistently. Privileged containers get caught at admission time, not in production.

23 policy bugs became 0.

More importantly: new teams don't have to learn policy-as-code. They don't have to read documentation. They fill a form. A template-driven system writes the policy for them.

The policy writes itself.

---

## This Is Automation

This is what automation actually means. Not code running on a schedule. Not webhooks firing on events.

Automation means removing human choice in favor of validated, correct patterns.

Template libraries do that.

### When Templates Work Best

- **High enforcement volume**: Many teams, same requirements (pod security policies, network policies, RBAC, secrets management)
- **Varied inputs, fixed constraints**: Teams have different namespaces and registries but same security boundaries
- **Low change frequency**: Policy rules stay stable; only team-specific variables change
- **High risk from errors**: Bad policies break deployments or create security gaps

Pod security policies fit all four criteria.

### How to Build a Template Library

The [Policy Template Library](../../enforce/policy-as-code/template-library/index.md) covers:

- **Template design patterns**: What makes a good template vs a bad one
- **Validation frameworks**: How to validate inputs before generating policies
- **Variable scoping**: Making variables flexible enough for variation without creating escape hatches
- **Distribution**: Getting templates to teams (CLI tool, web interface, CI/CD integration)
- **Monitoring**: Tracking which templates get used, which inputs get rejected, what fails at deployment

---

## The Takeaway

Policy-as-Code enforcement at scale isn't about better policies. It's about removing the need to write them.

12 teams, 47 namespaces, 1 requirement, 0 teams writing code. That's enforcement done right.

The policy wrote itself. Your teams write forms.

---

*47 namespaces. 1 template library. 0 policy bugs. 15 minutes to security.*
