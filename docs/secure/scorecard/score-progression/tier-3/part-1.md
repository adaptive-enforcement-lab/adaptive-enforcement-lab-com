---
description: >-
  Selective improvements for Scorecard scores 9 to 10. CII badge, fuzzing integration,
  perfect branch protection, and ongoing maintenance. Diminishing returns, evaluate context.
tags:
  - scorecard
  - compliance
  - cii-badge
  - fuzzing
  - maintenance
---

# Tier 3: Score 9 to 10 (Advanced → Exceptional)

Edge cases, community certification, and continuous monitoring. These are high-effort improvements with diminishing returns.

**Estimated effort**: Ongoing maintenance and selective improvements

---

## What You Have at Score 9

- All supply chain protections from Tier 1 and 2
- Job-level permissions scoped correctly
- SLSA Level 3 provenance proving build integrity
- Comprehensive dependency pinning with SHA digests
- Static analysis integrated in CI
- Advanced tooling and review processes

**What's left**: Community certification, fuzzing (selective), perfect branch protection (selective), ongoing maintenance

---

## Priority 1: CII Best Practices Badge (2 to 4 hours)

**Target**: CII-Best-Practices 10/10

**Fix**: Complete OpenSSF Best Practices questionnaire at [bestpractices.coreinfrastructure.org](https://bestpractices.coreinfrastructure.org)

### Key Requirements

Most projects with good CI/CD **already meet these criteria**:

**Project Basics**:
- ✅ Public version control (GitHub)
- ✅ Change history (git log)
- ✅ Unique version numbers (releases with tags)
- ✅ Release notes (CHANGELOG.md or GitHub releases)

**Quality**:
- ✅ Automated test suite (CI with tests)
- ✅ High test coverage (95%+)
- ✅ Warning-free builds
- ✅ Reproducible builds

**Security**:
- ✅ Security policy (SECURITY.md from Tier 1)
- ✅ Static analysis (SAST from Tier 2)
- ✅ Dependency scanning (Renovate/Dependabot from Tier 1)
- ✅ Known vulnerabilities addressed

**Documentation**:
- ✅ README with purpose, installation, usage
- ✅ LICENSE file
- ✅ Contribution guidelines (CONTRIBUTING.md)
- ✅ Code of conduct (CODE_OF_CONDUCT.md)

### The Badge Is Documentation, Not Implementation

If you've completed Tier 1 and 2, **you already have the practices**. The badge questionnaire is documentation.

### Fast-Track Process

1. **Sign up** at [bestpractices.coreinfrastructure.org](https://bestpractices.coreinfrastructure.org)
2. **Start questionnaire** for your repository
3. **Answer questions** - most are "yes" with links to proof
4. **Submit for review** - usually approved within 24 hours
5. **Add badge** to README

**Time investment**: 2 to 4 hours of form-filling.

**Real-world guide**: [OpenSSF Best Practices Badge in 2 Hours](../../../blog/posts/2025-12-17-openssf-badge-two-hours.md)

**Impact**: Community certification of security practices. Shows commitment to security best practices.

---

## Priority 2: Fuzzing (8+ hours)

**Target**: Fuzzing 10/10

**Fix**: Integrate fuzzing for input handling code.

**Critical evaluation**: High implementation cost. Evaluate value before committing.

### When to Prioritize Fuzzing

**✅ Implement fuzzing for**:
- Parsers (JSON, XML, YAML, Markdown, protocol buffers)
- Cryptographic code (encryption, signing, verification)
- Network protocol handlers (HTTP, WebSocket, custom protocols)
- Compression/decompression routines
- Image/video/audio processing
- Serialization/deserialization logic

**❌ Skip fuzzing for**:
- Simple CRUD applications
- CLI tools with validated input
- Internal tools with trusted input only
- Projects with no complex input parsing

### OSS-Fuzz Integration (Recommended for Public Projects)

Create `.github/workflows/fuzz.yml`:

```yaml
name: Fuzzing

on:
  push:
    branches: [main]
  pull_request:

jobs:
  fuzz:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4

      - uses: google/oss-fuzz/infra/cifuzz/actions/build_fuzzers@master
        with:
          language: go  # or: python, rust, java, c, c++

      - uses: google/oss-fuzz/infra/cifuzz/actions/run_fuzzers@master
        with:
          fuzz-seconds: 600
```

### Manual Fuzzing with Go

```go
// fuzz_test.go
package parser

import "testing"

func FuzzParse(f *testing.F) {
    // Seed corpus
    f.Add([]byte("valid input"))
    f.Add([]byte("edge case"))

    f.Fuzz(func(t *testing.T, data []byte) {
        // Parse should not panic on any input
        _, _ = Parse(data)
    })
}
```

Run with: `go test -fuzz=FuzzParse -fuzztime=30s`

### Continuous Fuzzing with OSS-Fuzz (Full Integration)

Apply to [OSS-Fuzz project](https://github.com/google/oss-fuzz):

- Continuous fuzzing on Google infrastructure
- Automated issue filing for crashes
- Coverage reports
- Free for open source projects

**Setup time**: 1 to 2 days for initial integration.

**Ongoing**: Triage and fix findings.

### Trade-offs

**Benefits**:
- Finds edge cases human testing misses
- Continuous security testing
- Industry best practice for security-critical code

**Costs**:
- High implementation effort (8+ hours minimum)
- Ongoing maintenance (triaging findings)
- May find issues in dependencies you can't fix

**Decision**: Evaluate based on project risk profile.

**Impact**: High for security-critical code. Low for simple applications.

---

## Priority 3: Perfect Branch Protection (Variable)

**Target**: Branch-Protection 9/10 → 10/10

**Fix**: Enable strictest protections in repository settings.

**Critical evaluation**: May not fit all team contexts. Evaluate carefully.

### Remaining Gaps for 10/10

**Settings → Branches → Branch protection rules → main**:

- ✅ **Require signed commits**
  - All commits must be GPG/SSH signed
  - Proves commit author identity

- ✅ **Restrict who can push to matching branches**
  - Only specific users/teams can push
  - Prevents unauthorized access

- ✅ **Do not allow bypassing the above settings** (including administrators)
  - Applies to all users, no exceptions
  - Maximum enforcement

- ✅ **Restrict force pushes** (no one, not even admins)
  - Prevents history rewriting
  - Protects against malicious changes

### Trade-offs

**Signed commits**:
- **Pro**: Cryptographic proof of author identity
- **Con**: All contributors need GPG keys configured
- **Con**: CI commits need signing setup
- **Effort**: 1 to 2 hours per contributor for initial setup

**Admin bypass disabled**:
- **Pro**: Maximum security, no exceptions
- **Con**: Blocks emergency fixes in crisis situations
- **Con**: May slow incident response

**Force push restrictions**:
- **Pro**: Protects git history from rewriting
- **Con**: Complicates history cleanup
- **Con**: May need workarounds for large refactors

### When to Implement

**✅ Implement for**:
- Large teams (5+ contributors)
- Public projects with external contributors
- High-security contexts (cryptography, authentication, infrastructure)
- Regulated industries (finance, healthcare)

**❌ Skip for**:
- Solo maintainer projects
- Small teams (2 to 3 people) with trusted members
- Internal tools with limited access
- Prototypes and experimental projects

### Documentation for Exceptions

If you choose not to implement, document the decision:

```markdown
<!-- In SECURITY.md or contributing guidelines -->

## Branch Protection Exceptions

**Signed commits**: Not required. Team size is 2 people, both trusted.
All commits are reviewed through PR process.

**Admin bypass**: Enabled for emergency hotfixes. Admin access is limited
to 2 team leads. All admin pushes are logged and reviewed.
```

**Impact**: Maximum security for high-risk projects. Overkill for small teams or low-risk contexts.

---
