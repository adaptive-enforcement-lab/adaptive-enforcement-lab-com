---
title: One-Line Change, One Hundred Repositories
date: 2026-10-21
authors:
  - mark
categories:
  - engineering
  - developer-experience
description: >-
  Updating a single line of code across 100+ repositories sparked a move to centralized
  pre-commit hook management, transforming our developer experience.
slug: one-line-change-one-hundred-repositories
---
A single, one-line change to a pre-commit hook took three engineers the better
part of a week to roll out. The change itself was trivial, a simple version bump
in a YAML file. The problem was that this one line was scattered across many active repositories, and each one needed its own pull request,
its own review, its own merge. That was the moment I realized our approach to
code quality was fundamentally broken. We were spending more time managing our
tools than using them to build better software.

<!-- more -->

## The tyranny of the manual update

Before we centralized our pre-commit hook management, our developer experience
was a study in frustration. Each of our repositories had its own
`.pre-commit-config.yaml` file. On the surface, this seemed like a good thing.
It gave teams autonomy and control over their local development environment. In
practice, it was a recipe for chaos.

Whenever we needed to update a hook (such as to patch a security vulnerability,
to roll out a new linter, or just to bump a version), we had to do it manually,
one repository at a time. This was a tedious, error-prone process and a huge
time sink. The one-line change I mentioned above, updating our internal
`platform-sdk-hook` to v1.0.2, was a perfect example. We had to:

1.  Clone each repository.
2.  Create a new branch.
3.  Edit the `.pre-commit-config.yaml` file.
4.  Commit the change.
5.  Push the branch.
6.  Open a pull request.
7.  Wait for CI to pass.
8.  Get the PR reviewed and merged.

Rinse and repeat, over a hundred times. It was a soul-crushing amount of work
for such a small change. And it was work that no developer wanted to do.

## The breaking point

The breaking point came when we discovered a critical security vulnerability in
one of our most commonly used hooks. We needed to patch it immediately, but the
thought of another marathon of manual updates was too much to bear. We had to
find a better way.

We gathered a small team of engineers and started brainstorming. We knew we
needed a centralized solution, a single source of truth for our pre-commit
hooks. But we also knew that we couldn't just create a one-size-fits-all
configuration. Different teams had different needs, and we needed to respect
that.

## A centralized, but flexible solution

Our solution was a new, dedicated repository: `neon-ch/workflows`.
This repository would house a collection of curated `.pre-commit-config.yaml`
files, each tailored to a specific type of project (e.g., Python library, Go
service, frontend application).

The key to making this work was a small shell script that we included in our
project templates. This script would pull the appropriate pre-commit
configuration from the `dev-workflows` repository and install it in the local
development environment.

This gave us the best of both worlds. We had a centralized location for managing
our pre-commit hooks, which made it easy to roll out updates and enforce
standards. But we also had the flexibility to create different configurations
for different types of projects.

## Automating the updates

Of course, a centralized repository is only useful if it's kept up-to-date. We
didn't want to trade one form of manual labor for another. So, we automated the
update process using Renovate, a tool that automatically creates pull requests
for dependency updates.

We configured Renovate to monitor the `dev-workflows` repository and to
automatically create a pull request whenever a new version of a pre-commit hook
was released. This meant that we no longer had to manually track new releases
or create pull requests to update our hooks. Renovate did it all for us. The commit history in the repository now shows an automated update from `renovate[bot]`.

!!! tip
    When using Renovate to manage pre-commit hooks, make sure to configure it to update the `rev` field in your `.pre-commit-config.yaml` files. This will ensure that your hooks are always pinned to a specific version, which is a best practice for security and reproducibility.

## The results: speed, safety, and sanity

The results of this project have been nothing short of transformative. We've gone
from spending days on manual updates to rolling out changes in a matter of
minutes. When a new version of a hook is released, Renovate automatically
creates a pull request, our CI pipeline runs the tests, and all we have to do
is click "merge."

This has had a huge impact on our developer experience. We've eliminated a
major source of toil and frustration, and we've made it easier for our
developers to do their best work. We've also improved our security posture.
With automated updates, we can be sure that we're always using the latest,
most secure versions of our pre-commit hooks.

## The rollback that almost wasn't

Of course, no project is without its challenges. One of the biggest hurdles we
faced was convincing teams to give up their local `.pre-commit-config.yaml`
files. Some teams were hesitant to cede control over their development
environment.

We addressed this by working closely with each team to understand their needs
and to create a pre-commit configuration that worked for them. We also made it
clear that this was not a top-down mandate. We were not forcing teams to adopt
this new system. We were offering it as a better way of working.

In the end, the results spoke for themselves. Once teams saw how much time
and effort they could save with centralized pre-commit hook management, they
were eager to adopt the new system.

## The future is automated

This project has been a huge success, but it's just the beginning. We're now looking for other ways to automate our developer workflows and to eliminate toil. We're exploring a similar approach for managing our CI/CD pipelines, our linters, and even our project templates.

The goal is to create a "paved road" for our developers, a set of
well-defined, automated workflows that make it easy to build, test, and deploy
high-quality software. We want our developers to focus on what they do best:
solving problems and creating value for our customers. We don't want them to
waste their time on tedious, manual tasks that can be easily automated.

## Lessons learned

This project has taught me a lot about the importance of developer experience.
It's easy to dismiss things like pre-commit hooks as minor details, but they can
have a huge impact on developer productivity and happiness.

I've also learned that automation is a powerful tool for driving change. By automating the update process, we were able to overcome resistance to our new system and to demonstrate its value in a very concrete way.

Finally, I've learned that the best solutions are often the simplest ones. Our centralized pre-commit hook management system is not a complex piece of technology. It's just a git repository and a shell script. But it has had a profound impact on our engineering organization.
