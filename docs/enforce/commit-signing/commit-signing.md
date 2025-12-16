---
title: Commit Signing
description: >-
  GPG signatures for non-repudiation. Cryptographic proof of authorship
  that prevents commit forgery and satisfies audit requirements.
tags:
  - security
  - git
  - gpg
  - compliance
  - developers
  - commit-signing
---

# Commit Signing

Who actually authored this commit? Can they deny it?

!!! warning "Security Foundation"
    These controls form the baseline security posture. All controls must be implemented for audit compliance.

Git's author field is trivial to forge. GPG signatures provide cryptographic proof.

## The Problem: Unsigned Commits

```bash
$ git log --pretty=format:"%h %an %s"
abc123d Mark Cheret Add feature
```

Anyone can set `user.name` to "Mark Cheret." This proves nothing.

```bash
$ git config user.name "Mark Cheret"
$ git config user.email "mark@example.com"
$ git commit -m "Malicious code"
# Commit appears from Mark, but Mark didn't write it
```

Auditors need non-repudiation. Unsigned commits don't provide it.

## The Solution: GPG Signatures

```bash
$ git log --show-signature
commit abc123d (HEAD -> main)
gpg: Signature made Thu Dec 12 10:23:45 2025 PST
gpg: using RSA key ABCD1234
gpg: Good signature from "Mark Cheret <mark@example.com>"
Author: Mark Cheret <mark@example.com>
```

The commit is cryptographically signed with Mark's private key. Mark can't deny authorship. Forging requires stealing the private key.

## Setup: GPG Key Generation

```bash
# Generate GPG key
gpg --full-generate-key

# Select:
# - RSA and RSA
# - 4096 bits
# - Does not expire (or 2 years)
# - Enter name and email matching Git config

# List keys
gpg --list-secret-keys --keyid-format=long

# Output:
# sec   rsa4096/ABCD1234EF567890 2025-01-01 [SC]
# uid   Mark Cheret <mark@example.com>
```

Key ID is `ABCD1234EF567890`.

## Configure Git to Sign

```bash
# Tell Git which key to use
git config --global user.signingkey ABCD1234EF567890

# Sign all commits automatically
git config --global commit.gpgsign true

# Sign all tags automatically
git config --global tag.gpgsign true
```

Now every commit and tag is signed automatically.

## Add Public Key to GitHub

```bash
# Export public key
gpg --armor --export ABCD1234EF567890

# Output:
# -----BEGIN PGP PUBLIC KEY BLOCK-----
# ...
# -----END PGP PUBLIC KEY BLOCK-----
```

Add to GitHub: Settings → SSH and GPG keys → New GPG key

GitHub will verify signatures and show "Verified" badge on commits.

## Enforce Signed Commits

GitHub branch protection can require signatures:

```yaml
# Branch protection setting
required_signatures: true
```

Unsigned commits cannot be pushed to protected branches.

## Verify Signatures Locally

```bash
# Verify specific commit
git verify-commit abc123d

# Verify tag
git verify-tag v1.0.0

# Show signatures in log
git log --show-signature
```

Output shows "Good signature" or "Bad signature."

## Automatic Signing in CI/CD

GitHub Actions can sign commits and tags:

```yaml
- name: Import GPG key
  uses: crazy-max/ghaction-import-gpg@v6
  with:
    gpg_private_key: ${{ secrets.GPG_PRIVATE_KEY }}
    passphrase: ${{ secrets.GPG_PASSPHRASE }}
    git_user_signingkey: true
    git_commit_gpgsign: true

- name: Create signed tag
  run: |
    git tag -s v1.0.0 -m "Release v1.0.0"
    git push origin v1.0.0
```

Store GPG private key in GitHub secrets (encrypted).

## Key Rotation

When key is compromised or expires:

```bash
# Generate new key
gpg --full-generate-key

# Update Git config
git config --global user.signingkey NEW_KEY_ID

# Add new public key to GitHub

# Revoke old key
gpg --gen-revoke OLD_KEY_ID > revocation.asc
gpg --import revocation.asc
gpg --send-keys OLD_KEY_ID  # Publish revocation
```

Old commits remain signed with old key. New commits use new key.

## Audit Evidence

Signed commits provide:

- **Authenticity**: Cryptographic proof of author identity
- **Non-repudiation**: Author cannot deny writing the code
- **Integrity**: Commit content hasn't been altered

Auditors can verify historical signatures:

```bash
# Verify all commits in March 2025
git log --since="2025-03-01" --until="2025-04-01" \
  --show-signature --oneline
```

Output shows which commits were signed and which weren't.

## Common Issues

### Issue 1: "gpg: signing failed: Inappropriate ioctl for device"

Solution:

```bash
export GPG_TTY=$(tty)
echo 'export GPG_TTY=$(tty)' >> ~/.bashrc
```

### Issue 2: "error: cannot run gpg: No such file or directory"

Install GPG:

```bash
# macOS
brew install gnupg

# Ubuntu
sudo apt-get install gnupg
```

### Issue 3: Passphrase prompt on every commit

Use GPG agent to cache passphrase:

```bash
# Configure GPG agent
echo 'use-agent' >> ~/.gnupg/gpg.conf
echo 'default-cache-ttl 3600' >> ~/.gnupg/gpg-agent.conf
gpg-connect-agent reloadagent /bye
```

## Organization-Wide Enforcement

Require signed commits across all repositories:

```bash
# Enable via GitHub API for all repos
REPOS=$(gh api orgs/my-org/repos --paginate --jq '.[].name')

for repo in $REPOS; do
  gh api --method PUT \
    repos/my-org/$repo/branches/main/protection \
    --field required_signatures=true
done
```

## Verification Script

Audit preparation: Check signature coverage.

```bash
#!/bin/bash
# check-signatures.sh

TOTAL=$(git rev-list --count main)
SIGNED=$(git log --show-signature main 2>&1 | grep -c "Good signature")

echo "Total commits: $TOTAL"
echo "Signed commits: $SIGNED"
echo "Coverage: $(($SIGNED * 100 / $TOTAL))%"
```

Target: 100% signed commits on production branches.

## Related Patterns

- **[Branch Protection](../branch-protection/branch-protection.md)** - Enforce signature requirement
- **[Audit Evidence](../audit-compliance/audit-evidence.md)** - Historical verification

*Commits were signed with private keys. GitHub verified the signatures. Authorship was cryptographically proven. Non-repudiation achieved.*
