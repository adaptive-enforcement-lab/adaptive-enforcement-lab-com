# Workflow Integration

Integrate policy validation into daily development workflows with pre-commit hooks, Make targets, and CI comparison.

## Overview

Policy validation works best when automatic:

- **Pre-commit hooks** - Validate before every commit
- **Make targets** - One command for all validations
- **Local/CI parity** - Identical commands, identical results

---

## Pre-commit Hook

Validate before every commit:

**.pre-commit-config.yaml**:

```yaml
repos:
  - repo: local
    hooks:
      - id: kyverno-validate
        name: Kyverno Policy Validation
        entry: docker run --rm -v $(pwd):/workspace policy-platform:latest
        args:
          - kyverno
          - apply
          - /repos/security-policy/
          - --resource
          - /workspace/manifests/
        language: system
        pass_filenames: false
```

!!! warning "Every Commit is Policy-Checked"
    Pre-commit hooks block commits that violate policies. This prevents policy violations from ever reaching CI or production.

---

## Make Targets

Add to Makefile:

```makefile
.PHONY: validate-policies
validate-policies:
 @echo "Rendering manifests..."
 docker run --rm -v $(PWD):/workspace policy-platform:latest \
   helm template app /workspace/charts/app \
     -f /workspace/charts/app/values.yaml \
     -f /workspace/cd/dev/values.yaml \
   > dev-manifests.yaml
 @echo "Validating policies..."
 docker run --rm -v $(PWD):/workspace policy-platform:latest \
   kyverno apply /repos/security-policy/ \
     --resource /workspace/dev-manifests.yaml

.PHONY: validate-all-envs
validate-all-envs:
 @for env in dev qac stg prd; do \
   $(MAKE) validate-env ENV=$$env; \
 done

.PHONY: validate-env
validate-env:
 docker run --rm -v $(PWD):/workspace policy-platform:latest \
   bash -c '\
     helm template app /workspace/charts/app \
       -f /workspace/charts/app/values.yaml \
       -f /workspace/cd/$(ENV)/values.yaml \
     | kyverno apply /repos/security-policy/ --resource -'
```

**Usage**:

```bash
make validate-policies        # Dev environment
make validate-env ENV=stg     # Specific environment
make validate-all-envs        # All environments
```

!!! tip "Make Targets for Team Consistency"
    Makefile targets ensure everyone on the team runs identical validation commands. No room for variation or shortcuts.

---

## Comparing Local vs CI Output

**Local** (instant feedback):

```bash
$ docker run --rm -v $(pwd):/workspace policy-platform:latest \
  kyverno apply /repos/security-policy/ --resource deployment.yaml

fail: 1/12
  require-resource-limits: CPU and memory limits required
```

**CI** (same container, same validation):

```yaml
steps:
  - name: Policy Check
    image: policy-platform:latest
    script:
      - kyverno apply /repos/security-policy/ --resource deployment.yaml
```

**Output is identical. No surprises.**

---

## Troubleshooting

### Volume Mount Permissions

**Problem**: `permission denied` when accessing workspace files

**Cause**: Container user doesn't match host user

**Solution**: Match container user to host user

```bash
docker run --rm \
  -v $(pwd):/workspace \
  --user $(id -u):$(id -g) \
  policy-platform:latest \
  kyverno apply /repos/security-policy/ --resource /workspace/deployment.yaml
```

### Policy Not Found

**Problem**: `policy not found` error

**Cause**: Policy path incorrect or missing from container

**Solution**: List available policies in container

```bash
docker run --rm policy-platform:latest ls -R /repos/
```

### Outdated Container

**Problem**: Policies don't match CI

**Cause**: Local container image is stale

**Solution**: Pull latest image

```bash
docker pull policy-platform:latest
```

!!! tip "Pull Before Every Validation"
    Policy repos update frequently. Set up a cron job or Git hook to pull `policy-platform:latest` daily.

---

## Best Practices

### 1. Validate Before Every Commit

Use pre-commit hooks or Make targets. Catch issues in seconds.

### 2. Test All Environments

Don't just validate dev. Production values differ.

### 3. Generate Policy Reports

Save reports for review. Share with team.

### 4. Match CI Exactly

Use same container image as CI. Same commands. Same flags.

### 5. Version Policy Container

Pin to specific versions for reproducibility:

```bash
docker run policy-platform:v1.0.2 ...
```

---

## Performance Tips

### Cache Container Locally

```bash
# Pull once, use many times
docker pull policy-platform:latest

# Validate without pulling
docker run --rm -v $(pwd):/workspace policy-platform:latest \
  kyverno apply /repos/security-policy/ --resource deployment.yaml
```

### Validate Changed Files Only

```bash
# Get changed YAML files
CHANGED=$(git diff --name-only --diff-filter=ACM | grep '\.yaml$')

# Validate only changed files
for file in $CHANGED; do
  docker run --rm -v $(pwd):/workspace policy-platform:latest \
    kyverno apply /repos/security-policy/ --resource /workspace/$file
done
```

---

## Next Steps

- **[CI Integration](../ci-integration/index.md)** - Automate policy checks in pipelines
- **[Policy Packaging](../policy-packaging/index.md)** - Build your own policy-platform container
- **[Multi-Source Policies](../multi-source-policies/index.md)** - Aggregate multiple policy repos
