---
title: The Label That Changed Everything
date: 2026-09-18
authors:
  - mark
categories:
  - engineering
  - architecture
  - migration
description: >-
  A server-side dry-run against our admission controller revealed a single label as the key to our data architecture migration, enforcing a new path forward.
slug: the-label-that-changed-everything
---

It wasn’t a failing test or a sudden outage, rather a server-side dry-run against
our admission controller. This revealed the path forward. A single, innocuously
named label was about to become the fulcrum of our entire data architecture
migration. The controller rejected our workflow template, not due to a syntax
error, but because we hadn't declared an `assets/` output key. In that moment,
the strategy crystallized: we wouldn't just encourage teams to migrate; we'd
enforce it at the point of admission.

<!-- more -->

This story is about a multi-quarter effort to move from a brittle, file-based
data dump system to a modern, asset-based streaming architecture. It’s a journey
about managing interim compatibility, building bridges between old and new, and,
most critically, using policy to drive architectural change.

## The Old World: JSON Dumps and Cron Jobs

For years, our `directory-discovery` service operated on a simple, if crude,
principle. Scheduled jobs would run, collecting information about our users
and groups. These were then dumped into massive JSON files (`groups.json`,
`users.json`) in a shared storage volume. Various downstream systems,
like our internal `auth-cli`, would then parse these files to get the data
they needed.

This worked, but it was fragile. The system was tightly coupled to the file
format; any change to the schema was a breaking change. Data was always stale,
its freshness dictated by the last cron job run. There was no single source
of truth, just a collection of files overwritten on a schedule. We were living
on borrowed time, and the debt was coming due. The system was opaque,
untraceable, and a nightmare to debug.

## The Goal: A Streaming Asset Architecture

The vision was clear: we needed to move to an event-driven, streaming architecture.
Instead of monolithic data dumps, we wanted our services to produce and consume
well-defined "assets." These assets would be versioned, discoverable, and
published to a central artifact registry.

In this new world, the `directory-discovery` collector wouldn't write giant
JSON files. Instead, it would publish three distinct, versioned coordinates
to our data bus. Downstream consumers would subscribe to these streams, getting
real-time updates from a single, reliable source of truth. This approach would
decouple our systems, improve data freshness, and give us a clear lineage for
every piece of data.

## First Steps: Building the Bridge

You can't just turn off a critical system overnight. The `auth-cli` was a vital
tool, still expecting `groups.json` and `users.json`. Our first task was to build
a bridge, modifying `auth-cli` to read from new asset streams. This significant
change moved it from a file-based to a stream-based consumer.

This was the first major step. By migrating the only consumer of the old
`gws-discovery/{groups,users}.json` files, we had effectively deprecated them.
The path was now clear to stop producing them entirely. It felt like a huge win,
and it was, but a more complex challenge lay just beneath the surface.

## The Hybrid State: Supporting Two Worlds at Once

Not every service could be migrated at once. A critical service, the
`identity-resolver`, still relied on a file named `memberships.json`. This service
had its own migration path and its own set of consumers to coordinate with.
We couldn't break it.

This led to a necessary, if slightly awkward, hybrid state. We configured our
collection workflow to stop generating `groups.json` and `users.json`. The code
was deleted, data bus keys removed, and tests explicitly asserted their absence.
However, `memberships.json` continued to be written to the shared volume. It was
no longer a formal "databus artifact," but an implementation detail: a temporary
compatibility layer. Its sole purpose was to allow an ancillary process to hash
it and push it to the artifact registry, where the `identity-resolver`'s warm-path
loader expected to find it.

!!! warning
    Managing a hybrid state is risky. Strong automated tests are crucial to
    enforce the boundaries of the old world. Our tests didn't just check for
    new behavior; they asserted that the old artifacts (`users.json`,
    `groups.json`) were gone. Without this, legacy code or assumptions can
    easily creep back in.

This interim state was a pragmatic compromise. It allowed us to make progress
without a "big bang" migration, de-risking the entire effort by breaking it
into manageable, verifiable chunks.

## Flipping the Switch: From Dumps to Streams

With the `auth-cli` migrated and a plan in place for the `identity-resolver`,
we were ready to flip the switch. We reconfigured the workflow template for the
`directory-collection` service. The old outputs were removed. The new outputs
were three asset coordinates. The service was no longer a file producer; it was
now an asset producer.

This was the moment of truth. We had done the work, but how could we be sure
it held? How could we prevent other teams, or even our future selves, from
accidentally re-introducing old patterns?

## Enforcement is Everything

This is where the admission controller came in. We had a rule, `Rule B`, in
our ops admission controller. It was simple: any workflow template that did
not declare an `assets/` output key would be rejected. This was the backstop.
It was the policy that would enforce our new architecture.

To complete the `directory-collection` service migration, we needed to add the
`asset-producer` label. Crucially, we could only apply this label *after* the
service's outputs were true asset streams. Applying it to a template that still
declared file-based outputs would have resulted in the admission controller
rejecting it.

This created a powerful feedback loop. The label wasn't just metadata for
tracking migration progress; it was a non-negotiable contract. To earn the
`asset-producer` label, your service *had* to conform to the new architecture.
There was no other way. We verified this with a server-side dry-run against the
live admission controller, confirming acceptance of our newly configured,
stream-producing service.

## The Payoff: A Single Source of Truth

With the migration of the core service complete, the benefits started to roll in.
The old, untraceable JSON dumps were gone. In their place, we had a clean,
versioned stream of assets flowing through our system. Debugging became easier.
We could finally trace the lineage of our data from producer to consumer.

The most significant change, however, was cultural. The admission controller
had transformed an architectural guideline into a hard requirement. It was no
longer possible to create new services following the old, brittle pattern. The
path of least resistance was now the correct path.

## Lessons Learned

This journey from file dumps to asset streams was more than just a technical
migration. It taught us a valuable lesson about driving change. It's not enough
to build a better system. You have to make it easier to use the new system than
the old one. And sometimes, you need to make it impossible to use the old one
at all.

Policy-driven enforcement, through tools like admission controllers, is a powerful
mechanism. It turned our architectural vision into a verifiable, non-negotiable
reality, ensuring the hard work of migration would stick. The quiet mandate of
that one label changed everything.
