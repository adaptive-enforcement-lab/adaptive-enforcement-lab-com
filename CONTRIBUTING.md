# Contributing

Contributions to Adaptive Enforcement Lab documentation are welcome.

## Quick Start

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## Development Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install mkdocs-material
mkdocs serve
```

## Documentation Standards

### Writing Style

- Tactical and direct
- Short sentences, real verbs
- Educational without being preachy
- Code examples over lengthy explanations

### Formatting

- Use MkDocs Material admonitions for tips, warnings, and examples
- Mermaid diagrams use Ghostty Hardcore theme colors
- YAML for workflow examples, bash for scripts
- Tables for permissions and configuration options

### Mermaid Diagrams

Apply the Ghostty Hardcore color palette:

```text
Background:  #1b1d1e
Foreground:  #f8f8f3
Orange:      #fd971e
Cyan:        #65d9ef
Purple:      #9e6ffe
Green:       #a7e22e
Pink:        #f92572
Gray:        #515354
```

### File Structure

New operator manual content goes in `docs/operator-manual/`. Group related topics into directories with an `index.md` overview.

### Blog Posts

Blog posts live in `docs/blog/posts/` with filename format `YYYY-MM-DD-slug.md`.

**Required frontmatter:**

```yaml
---
date: 2025-01-15
provenance: human
authors:
  - mark
categories:
  - DevSecOps
  - Automation
description: >-
  A concise summary for RSS feeds and social sharing.
  Keep under 160 characters for optimal display.
slug: url-friendly-post-slug
---
```

**RSS Feed considerations:**

- The `description` field is used for RSS feed item summaries
- Use `<!-- more -->` to mark the excerpt boundary
- Keep content above `<!-- more -->` clean - avoid MkDocs-specific syntax (admonitions, tabs) as RSS readers won't render them
- Mermaid diagrams and admonitions should appear after the `<!-- more -->` marker
- RSS feeds use excerpts by industry standard - full content stays on the site

**Content structure:**

```markdown
# Post Title

Opening hook paragraph - appears in RSS feed.

<!-- more -->

## Rest of content

!!! tip "Admonitions work here"
    After the more marker, use full MkDocs features.
```

### Provenance

Human work and machine drafts stay apart. Every page under `docs/` (except `docs/includes/`) carries a `provenance` key in its frontmatter:

- `human`: written by a human. Blog posts list `authors: [mark]`.
- `human_edited`: drafted by the content-machine pipeline, then edited by a human. Blog posts list `mark` and `content-machine`.
- `machine`: drafted by the content-machine pipeline and merged without human edits. Blog posts list only `content-machine`.

Pages marked `machine` or `human_edited` render a one-line note above the content. The blog's author pages separate the two authors; URLs do not change.

Machine drafts arrive as `machine`. The reviewer keeps that label or changes it to `human_edited` before merging, after reading the edit ratio between the pipeline's commit and the PR head.

`scripts/check-provenance.sh` runs as a pre-commit hook and in CI. It fails a page with no or an unknown `provenance` value, a blog post whose authors do not match its provenance, and a file that claims `human` although its first commit (renames followed) is by `ael-content-machine[bot]`.

## Pre-commit Hooks

The repository uses markdownlint. Run `pre-commit install` to set up hooks locally.

## Pull Requests

- Clear, descriptive titles
- Reference any related issues
- One logical change per PR
- Ensure `mkdocs build` succeeds

## Questions

Open an issue for questions or discussion.
