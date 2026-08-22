---
title: Operator RBAC from Code Markers
date: 2026-08-10
authors:
  - mark
categories:
  - kubernetes
  - operators
  - rbac
description: >-
  Our team struggled with complex RBAC rules for our integration testing
  operator. Manual YAML updates for every change were error-prone and slow.
slug: operator-rbac-from-code-markers
---

I still remember the late-night debugging session. I was staring at a `permission denied`
error in our Kubernetes integration testing operator logs. We'd just introduced
a new custom resource. Despite our best efforts, the operator couldn't get the
permissions it needed to update the `status` field. We meticulously crafted
the RBAC YAML. We tried to grant just enough access, but the Kubernetes API
kept rejecting our requests. This was a familiar frustration, common in every
operator project I'd touched. The manual process of defining roles, role
bindings, and service accounts, then syncing them, felt like a constant
uphill battle. It ate into valuable development time.

<!-- more -->

This wasn't just a one-off problem; it was a symptom of a deeper issue.
Our operator was designed to reconcile a declarative `TestRun` resource
and manage its lifecycle. It was becoming increasingly complex. Each new feature
or modification to our custom resources meant revisiting not just the controller
logic but also the associated RBAC. This friction was unsustainable. We needed
a better way to ensure our operator always had the correct permissions,
automatically and reliably.

That's when the idea solidified: what if we could generate the RBAC
configuration directly from the operator's source code? We already used
a popular operator SDK. It leveraged markers in Go code to define API schemas
and controller logic. Why couldn't we extend this to RBAC? The vision was clear:
developers would focus on business logic and desired Kubernetes interactions.
They would annotate their code with markers. The build process would then
handle the rest, producing precise RBAC definitions.

The immediate benefit was obvious: consistency. No more out-of-sync
permissions or forgotten rules. The RBAC would always reflect the
current state of the operator's responsibilities. It also drastically
reduced the cognitive load on developers. Instead of becoming Kubernetes
RBAC experts, they could express permissions directly alongside the
code that required them.

Beyond RBAC, this principle of declarative, code-driven configuration
extended to other critical aspects of our operator. Take, for instance,
`TestRun` status updates. We embraced Kubernetes Server-Side Apply to end
the ownership conflicts outright. It wasn't just about avoiding those
conflicts; it was about clearly defining responsibility, and keeping
the source of truth for the test's progress with the component
designed to manage it.

!!! tip "Embrace Server-Side Apply for clear ownership"
    When designing Kubernetes controllers, especially for custom resources,
    leverage Server-Side Apply (SSA) for status subresources. It simplifies
    reconciliation logic by clearly demarcating ownership and preventing
    conflicting updates. This significantly reduces debugging time for
    intermittent status issues.

The journey wasn't without its challenges. Integrating the RBAC generation
into our CI/CD pipeline required careful scripting and testing. We had to
ensure the markers were correctly parsed and translated into valid,
minimal YAML. Early iterations sometimes generated overly broad permissions.
This defeated the purpose of fine-grained RBAC. Through iteration and
refinement, we fine-tuned the marker definitions and the generation process
to produce exactly what was needed, no more, no less. This approach not only
streamlined our development workflow. It also significantly enhanced the
security posture of our operator by adhering to the principle of least
privilege by default. Now, when I see a new feature branch, I know the RBAC
will be handled automatically, precisely, and correctly. It frees us up to
focus on delivering robust and reliable integration testing for our
cloud-native applications.

## Related

- [RBAC Setup](../../build/go-cli-architecture/kubernetes-integration/rbac-setup.md) - Manual least-privilege RBAC for a Kubernetes CLI; doesn't cover marker-driven generation, but the same least-privilege reasoning applies
- [RBAC Configuration](../../patterns/argo-workflows/templates/rbac.md) - Why least-privilege RBAC matters for workflow ServiceAccounts; a different execution model, but the same underlying discipline
