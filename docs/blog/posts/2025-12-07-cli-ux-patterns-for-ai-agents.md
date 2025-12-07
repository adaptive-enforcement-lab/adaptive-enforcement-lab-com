---
date: 2025-12-07
authors:
  - mark
categories:
  - DevSecOps
  - Automation
  - Go
description: >-
  AI agents take error messages literally. Design CLI output that guides
  correct fixes, not destructive shortcuts.
slug: cli-ux-patterns-for-ai-agents
---

# Designing Error Messages AI Agents Can't Misinterpret

AI coding assistants are increasingly the first responders to pre-commit failures and CI errors. The error messages your CLI produces directly influence how these agents attempt fixes—often without human review.

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

```go
// Bad: Only describes the problem
fmt.Fprintln(os.Stderr, "Error: Readability score too low")

// Good: Describes problem AND solution approach
fmt.Fprintln(os.Stderr, "READABILITY: High grade level indicates complex sentences.")
fmt.Fprintln(os.Stderr, "- Break long sentences into shorter ones (15-20 words)")
fmt.Fprintln(os.Stderr, "- Add introductory sentences before code blocks")
```

### 2. Explicitly State What NOT TO DO

AI agents optimize for speed. Prohibit destructive shortcuts:

```go
fmt.Fprintln(os.Stderr, "Do NOT remove content to meet thresholds.")
fmt.Fprintln(os.Stderr, "Do NOT remove technical accuracy. Rewrite for clarity.")
```

### 3. Provide Specific, Actionable Guidance

Vague instructions produce vague fixes:

```go
// Bad: Vague
fmt.Fprintln(os.Stderr, "Improve the readability of this document.")

// Good: Specific actions
fmt.Fprintln(os.Stderr, "- Break sentences over 20 words into multiple sentences")
fmt.Fprintln(os.Stderr, "- Add brief explanations before bullet lists")
fmt.Fprintln(os.Stderr, "- Use transitional phrases between dense sections")
```

---

## Implementation: Contextual Warnings

Show different guidance based on failure type:

```go
func run() error {
    // Analyze files...

    if checkFlag && failed > 0 {
        tooLong := countFilesExceedingLines(results, 375)
        lowReadability := countLowReadability(results)

        if tooLong > 0 {
            fmt.Fprintln(os.Stderr, "")
            fmt.Fprintln(os.Stderr, "IMPORTANT: Files exceeding line limits should be SPLIT.")
            fmt.Fprintln(os.Stderr, "Do NOT remove content. Split by topic or section.")
            fmt.Fprintln(os.Stderr, "")
        }

        if lowReadability > 0 {
            fmt.Fprintln(os.Stderr, "")
            fmt.Fprintln(os.Stderr, "READABILITY: Complex sentence structure detected.")
            fmt.Fprintln(os.Stderr, "- Break long sentences (aim for 15-20 words)")
            fmt.Fprintln(os.Stderr, "- Add context before code blocks and lists")
            fmt.Fprintln(os.Stderr, "Do NOT remove technical content.")
            fmt.Fprintln(os.Stderr, "")
        }

        return fmt.Errorf("%d file(s) failed", failed)
    }
    return nil
}
```

!!! tip "Match Guidance to Failure"
    Don't show line-limit guidance for readability failures. Irrelevant advice confuses AI agents.

---

## Error Message Templates

### Threshold Exceeded

```text
[CATEGORY]: [Metric] exceeds threshold ([actual] > [max]).

To fix:
- [Specific action 1]
- [Specific action 2]

Do NOT [prohibited shortcut].
```

### Quality Issue

```text
[CATEGORY]: [What the metric indicates].

Improvement strategies:
- [Strategy 1]
- [Strategy 2]

Do NOT [prohibited approach]. [Why it's wrong].
```

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

The investment in better error messages pays dividends every time an AI agent encounters your CLI—which is increasingly often.

---

## Related

- [Shipping a GitHub Action the Right Way](2025-12-06-shipping-a-github-action-the-right-way.md) - The action that inspired these patterns
- [The Art of Failing Gracefully](2025-12-05-the-art-of-failing-gracefully.md) - Error handling philosophy
- [Should Work ≠ Does Work](2025-12-08-always-works-qa-methodology.md) - Verify AI fixes actually work
