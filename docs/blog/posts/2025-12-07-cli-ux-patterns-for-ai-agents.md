---
title: Designing Error Messages AI Agents Can't Misinterpret
date: 2025-12-07
authors:
  - mark
categories:
  - AI Agents
  - CLI Design
  - Go
description: >-
  AI agents take error messages literally. Design CLI output that guides
  correct fixes, not destructive shortcuts.
slug: cli-ux-patterns-for-ai-agents
provenance: human
---
# Designing Error Messages AI Agents Can't Misinterpret

AI coding assistants are increasingly the first responders to pre-commit failures and CI errors. The error messages your CLI produces directly influence how these agents attempt fixes. Often, these fixes happen without human review.

Here's how to design CLI output that guides AI agents toward correct remediation.

<!-- more -->

## The Problem: AI Agents Take Error Messages Literally

Consider this error message:

```text
Error: docs/guide.md exceeds 375 lines
```

An AI agent interprets this as: "The file has too many lines. I'll reduce the lines by removing content."

The result? Deleted documentation sections. Lost context. Angry humans.

!!! danger "Destructive Shortcuts"
    AI agents optimize for the simplest fix. Without explicit guidance, they'll choose deletion over restructuring every time.

---

## The Fix: Explicit Guidance

Better error message:

```text
Error: docs/guide.md exceeds 375 lines

IMPORTANT: Files exceeding line limits should be SPLIT into smaller documents.
Do NOT remove content to meet thresholds. Split logically by topic or section.
```

Now the AI agent knows: split files, don't delete content.

---

## Core Principles

### 1. State What TO DO, Not Just What's Wrong

The bad message only says `Error: Readability score too low`.
The good one names what the score means, `READABILITY: High grade level indicates complex sentences.`, then lists fixes: shorter sentences of 15-20 words, an introductory sentence before each code block.

### 2. Explicitly State What NOT TO DO

AI agents optimize for speed. Prohibit destructive shortcuts.

Two lines do it: `Do NOT remove content to meet thresholds.` and `Do NOT remove technical accuracy. Rewrite for clarity.`

### 3. Provide Specific, Actionable Guidance

Vague instructions produce vague fixes.

"Improve the readability of this document" is vague.
"Break sentences over 20 words into multiple sentences" is a fix an agent can apply.

---

## Implementation: Contextual Warnings

Show different guidance based on failure type.

The CLI counts files over the line limit and files with low readability separately.
It prints the split guidance only when a file is too long, and the readability guidance only when a score failed.
The [error messages for AI agents guide](../../build/go-cli-architecture/command-architecture/error-messages-for-ai-agents.md) has the code.

!!! tip "Match Guidance to Failure"
    Don't show line-limit guidance for readability failures. Irrelevant advice confuses AI agents.

---

## Error Message Templates

Two shapes cover most cases.
A threshold message names the category, the metric with actual and maximum values, the specific fixes, and one prohibited shortcut.
A quality message names the category, what the metric indicates, the improvement strategies, and the prohibited approach with the reason it is wrong.
The [guide](../../build/go-cli-architecture/command-architecture/error-messages-for-ai-agents.md) has both templates.

---

## Testing with AI Agents

Before shipping, test your error messages:

1. Create a file that fails your checks
2. Copy the error message
3. Paste to an AI assistant with the file content
4. Ask it to "fix this error"
5. Verify the fix is correct (not destructive)

!!! warning "The Real Test"
    If an AI agent deletes content instead of restructuring, your error message failed.

---

## The Payoff

Well-designed error messages mean:

- AI agents fix issues correctly on first attempt
- Fewer review cycles for automated fixes
- No accidental content destruction
- Happy developers who trust their tools

The investment in better error messages pays dividends every time an AI agent encounters your CLI. As AI agents become more prevalent in development workflows, this investment compounds.

---

## Related

- [Shipping a GitHub Action the Right Way](2025-12-06-shipping-a-github-action-the-right-way.md) - The action that inspired these patterns
- [The Art of Failing Gracefully](2025-12-05-the-art-of-failing-gracefully.md) - Error handling philosophy
- [Should Work ≠ Does Work](2025-12-08-always-works-qa-methodology.md) - Verify AI fixes actually work
