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
| ------ | ------------ | -------- | ------- |
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

### Content Type Validation

**CRITICAL CHECK**: Blog posts vs Articles distinction

For each blog post in the PR:
- Check if it contains workflows, code blocks, or step-by-step instructions
- If YES → FLAG: This should be an article, not a blog post
- Blog posts should tell emotional journeys and link to articles for tactics

For each article in the PR:
- Check if it's in the correct location (developer-guide, operator-manual, sdlc-hardening)
- Check if blog posts link to it for implementation details
- Articles should be matter-of-fact how-to guides

### Content Standards Check

| Standard | Status | Notes |
| ---------- | -------- | ------- |
| **Blog vs Article** | PASS/FLAG | Blog posts must NOT be how-tos |
| Frontmatter complete | PASS/FAIL | missing: X |
| `<!-- more -->` marker | PASS/FAIL/N/A | |
| Description under 160 chars | PASS/FAIL | current: X chars |
| No admonitions above fold | PASS/FAIL | |
| Blog posts link to articles | PASS/FAIL/N/A | Blog posts should reference articles |

### Recommendations

[Specific actionable items for the PR author]
```

## Important Rules

1. **VALIDATE CONTENT TYPE** - Blog posts with workflows/code/how-tos are WRONG. They should be articles. This is the most critical check.
2. **Articles are matter-of-fact** - How-to guides belong in developer-guide, operator-manual, or sdlc-hardening
3. **Blog posts are emotional journeys** - They tell stories and link to articles for implementation
4. **Be precise about category status** - Clearly distinguish existing, planned, and unexpected new categories
5. **Connect to roadmap** - Always check if new content advances roadmap items
6. **Surface closeable issues** - If creating a planned category, find related issues
7. **Validate standards** - Check blog post format requirements from CONTRIBUTING.md
8. **Suggest, don't block** - Provide recommendations, not hard failures
