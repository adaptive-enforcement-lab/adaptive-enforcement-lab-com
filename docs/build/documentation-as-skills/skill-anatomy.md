---
title: Skill Anatomy
description: >-
  The structure of a generated Claude Code skill: frontmatter, section mapping, progressive disclosure, and extracted code artifacts.
tags:
  - documentation
  - ai-agents
---
# Skill Anatomy

What a generated skill directory contains, and which parts of the source document produce each file.

## Directory Layout

```text
plugins/patterns/skills/idempotency/
├── SKILL.md           # Always written
├── examples.md        # If the source has 2+ code blocks
├── reference.md       # If the source exceeds 200 lines
├── troubleshooting.md # If a troubleshooting section exists
└── scripts/
    ├── example-1.mermaid
    └── example-2.yaml
```

Only `SKILL.md` is guaranteed. The optional files exist to keep the always-loaded file small while making depth available when needed.

!!! abstract "Progressive Disclosure"
    `SKILL.md` is what the agent reads to decide relevance and take action. Everything else is loaded only if the task requires it. Pushing bulk into side files keeps the routing decision cheap.

## Frontmatter

Generated skill frontmatter carries two fields:

```yaml
---
name: idempotency
description: >-
  Build automation that survives reruns. Idempotent operations let you rerun
  workflows without fear of duplicates, corruption, or cascading failures.
---
```

`name` comes from the derived skill name. `description` is copied **verbatim** from the source document's frontmatter. No summarization, no truncation, no fallback.

!!! warning "The Description Is the Entire Routing Signal"
    This field is the only text consulted when deciding whether a skill is relevant. A description that describes the *topic* rather than the *situation* will not route well.

    Weak: `Patterns for idempotency in distributed systems.`

    Strong: `Build automation that survives reruns. Use when an operation may be retried, replayed, or executed concurrently.`

    Because the value is copied verbatim, improving skill routing means editing the source document's frontmatter. There is no separate place to tune it.

## Section Mapping

Headings in the source document are matched against component buckets using case-insensitive substring matching in both directions. Each bucket carries a keyword list.

| Component | Matches headings containing |
| --- | --- |
| When to Use | Why It Matters, When to Use, Use Cases, What You'll Learn, Overview |
| Prerequisites | Prerequisites, Requirements |
| Implementation Steps | Implementation, Setup, Configuration |
| Key Principles | Key Principles, Principles |
| When to Apply | When to Apply, Decision |
| Techniques | Techniques, Methods, Approaches |
| Comparison | Comparison, Versus, Trade-offs |
| Anti-Patterns | Anti-Patterns, Pitfalls, Mistakes |
| Troubleshooting | Troubleshooting, Debugging |
| Related Patterns | Related, See Also |

Matching recurses into subsections. Two behaviors are worth knowing:

- **When to Use falls back to the introduction.** If no heading matches, the text between the H1 and the first H2 is used instead. A strong opening paragraph is therefore load-bearing.
- **Techniques are capped.** Only the first five technique subsections are extracted. A document with twelve produces a skill covering five.

Documents written with conventional headings extract richly. Documents with idiosyncratic ones, such as "The Story So Far" or "Some Thoughts", match nothing and produce a thin skill with a warning.

## Code Block Handling

Fenced code blocks are extracted to `scripts/` and named by position and language: `example-1.yaml`, `example-2.sh`, `code-3.txt` when the language is unset.

Blocks are also handled inline based on length:

- **Ten lines or fewer**: kept inline in `SKILL.md`
- **More than ten lines**: removed from `SKILL.md` and replaced with a pointer to `examples.md`

This keeps the primary file readable while preserving every example.

!!! tip "Language Tags Become File Extensions"
    The fence language maps directly to the extension, with an unrecognized language passed through unchanged. A ` ```mermaid ` fence becomes `example-1.mermaid`. Tag fences accurately. The tag is metadata, not decoration.

## Optional File Thresholds

| File | Condition |
| --- | --- |
| `examples.md` | Source contains 2 or more fenced code blocks |
| `reference.md` | Source exceeds 200 lines |
| `troubleshooting.md` | A heading matches the troubleshooting bucket |

`reference.md` contains the full source document with MkDocs admonitions converted to blockquotes. It is the escape hatch for cases where mapped sections lost nuance.

## Admonition Conversion

MkDocs admonitions are not portable markdown, so they are converted to blockquotes:

```markdown
!!! tip "Cache Aggressively"
    Skip work when the output cannot change.
```

becomes:

```markdown
> **Cache Aggressively**
> Skip work when the output cannot change.
```

Content is de-indented during conversion. Admonition *titles* survive as bold text, so a titled admonition carries more signal into the skill than an untitled one.

---

**Next:** [Marketplace and Versioning](marketplace-versioning.md) covers how manifests and versions are generated.
