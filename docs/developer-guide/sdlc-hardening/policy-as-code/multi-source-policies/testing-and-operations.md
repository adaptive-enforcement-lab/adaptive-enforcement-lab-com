# Testing and Operations

Test multi-source policy aggregation and maintain policy repositories.

## Testing Multi-Source Policies

### Local Testing

Test all policy sources together:

```bash
# Render all policies
docker run --rm policy-platform:latest bash -c '
  helm template devops /repos/devops-policy/charts/devops-policy \
    -f /repos/devops-policy/cd/prd/values.yaml \
  > /tmp/devops.yaml &&
  helm template security /repos/security-policy/charts/security-policy \
    -f /repos/security-policy/cd/prd/values.yaml \
  > /tmp/security.yaml &&
  cat /tmp/devops.yaml /tmp/security.yaml
' > all-policies.yaml

# Validate application against all policies
kyverno apply all-policies.yaml --resource deployment.yaml
```

!!! tip "Test Combined Policies"
    Always test all policy sources together locally. Conflicts might only appear when policies are combined.

### CI Testing

Test policy aggregation in CI before container build:

```yaml
- step:
    name: Test Policy Aggregation
    image: alpine
    script:
      # Pull all policy repos
      - docker pull security-policy-repo:main
      - docker pull devops-policy-repo:main

      # Verify no conflicts
      - docker run security-policy-repo:main ls /repos/security-policy/
      - docker run devops-policy-repo:main ls /repos/devops-policy/
```

---

## Best Practices

### 1. Version Policy Repos

Tag policy repos with semantic versions:

```bash
docker tag security-policy-repo:main security-policy-repo:2.1.2
docker push security-policy-repo:2.1.2
```

### 2. Separate Concerns

- **Security team** → security-policy repo
- **DevOps team** → devops-policy repo
- **App teams** → application-specific policies

### 3. Test Independently

Each policy repo should be testable in isolation:

```bash
docker run --rm -v $(pwd):/workspace security-policy-repo:main \
  kyverno apply /repos/security-policy/ --resource /workspace/app.yaml
```

### 4. Document Policy Sources

In policy-platform README, list all sources:

```markdown
## Policy Sources

This container aggregates policies from:

- security-policy v2.1.2
- devops-policy v0.3.2
- backend-applications v1.5.0
```

### 5. Use Common Schemas

Standardize values.yaml structure across repos:

```yaml
policies:
  <policy-name>:
    enabled: true/false
    validationFailureAction: Enforce/Audit
```

---

## Troubleshooting

### Missing Policies

**Problem**: Policy not found in rendered output

**Cause**: Policy repo not copied in Dockerfile

**Solution**: Check if policy repo was copied

```bash
docker run --rm policy-platform:latest \
  ls /repos/security-policy/charts/security-policy/templates/
```

### Version Conflicts

**Problem**: Different policy versions pulled

**Cause**: Dockerfile pulls `latest` tag

**Solution**: Pin versions in Dockerfile

```dockerfile
FROM security-policy-repo:2.1.2 AS security_policy_repo
FROM devops-policy-repo:0.3.2 AS devops_policy_repo
```

!!! warning "Always Pin Versions"
    Never use `:latest` for policy repo dependencies. Pin exact versions to ensure reproducible builds and prevent breaking changes.

### Policy Overlap

**Problem**: Two policies with same name

**Cause**: Multiple repos define policies with identical names

**Solution**: Namespace policies by source

```yaml
metadata:
  name: security-require-limits  # Prefix with repo name
```

---

## Next Steps

- **[Policy Packaging](../policy-packaging/index.md)** - Build the policy-platform container
- **[Operations](../operations/index.md)** - Day-to-day policy management
- **[CI Integration](../ci-integration/index.md)** - Automate policy validation
