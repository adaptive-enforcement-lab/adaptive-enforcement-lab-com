#!/bin/bash

set -e

TEMPLATE_DIR="docs/enforce/policy-as-code/template-library"

echo "Fixing links in template-library files..."

# Function to fix links in all files EXCEPT those in a specific subdirectory
fix_links_outside_dir() {
    local old_pattern="$1"
    local new_pattern="$2"
    local exclude_dir="$3"

    find "$TEMPLATE_DIR" -name "*.md" ! -path "*/$exclude_dir/*" -type f -exec sed -i '' "s|${old_pattern}|${new_pattern}|g" {} +
}

# Function to fix links in files WITHIN a specific subdirectory (for internal links)
fix_links_inside_dir() {
    local old_pattern="$1"
    local new_pattern="$2"
    local target_dir="$3"

    if [ -d "$TEMPLATE_DIR/$target_dir" ]; then
        find "$TEMPLATE_DIR/$target_dir" -name "*.md" -type f -exec sed -i '' "s|${old_pattern}|${new_pattern}|g" {} +
    fi
}

echo "1. Fixing kyverno-generation links..."
# From outside kyverno-generation/ directory
fix_links_outside_dir "kyverno-generation-namespace\.md" "kyverno-generation/namespace.md" "kyverno-generation"
fix_links_outside_dir "kyverno-generation-workload\.md" "kyverno-generation/workload.md" "kyverno-generation"

# From inside kyverno-generation/ directory (no prefix needed)
fix_links_inside_dir "kyverno-generation-namespace\.md" "namespace.md" "kyverno-generation"
fix_links_inside_dir "kyverno-generation-workload\.md" "workload.md" "kyverno-generation"

echo "2. Fixing kyverno-image links..."
fix_links_outside_dir "kyverno-image-cve-scanning\.md" "kyverno-image/cve-scanning.md" "kyverno-image"
fix_links_outside_dir "kyverno-image-security\.md" "kyverno-image/security.md" "kyverno-image"
fix_links_outside_dir "kyverno-image-signing\.md" "kyverno-image/signing.md" "kyverno-image"
fix_links_outside_dir "kyverno-image-validation\.md" "kyverno-image/validation.md" "kyverno-image"

fix_links_inside_dir "kyverno-image-cve-scanning\.md" "cve-scanning.md" "kyverno-image"
fix_links_inside_dir "kyverno-image-security\.md" "security.md" "kyverno-image"
fix_links_inside_dir "kyverno-image-signing\.md" "signing.md" "kyverno-image"
fix_links_inside_dir "kyverno-image-validation\.md" "validation.md" "kyverno-image"

echo "3. Fixing kyverno-mutation links..."
fix_links_outside_dir "kyverno-mutation-labels\.md" "kyverno-mutation/labels.md" "kyverno-mutation"
fix_links_outside_dir "kyverno-mutation-sidecar\.md" "kyverno-mutation/sidecar.md" "kyverno-mutation"

fix_links_inside_dir "kyverno-mutation-labels\.md" "labels.md" "kyverno-mutation"
fix_links_inside_dir "kyverno-mutation-sidecar\.md" "sidecar.md" "kyverno-mutation"

echo "4. Fixing kyverno-network links..."
fix_links_outside_dir "kyverno-network-ingress-class\.md" "kyverno-network/ingress-class.md" "kyverno-network"
fix_links_outside_dir "kyverno-network-ingress-tls\.md" "kyverno-network/ingress-tls.md" "kyverno-network"
fix_links_outside_dir "kyverno-network-security\.md" "kyverno-network/security.md" "kyverno-network"
fix_links_outside_dir "kyverno-network-services\.md" "kyverno-network/services.md" "kyverno-network"

fix_links_inside_dir "kyverno-network-ingress-class\.md" "ingress-class.md" "kyverno-network"
fix_links_inside_dir "kyverno-network-ingress-tls\.md" "ingress-tls.md" "kyverno-network"
fix_links_inside_dir "kyverno-network-security\.md" "security.md" "kyverno-network"
fix_links_inside_dir "kyverno-network-services\.md" "services.md" "kyverno-network"

echo "5. Fixing kyverno-pod-security links..."
fix_links_outside_dir "kyverno-pod-security-privileges\.md" "kyverno-pod-security/privileges.md" "kyverno-pod-security"
fix_links_outside_dir "kyverno-pod-security-profiles\.md" "kyverno-pod-security/profiles.md" "kyverno-pod-security"
fix_links_outside_dir "kyverno-pod-security\.md" "kyverno-pod-security/standards.md" "kyverno-pod-security"

fix_links_inside_dir "kyverno-pod-security-privileges\.md" "privileges.md" "kyverno-pod-security"
fix_links_inside_dir "kyverno-pod-security-profiles\.md" "profiles.md" "kyverno-pod-security"
fix_links_inside_dir "kyverno-pod-security\.md" "standards.md" "kyverno-pod-security"

echo "6. Fixing kyverno-resource links..."
fix_links_outside_dir "kyverno-resource-hpa\.md" "kyverno-resource/hpa.md" "kyverno-resource"
fix_links_outside_dir "kyverno-resource-limits\.md" "kyverno-resource/limits.md" "kyverno-resource"
fix_links_outside_dir "kyverno-resource-storage\.md" "kyverno-resource/storage.md" "kyverno-resource"

fix_links_inside_dir "kyverno-resource-hpa\.md" "hpa.md" "kyverno-resource"
fix_links_inside_dir "kyverno-resource-limits\.md" "limits.md" "kyverno-resource"
fix_links_inside_dir "kyverno-resource-storage\.md" "storage.md" "kyverno-resource"

echo "7. Fixing opa-image links..."
fix_links_outside_dir "opa-image-base\.md" "opa-image/base.md" "opa-image"
fix_links_outside_dir "opa-image-digest\.md" "opa-image/digest.md" "opa-image"
fix_links_outside_dir "opa-image-security\.md" "opa-image/security.md" "opa-image"
fix_links_outside_dir "opa-image-verification\.md" "opa-image/verification.md" "opa-image"

fix_links_inside_dir "opa-image-base\.md" "base.md" "opa-image"
fix_links_inside_dir "opa-image-digest\.md" "digest.md" "opa-image"
fix_links_inside_dir "opa-image-security\.md" "security.md" "opa-image"
fix_links_inside_dir "opa-image-verification\.md" "verification.md" "opa-image"

echo "8. Fixing opa-pod-security links..."
fix_links_outside_dir "opa-pod-security-capabilities\.md" "opa-pod-security/capabilities.md" "opa-pod-security"
fix_links_outside_dir "opa-pod-security-contexts\.md" "opa-pod-security/contexts.md" "opa-pod-security"
fix_links_outside_dir "opa-pod-security-escalation\.md" "opa-pod-security/escalation.md" "opa-pod-security"
fix_links_outside_dir "opa-pod-security\.md" "opa-pod-security/overview.md" "opa-pod-security"

fix_links_inside_dir "opa-pod-security-capabilities\.md" "capabilities.md" "opa-pod-security"
fix_links_inside_dir "opa-pod-security-contexts\.md" "contexts.md" "opa-pod-security"
fix_links_inside_dir "opa-pod-security-escalation\.md" "escalation.md" "opa-pod-security"
fix_links_inside_dir "opa-pod-security\.md" "overview.md" "opa-pod-security"

echo "9. Fixing opa-rbac links..."
fix_links_outside_dir "opa-rbac-cluster-admin\.md" "opa-rbac/cluster-admin.md" "opa-rbac"
fix_links_outside_dir "opa-rbac-privileged-verbs\.md" "opa-rbac/privileged-verbs.md" "opa-rbac"
fix_links_outside_dir "opa-rbac-wildcards\.md" "opa-rbac/wildcards.md" "opa-rbac"
fix_links_outside_dir "opa-rbac\.md" "opa-rbac/overview.md" "opa-rbac"

fix_links_inside_dir "opa-rbac-cluster-admin\.md" "cluster-admin.md" "opa-rbac"
fix_links_inside_dir "opa-rbac-privileged-verbs\.md" "privileged-verbs.md" "opa-rbac"
fix_links_inside_dir "opa-rbac-wildcards\.md" "wildcards.md" "opa-rbac"
fix_links_inside_dir "opa-rbac\.md" "overview.md" "opa-rbac"

echo "10. Fixing opa-resource links..."
fix_links_outside_dir "opa-resource-governance\.md" "opa-resource/governance.md" "opa-resource"
fix_links_outside_dir "opa-resource-limitrange\.md" "opa-resource/limitrange.md" "opa-resource"
fix_links_outside_dir "opa-resource-storage\.md" "opa-resource/storage.md" "opa-resource"

fix_links_inside_dir "opa-resource-governance\.md" "governance.md" "opa-resource"
fix_links_inside_dir "opa-resource-limitrange\.md" "limitrange.md" "opa-resource"
fix_links_inside_dir "opa-resource-storage\.md" "storage.md" "opa-resource"

echo "11. Fixing jmespath links..."
# From outside jmespath/ directory
fix_links_outside_dir "jmespath-advanced\.md" "jmespath/advanced.md" "jmespath"
fix_links_outside_dir "jmespath-enterprise-supply-chain\.md" "jmespath/enterprise-supply-chain.md" "jmespath"
fix_links_outside_dir "jmespath-enterprise\.md" "jmespath/enterprise.md" "jmespath"
fix_links_outside_dir "jmespath-patterns\.md" "jmespath/patterns.md" "jmespath"
fix_links_outside_dir "jmespath-reference\.md" "jmespath/reference.md" "jmespath"
fix_links_outside_dir "jmespath-testing\.md" "jmespath/testing.md" "jmespath"

# From inside jmespath/ directory (no prefix needed)
fix_links_inside_dir "jmespath-advanced\.md" "advanced.md" "jmespath"
fix_links_inside_dir "jmespath-enterprise-supply-chain\.md" "enterprise-supply-chain.md" "jmespath"
fix_links_inside_dir "jmespath-enterprise\.md" "enterprise.md" "jmespath"
fix_links_inside_dir "jmespath-patterns\.md" "patterns.md" "jmespath"
fix_links_inside_dir "jmespath-reference\.md" "reference.md" "jmespath"
fix_links_inside_dir "jmespath-testing\.md" "testing.md" "jmespath"

echo "Done! All links fixed."
echo ""
echo "Running mkdocs build --strict to verify..."
mkdocs build --strict
