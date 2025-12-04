# AEL Content Review

You are reviewing content changes in a pull request for category alignment and content standards compliance.

## Context Gathering

### 1. Get PR Changes

Use `gh api` to fetch the PR details and changed files:

```bash
# Get PR details (replace PR_NUMBER with actual number from $ARGUMENTS or current branch)
gh api repos/{owner}/{repo}/pulls/PR_NUMBER --jq '{title, body, head: .head.ref, base: .base.ref}'

# Get changed files
gh api repos/{owner}/{repo}/pulls/PR_NUMBER/files --jq '.[] | {filename, status, additions, deletions}'
```

If no PR number provided, check if current branch has an open PR:

```bash
gh pr view --json number,title,body,files
```

### 2. Read Changed Content Files

For each changed file under `docs/`:

- Use Read tool to get the full content
- Extract frontmatter (especially `categories`)
- Note the content type (blog post, guide, manual page)

### 3. Get Existing Categories

Scan existing content to build category inventory:

```bash
# Extract all categories currently in use
grep -rh "^categories:" docs/blog/posts/ -A 10 | grep "^  - " | sort | uniq
```

Also read `mkdocs.yml` for any defined category structure.

### 4. Get Planned Categories

Read `docs/roadmap.md` to identify planned but not-yet-created categories or content areas.

### 5. Check Related Issues

```bash
# Find issues related to categories or content structure
gh api repos/{owner}/{repo}/issues --jq '.[] | select(.pull_request == null) | select(.title | test("category|content|blog|documentation"; "i")) | {number, title, body}'
```

## Validation Framework

### Category Alignment Check

For each content file in the PR:

1. **Extract categories from frontmatter**
2. **Compare against existing categories**:
   - If all categories exist → PASS
   - If category is new but not planned → FLAG for review
   - If category matches planned content → TRIGGER category creation

### Planned Category Detection

When a PR introduces content that matches a roadmap item:

1. **Identify the roadmap alignment**
2. **Check if category infrastructure exists** (nav entries, index pages)
3. **Recommend category creation steps**:
   - Update `mkdocs.yml` navigation
   - Create category index page if needed
   - Update roadmap to mark item as complete
4. **Find closeable issues** related to this category

## Output Format

```markdown
## Content Review Report

### PR Summary
- **PR**: #NUMBER - TITLE
- **Branch**: BRANCH_NAME
- **Content Files Changed**: COUNT

### Category Validation

| File | Categories | Status | Notes |
|------|------------|--------|-------|
| path/to/file.md | [cat1, cat2] | PASS/FLAG/NEW | details |

### Existing Category Alignment
[List any mismatches or suggestions for existing categories]

### New Category Detection

**Planned Category Ready for Creation**: CATEGORY_NAME

This PR introduces content that matches roadmap item: "ROADMAP_ITEM"

**Required Actions**:
1. [ ] Add navigation entry to `mkdocs.yml`
2. [ ] Create `docs/CATEGORY/index.md` if needed
3. [ ] Update `docs/roadmap.md` to mark complete

**Related Issues to Close**:
- #NUMBER - ISSUE_TITLE

### Content Standards Check

| Standard | Status | Notes |
|----------|--------|-------|
| Frontmatter complete | PASS/FAIL | missing: X |
| `<!-- more -->` marker | PASS/FAIL/N/A | |
| Description under 160 chars | PASS/FAIL | current: X chars |
| No admonitions above fold | PASS/FAIL | |

### Recommendations

[Specific actionable items for the PR author]
```

## Important Rules

1. **Be precise about category status** - Clearly distinguish existing, planned, and unexpected new categories
2. **Connect to roadmap** - Always check if new content advances roadmap items
3. **Surface closeable issues** - If creating a planned category, find related issues
4. **Validate standards** - Check blog post format requirements from CONTRIBUTING.md
5. **Suggest, don't block** - Provide recommendations, not hard failures
