---
title: Performance
description: >-
  Parallel processing and rate limit management.
---

# Performance Optimization

## Parallel Processing

```yaml
strategy:
  matrix:
    repo: ${{ fromJson(needs.discover.outputs.repositories) }}
  max-parallel: 10  # Process 10 repositories concurrently
```

### Tuning Guidelines

- Start with `max-parallel: 10`
- Monitor rate limit headers
- Reduce if hitting rate limits
- Increase for smaller organizations

## Rate Limit Management

```bash
# Check rate limits before operations
RATE_LIMIT=$(gh api /rate_limit --jq '.resources.core.remaining')
if [ "$RATE_LIMIT" -lt 100 ]; then
  echo "WARNING: Rate limit low ($RATE_LIMIT remaining)"
  sleep 60
fi
```

## Rate Limit Tiers

| Tier | Requests/Hour | Typical Use Case |
|------|---------------|------------------|
| Unauthenticated | 60 | Not recommended |
| User PAT | 5,000 | Small orgs |
| GitHub App | 5,000 per installation | Enterprise |
| GitHub App (org-wide) | 15,000+ | Large orgs |

## Optimization Strategies

### Token Reuse

Generate token once, reuse across steps:

```yaml
- name: Generate token once
  id: auth
  uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.CORE_APP_ID }}
    private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
    owner: your-org

- name: Operation 1
  env:
    GH_TOKEN: ${{ steps.auth.outputs.token }}
  run: # ...

- name: Operation 2
  env:
    GH_TOKEN: ${{ steps.auth.outputs.token }}
  run: # ...
```

### Shallow Clones

Reduce clone time with shallow clones:

```bash
gh repo clone your-org/${{ matrix.repo.name }} target -- --depth 1
```

### Conditional Processing

Skip repos that don't need updates:

```yaml
- name: Check if update needed
  id: check
  run: |
    # Compare file hashes before cloning
    REMOTE_HASH=$(gh api repos/your-org/${{ matrix.repo.name }}/contents/file.txt --jq '.sha')
    LOCAL_HASH=$(sha1sum source-file.txt | cut -d' ' -f1)
    if [ "$REMOTE_HASH" == "$LOCAL_HASH" ]; then
      echo "skip=true" >> $GITHUB_OUTPUT
    fi
```
