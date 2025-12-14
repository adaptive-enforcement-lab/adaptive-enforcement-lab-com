---
date: 2025-12-08
authors:
  - mark
categories:
  - QA
  - Testing
  - Developer Workflow
description: >-
  Pattern matching isn't verification. Build a habit of running code,
  not just reading it.
slug: always-works-qa-methodology
---

# Should Work ≠ Does Work: The Always Works Methodology

"The code looks correct" is not the same as "I ran the code and it works."

This distinction costs engineering teams hours every week. Failed CI runs. Broken deployments. Embarrassing rollbacks. All because someone pattern-matched instead of verified.

Here's a framework for building verification into your workflow.

<!-- more -->

## The Problem with "It Should Work"

Common anti-patterns that lead to broken pushes:

1. **Optimistic Completion**: Marking tasks done based on code written, not functionality verified
2. **Pattern-Matching Confidence**: "The code looks correct, so it must work"
3. **Partial Testing**: Testing one path but not edge cases
4. **Assumption Chains**: "If A works and B looks similar to A, B must work"
5. **Deferred Verification**: "I'll test it after I finish this other thing"

!!! danger "The Real Cost"
    Each failed CI push wastes 30+ seconds of pipeline time, minutes of context-switching, and a small amount of credibility with your team.

---

## The 30-Second Reality Check

Before declaring any task complete, answer YES to all:

| Question | Verification Method |
| ---------- | --------------------- |
| Did I run/build the code? | `go build ./...` succeeded |
| Did I trigger the exact feature I changed? | Ran the specific command |
| Did I see the expected result? | Observed output, not assumed |
| Did I check for error messages? | Checked stderr, exit codes |
| Would I bet $100 this works? | Gut check on confidence |

If any answer is NO or uncertain, you're not done.

---

## The Embarrassment Test

> "If someone records trying this and it fails, will I feel embarrassed?"

This test catches the gap between "probably works" and "definitely works."

---

## Time Economics

| Action | Time Cost |
| -------- | ----------- |
| Running tests before push | 30 seconds |
| Investigating CI failure | 5 minutes |
| Second round of fixes | 10 minutes |
| Team frustration | Immeasurable |

The math is clear: always verify locally.

!!! tip "The Rule"
    CI should confirm, not discover. Failures should be rare surprises, not routine occurrences.

---

## Verification Chains by Change Type

### Code Logic Changes

```bash
# 1. Build
go build ./...

# 2. Run unit tests
go test ./...

# 3. Run the specific scenario
./my-tool --flag-i-changed input.txt

# 4. Verify output matches expectations
# (Actually read the output, don't assume)
```

### CLI Flag Changes

```bash
# 1. Build
go build ./...

# 2. Test the new flag
./my-tool --new-flag value

# 3. Test flag interactions
./my-tool --new-flag value --existing-flag

# 4. Test help output
./my-tool --help | grep new-flag

# 5. Test invalid input
./my-tool --new-flag invalid-value
```

### CI/CD Pipeline Changes

```bash
# 1. Lint the workflow file
actionlint .github/workflows/my-workflow.yml

# 2. Validate YAML syntax
yamllint .github/workflows/my-workflow.yml

# 3. Create a test branch and push
git checkout -b test-workflow
git push origin test-workflow

# 4. Watch CI run, don't assume
gh run view <run-id> --log
```

---

## Phrases to Avoid vs. Use

| Avoid | Replace With |
| ------- | -------------- |
| "This should work now" | "I verified this works by running..." |
| "I've fixed the issue" | "All tests pass after..." |
| "Try it now" | "I tested [scenario] and observed..." |
| "The logic is correct" | "The output shows..." |

---

## Multi-Step Verification Checklist

For complex changes, create explicit checklists:

```markdown
## Verification Checklist

- [ ] Code compiles: `go build ./...`
- [ ] Linter passes: `golangci-lint run ./...`
- [ ] Warning appears for failure case:
  - Create failing input
  - Run tool with `--check`
  - Observe expected warning message
- [ ] No warnings for passing case:
  - Run tool on valid input
  - Observe no warnings
- [ ] Exit codes correct:
  - Failure returns exit 1
  - Success returns exit 0
```

---

## Pre-commit Hooks as Enforcement

Install verification as a habit:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: go-build
        name: go build
        entry: go build ./...
        language: system
        pass_filenames: false

      - id: go-lint
        name: golangci-lint
        entry: golangci-lint run
        language: system
        pass_filenames: false
```

Now verification happens automatically. No discipline required.

!!! success "Automation Over Willpower"
    Don't rely on remembering to verify. Automate it so forgetting isn't an option.

---

## The "But I Just Changed One Line" Trap

Small changes can have large impacts:

- Import statement added → Build fails if unused
- Condition flipped → Logic inverts
- Type changed → Callers break

Always run full verification regardless of change size.

---

## Metrics: Track Your Hit Rate

For every PR:

1. Did CI pass on first push?
2. If not, what was missed?
3. How can verification be improved?

**Goal**: 100% first-push CI success rate. Every failure is a process improvement opportunity.

---

## The Complete Workflow

### Before Starting

1. Understand the requirement fully
2. Identify what needs to change
3. Plan verification steps

### During Development

1. Make changes incrementally
2. Verify each increment locally
3. Don't accumulate unverified changes

### Before Committing

1. Run full build
2. Run linter
3. Run tests
4. Manually test changed functionality

### After Pushing

1. Watch CI status
2. If failure: understand why local verification missed it
3. Update process to prevent recurrence

---

## Conclusion

The Always Works methodology isn't about distrust in your code. It's about respecting the complexity of software systems and the gap between intention and execution.

The 30 seconds spent verifying saves 30 minutes debugging failed CI. More importantly, it maintains trust with teammates who expect working code, not "should work" code.

---

## Related

- [The Art of Failing Gracefully](2025-12-05-the-art-of-failing-gracefully.md) - Handle failures elegantly when they happen
- [CLI UX Patterns for AI Agents](2025-12-07-cli-ux-patterns-for-ai-agents.md) - Verify AI fixes with the same rigor
- [Building GitHub Actions in Go](2025-12-09-building-github-actions-in-go.md) - Apply verification to action development
- [Prerequisite Checks](../../developer-guide/error-handling/prerequisite-checks/index.md) - Fail fast when prerequisites aren't met
