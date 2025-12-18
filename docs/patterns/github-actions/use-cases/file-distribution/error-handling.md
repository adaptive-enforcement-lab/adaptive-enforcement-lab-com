---
title: Error Handling
description: >-
  Failure strategies for matrix distribution workflows: fail-fast configuration, conditional execution, step outcome handling, and comprehensive error reporting.
---

# Error Handling

!!! warning "Expect Failures"
    Large matrix operations will have failures. Design for visibility: report failures clearly, continue processing others, and make reruns safe.

## Failure Strategies

```yaml
strategy:
  matrix:
    repo: ${{ fromJson(needs.discover.outputs.repositories) }}
  fail-fast: false  # Continue processing other repos on failure
```

## Conditional Execution

```yaml
- name: Operation
  if: steps.previous.outcome == 'success'
  run: |
    # Only runs if previous step succeeded
```

## Error Reporting

```yaml
- name: Report failures
  if: failure()
  run: |
    echo "::error::Distribution failed for ${{ matrix.repo.name }}"
```

## Step Outcome Handling

```yaml
- name: First step
  id: first
  continue-on-error: true
  run: |
    # May fail

- name: Handle failure
  if: steps.first.outcome == 'failure'
  run: |
    echo "First step failed, executing fallback"

- name: Handle success
  if: steps.first.outcome == 'success'
  run: |
    echo "First step succeeded"
```

## Summary Error Reporting

```yaml
summary:
  needs: [discover, distribute]
  if: always()  # Run even if distribute fails
  steps:
    - name: Report status
      run: |
        if [ "${{ needs.distribute.result }}" == "failure" ]; then
          echo "## :warning: Distribution had failures" >> $GITHUB_STEP_SUMMARY
        elif [ "${{ needs.distribute.result }}" == "success" ]; then
          echo "## :white_check_mark: Distribution complete" >> $GITHUB_STEP_SUMMARY
        fi
```

## Error Categories

| Error Type | Handling | Recovery |
| ------------ | ---------- | ---------- |
| Auth failure | Job fails | Check secrets configuration |
| Clone failure | Job fails | Verify repo access |
| Push failure | Job fails | Check branch protection |
| PR creation failure | Job fails | Verify PR permissions |
| Rate limit | Retry with backoff | Reduce parallelism |
