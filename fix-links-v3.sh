#!/bin/bash

set -e

TEMPLATE_DIR="docs/enforce/policy-as-code/template-library"

echo "Fixing links to root-level template-library files..."

# Fix links FROM subdirectories TO root-level files
for subdir in jmespath kyverno-generation kyverno-image kyverno-mutation kyverno-network kyverno-pod-security kyverno-resource opa-image opa-pod-security opa-rbac opa-resource; do
    if [ -d "$TEMPLATE_DIR/$subdir" ]; then
        echo "Fixing links in $subdir/ to root-level files..."

        # These files are at the root of template-library/, need ../ prefix from subdirs
        find "$TEMPLATE_DIR/$subdir" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)decision-guide\.md|\1../decision-guide.md|g' {} +
        find "$TEMPLATE_DIR/$subdir" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-templates\.md|\1../kyverno-templates.md|g' {} +
        find "$TEMPLATE_DIR/$subdir" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-labels\.md|\1../kyverno-labels.md|g' {} +
        find "$TEMPLATE_DIR/$subdir" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)opa-templates\.md|\1../opa-templates.md|g' {} +
        find "$TEMPLATE_DIR/$subdir" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)opa-kyverno-comparison\.md|\1../opa-kyverno-comparison.md|g' {} +
        find "$TEMPLATE_DIR/$subdir" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)opa-kyverno-migration\.md|\1../opa-kyverno-migration.md|g' {} +
        find "$TEMPLATE_DIR/$subdir" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)usage-guide\.md|\1../usage-guide.md|g' {} +
        find "$TEMPLATE_DIR/$subdir" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)ci-cd-integration\.md|\1../ci-cd-integration.md|g' {} +
    fi
done

echo "Fixing kyverno-image/ links from opa-image/..."
# Fix links in opa-image/ to kyverno-image/ files (they're siblings, need ../)
if [ -d "$TEMPLATE_DIR/opa-image" ]; then
    find "$TEMPLATE_DIR/opa-image" -name "*.md" -type f -exec sed -i '' 's|kyverno-image/|../kyverno-image/|g' {} +
fi

echo "Fixing kyverno-pod-security/ links from opa-pod-security/..."
# Fix links in opa-pod-security/ to kyverno-pod-security/ files
if [ -d "$TEMPLATE_DIR/opa-pod-security" ]; then
    find "$TEMPLATE_DIR/opa-pod-security" -name "*.md" -type f -exec sed -i '' 's|kyverno-pod-security/|../kyverno-pod-security/|g' {} +
fi

echo "Fixing kyverno-pod-security/ links from opa-rbac/..."
# Fix links in opa-rbac/ to kyverno-pod-security/ files
if [ -d "$TEMPLATE_DIR/opa-rbac" ]; then
    find "$TEMPLATE_DIR/opa-rbac" -name "*.md" -type f -exec sed -i '' 's|kyverno-pod-security/|../kyverno-pod-security/|g' {} +
fi

echo "Fixing kyverno-resource/ links from opa-resource/..."
# Fix links in opa-resource/ to kyverno-resource/ files
if [ -d "$TEMPLATE_DIR/opa-resource" ]; then
    find "$TEMPLATE_DIR/opa-resource" -name "*.md" -type f -exec sed -i '' 's|kyverno-resource/|../kyverno-resource/|g' {} +
fi

echo "Fixing ../ links in kyverno-mutation/index.md..."
# Fix broken ../ links in kyverno-mutation/index.md - should be ../kyverno-XXX/
if [ -f "$TEMPLATE_DIR/kyverno-mutation/index.md" ]; then
    # These were already changed to ../../, need to be ../
    sed -i '' 's|../../kyverno-generation/index\.md|../kyverno-generation/index.md|g' "$TEMPLATE_DIR/kyverno-mutation/index.md"
    sed -i '' 's|../../kyverno-image/index\.md|../kyverno-image/index.md|g' "$TEMPLATE_DIR/kyverno-mutation/index.md"
fi

echo "Done fixing remaining links!"
echo ""
echo "Running mkdocs build --strict to verify..."
mkdocs build --strict
