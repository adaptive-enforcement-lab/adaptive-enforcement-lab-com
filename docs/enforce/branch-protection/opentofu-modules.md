---
title: OpenTofu Modules
description: >-
  OpenTofu module patterns for managing branch protection rules at scale.
  Open-source alternative with identical module structure.
tags:
  - github
  - security
  - opentofu
  - infrastructure-as-code
  - automation
  - operators
  - policy-enforcement
---

# OpenTofu Modules

Open-source infrastructure as code. Drop-in replacement for Terraform. Module patterns identical.

!!! tip "OpenTofu Compatibility"
    OpenTofu is a fork of Terraform with identical HCL syntax and provider ecosystem. Existing Terraform modules work without modification. State file format is compatible.

Branch protection declared in code. Version controlled. Auditable. Repeatable.

---

## Why OpenTofu

**Open source forever**: Linux Foundation governance. MPL 2.0 license. Community-driven.

**No vendor lock-in**: Compatible with Terraform providers. State encryption built-in.

**Drop-in replacement**: Existing `.tf` files work. State migration automated.

**Enterprise features included**: State encryption. Early variable evaluation. No paid tier.

---

## Installation

```bash
# macOS (Homebrew)
brew install opentofu

# Ubuntu/Debian
curl -fsSL https://get.opentofu.org/install-opentofu.sh | sh

# Verify
tofu version
```

---

## GitHub Provider Setup

Identical to Terraform configuration. Replace `terraform` with `tofu` command.

```hcl
# versions.tf
terraform {
  required_version = ">= 1.6"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }

  backend "gcs" {
    bucket = "my-org-tofu-state"
    prefix = "github/branch-protection"
  }
}

provider "github" {
  owner = "my-org"

  app_auth {
    id              = var.github_app_id
    installation_id = var.github_app_installation_id
    pem_file        = var.github_app_pem_file
  }
}
```

**Authentication**: Use GitHub App for production. See [GitHub Apps](../../secure/github-apps/index.md).

---

## Basic Module

Module structure identical to Terraform.

```hcl
# modules/branch-protection/main.tf
resource "github_branch_protection" "main" {
  repository_id = var.repository_name
  pattern       = var.branch_pattern

  required_pull_request_reviews {
    required_approving_review_count = var.required_reviewers
    dismiss_stale_reviews           = var.dismiss_stale_reviews
    require_code_owner_reviews      = var.require_code_owner_reviews
  }

  required_status_checks {
    strict   = var.strict_status_checks
    contexts = var.required_status_checks
  }

  enforce_admins          = var.enforce_admins
  require_signed_commits  = var.require_signed_commits
  required_linear_history = var.required_linear_history
  allow_force_pushes      = false
  allow_deletions         = false
}
```

### Key Variables

```hcl
# modules/branch-protection/variables.tf
variable "repository_name" {
  description = "Repository name"
  type        = string
}

variable "required_reviewers" {
  description = "Number of required approving reviews"
  type        = number
  default     = 1
}

variable "enforce_admins" {
  description = "Enforce rules for administrators"
  type        = bool
  default     = false
}

variable "required_status_checks" {
  description = "Status check contexts that must pass"
  type        = list(string)
  default     = []
}
```

---

## Security Tier Modules

Pre-configured modules matching tier templates. See **[Security Tiers](security-tiers.md)**.

### Standard Tier

```hcl
# modules/branch-protection-standard/main.tf
module "standard_protection" {
  source = "../branch-protection"

  repository_name        = var.repository_name
  required_reviewers     = 1
  enforce_admins         = false
  required_status_checks = ["ci/tests", "lint/code-quality"]
}
```

### Enhanced Tier

```hcl
# modules/branch-protection-enhanced/main.tf
module "enhanced_protection" {
  source = "../branch-protection"

  repository_name            = var.repository_name
  required_reviewers         = 2
  enforce_admins             = true
  require_code_owner_reviews = true
  required_status_checks     = [
    "ci/tests",
    "security/sast",
    "security/dependency-scan"
  ]
}
```

### Maximum Tier

```hcl
# modules/branch-protection-maximum/main.tf
module "maximum_protection" {
  source = "../branch-protection"

  repository_name            = var.repository_name
  required_reviewers         = 2
  enforce_admins             = true
  require_code_owner_reviews = true
  require_signed_commits     = true
  required_status_checks     = [
    "ci/tests",
    "security/sast",
    "security/container-scan",
    "compliance/license-check"
  ]
}
```

### Usage

```hcl
# Enhanced tier for production API
module "api_service" {
  source          = "./modules/branch-protection-enhanced"
  repository_name = "api-service"
}

# Maximum tier for auth service
module "auth_service" {
  source          = "./modules/branch-protection-maximum"
  repository_name = "auth-service"
}
```

---

## OpenTofu-Specific Features

### Built-in State Encryption

```hcl
# encryption.tf - No enterprise license required
terraform {
  encryption {
    key_provider "pbkdf2" "main" {
      passphrase = var.encryption_passphrase
    }
    method "aes_gcm" "state" {
      keys = key_provider.pbkdf2.main
    }
    state {
      method = method.aes_gcm.state
    }
  }
}
```

**Benefit**: Protect sensitive metadata (team IDs, org structure) in state files.

---

## Workflow

### Commands

```bash
# Initialize
tofu init

# Plan
tofu plan

# Apply
tofu apply

# Detect drift
tofu plan

# Show state
tofu show
```

### Import Existing Protection

```bash
# Inspect current protection
gh api repos/my-org/api-service/branches/main/protection > current.json

# Import into state
tofu import 'module.api_service.github_branch_protection.main' \
  'api-service:main'

# Verify
tofu plan
```

---

## Verification

### Check Plan

```bash
tofu plan

# Example drift:
# ~ enforce_admins = true -> false
```

### Manual Check

```bash
gh api repos/my-org/api-service/branches/main/protection \
  --jq '{
    enforce_admins: .enforce_admins.enabled,
    required_reviews: .required_pull_request_reviews.required_approving_review_count
  }'
```

---

## Troubleshooting

**Command not found**: Run `brew install opentofu`.

**Repository not found**: Use `repository_name = "api-service"` (no org prefix).

**Backend initialization required**: Run `tofu init -migrate-state`.

See **[Troubleshooting](troubleshooting.md)** for more issues.

---

## Best Practices

**1. Enable state encryption**: Use built-in encryption for sensitive metadata.

**2. Use tier modules**: Pre-configured modules reduce duplication.

**3. Require code review**: Add `/opentofu/**` to CODEOWNERS.

**4. Pin OpenTofu version**: Set `required_version = "~> 1.6.0"` in `versions.tf`.

**5. Version control**: Store all `.tf` files in Git with protection rules.

---

## Multi-Repository Patterns

For organization-wide enforcement across 100+ repositories, see **[Multi-Repo Management](multi-repo-management.md)**.

---

## Related Patterns

- **[Security Tiers](security-tiers.md)** - Pre-configured tier templates
- **[Multi-Repo Management](multi-repo-management.md)** - Organization-wide enforcement
- **[Drift Detection](drift-detection.md)** - Automated monitoring
- **[GitHub Apps Setup](../../secure/github-apps/index.md)** - Authentication

---

## Next Steps

1. Install OpenTofu and verify compatibility
2. Import existing protection to establish baseline
3. Enable state encryption for production
4. Refactor to tier modules for consistency
5. Configure drift detection for compliance

For organization-wide patterns, see **[Multi-Repo Management](multi-repo-management.md)**.

---

*The code was declared open. The license was clear. The state was encrypted. The protection was versioned. Vendor lock-in became impossible.*
