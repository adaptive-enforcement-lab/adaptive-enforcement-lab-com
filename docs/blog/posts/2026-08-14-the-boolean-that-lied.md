---
title: The Boolean That Lied
date: 2026-08-14
authors:
  - mark
categories:
  - Software Engineering
  - CI/CD
  - Best Practices
description: >-
  IS_RELEASE_CANDIDATE=false shipped to production anyway. The string "false"
  evaluated as truthy. Here's how we stopped trusting booleans in CI.
slug: the-boolean-that-lied
---
# The Boolean That Lied

I set `IS_RELEASE_CANDIDATE=false` in the pipeline config. Ten minutes later,
production shipped a release nobody signed off on.

The flag was right. The intent was right. But somewhere between the YAML file
and the deployment script, `false` stopped meaning false. The parser read the
string `"false"` as a non-empty value, and non-empty meant truthy. My kill
switch had flipped itself the moment I set it.

I've since learned this wasn't a fluke. It's a pattern with a name, and it
bites teams that treat configuration as an afterthought.

<!-- more -->

This wasn't a one-off bug in one script. Across every project I've touched,
someone eventually reads a config value from an environment variable, a YAML
file, or a `.env` file and assumes the type matches the intent. A `"true"`
string is not a `true` boolean, but plenty of languages and parsers treat them
the same. Some go further and count *any* non-empty string as truthy. In
CI/CD, where automated decisions ride on these values, that ambiguity is a
live wire. Is `FEATURE_TOGGLE_ENABLED=false` disabling a feature, or is the
mere presence of the string "false" enabling it?

We stopped guessing. Configuration schemas got codified, and we stopped
trusting deployment scripts to interpret flags like `helm_is_release` or
`run_preflight_checks` on faith. A `"false"` string that should have been a
boolean `false` now fails the build immediately, instead of failing a release
later.

This wasn't a new linter bolted on as an afterthought. It was a decision to
treat configuration with the same rigor as application code, whether that
meant a typed loader or a small assertion script in CI.

!!! warning "Beware of implicit conversions"
    Many languages and frameworks have silent implicit type conversions that can turn `"false"` into `true` or `0` into `false` in unexpected ways. Always explicitly cast or validate configuration inputs, especially when they drive critical path logic.

This practice has saved us from numerous headaches. No more scrambling to
revert deployments because a feature flag didn't behave as expected in
production. The CI pipeline now acts as an early warning system. It fails
quickly and clearly if configuration does not meet its expected contract.
This small, defensive programming habit offers immense dividends. It improves
stability and developer sanity. By being precise about boolean types in our
integration pipeline, we ensure solid, unambiguous deployments.

## Related

- [Strict Mode Execution](../../patterns/error-handling/fail-fast/techniques/strict-mode.md) - Shell strict mode, typed configs, and schema validation to catch bad values before they run
