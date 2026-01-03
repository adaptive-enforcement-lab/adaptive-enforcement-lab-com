#!/bin/bash

set -e

TEMPLATE_DIR="docs/enforce/policy-as-code/template-library"

echo "Fixing cross-subdirectory links (phase 2)..."

# Fix links FROM kyverno-mutation TO other subdirectories
if [ -d "$TEMPLATE_DIR/kyverno-mutation" ]; then
    echo "Fixing links in kyverno-mutation/ to other subdirectories..."
    find "$TEMPLATE_DIR/kyverno-mutation" -name "*.md" -type f -exec sed -i '' 's|kyverno-network/|../kyverno-network/|g' {} +
    find "$TEMPLATE_DIR/kyverno-mutation" -name "*.md" -type f -exec sed -i '' 's|kyverno-generation/|../kyverno-generation/|g' {} +
    find "$TEMPLATE_DIR/kyverno-mutation" -name "*.md" -type f -exec sed -i '' 's|kyverno-pod-security/|../kyverno-pod-security/|g' {} +
    find "$TEMPLATE_DIR/kyverno-mutation" -name "*.md" -type f -exec sed -i '' 's|kyverno-image/|../kyverno-image/|g' {} +
    find "$TEMPLATE_DIR/kyverno-mutation" -name "*.md" -type f -exec sed -i '' 's|kyverno-resource/|../kyverno-resource/|g' {} +
    find "$TEMPLATE_DIR/kyverno-mutation" -name "*.md" -type f -exec sed -i '' 's|opa-|../opa-|g' {} +
    find "$TEMPLATE_DIR/kyverno-mutation" -name "*.md" -type f -exec sed -i '' 's|jmespath/|../jmespath/|g' {} +
fi

# Fix links FROM jmespath TO other subdirectories
if [ -d "$TEMPLATE_DIR/jmespath" ]; then
    echo "Fixing links in jmespath/ to other subdirectories..."
    find "$TEMPLATE_DIR/jmespath" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-pod-security/|\1../kyverno-pod-security/|g' {} +
    find "$TEMPLATE_DIR/jmespath" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-network/|\1../kyverno-network/|g' {} +
    find "$TEMPLATE_DIR/jmespath" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-generation/|\1../kyverno-generation/|g' {} +
    find "$TEMPLATE_DIR/jmespath" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-image/|\1../kyverno-image/|g' {} +
    find "$TEMPLATE_DIR/jmespath" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-mutation/|\1../kyverno-mutation/|g' {} +
    find "$TEMPLATE_DIR/jmespath" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-resource/|\1../kyverno-resource/|g' {} +
    find "$TEMPLATE_DIR/jmespath" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)opa-image/|\1../opa-image/|g' {} +
    find "$TEMPLATE_DIR/jmespath" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)opa-pod-security/|\1../opa-pod-security/|g' {} +
    find "$TEMPLATE_DIR/jmespath" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)opa-rbac/|\1../opa-rbac/|g' {} +
    find "$TEMPLATE_DIR/jmespath" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)opa-resource/|\1../opa-resource/|g' {} +
fi

# Fix links FROM kyverno-generation TO other subdirectories
if [ -d "$TEMPLATE_DIR/kyverno-generation" ]; then
    echo "Fixing links in kyverno-generation/ to other subdirectories..."
    find "$TEMPLATE_DIR/kyverno-generation" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-network/|\1../kyverno-network/|g' {} +
    find "$TEMPLATE_DIR/kyverno-generation" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-mutation/|\1../kyverno-mutation/|g' {} +
    find "$TEMPLATE_DIR/kyverno-generation" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-pod-security/|\1../kyverno-pod-security/|g' {} +
    find "$TEMPLATE_DIR/kyverno-generation" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-image/|\1../kyverno-image/|g' {} +
    find "$TEMPLATE_DIR/kyverno-generation" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-resource/|\1../kyverno-resource/|g' {} +
    find "$TEMPLATE_DIR/kyverno-generation" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)jmespath/|\1../jmespath/|g' {} +
fi

# Fix links FROM kyverno-image TO other subdirectories
if [ -d "$TEMPLATE_DIR/kyverno-image" ]; then
    echo "Fixing links in kyverno-image/ to other subdirectories..."
    find "$TEMPLATE_DIR/kyverno-image" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-network/|\1../kyverno-network/|g' {} +
    find "$TEMPLATE_DIR/kyverno-image" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-mutation/|\1../kyverno-mutation/|g' {} +
    find "$TEMPLATE_DIR/kyverno-image" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-pod-security/|\1../kyverno-pod-security/|g' {} +
    find "$TEMPLATE_DIR/kyverno-image" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-generation/|\1../kyverno-generation/|g' {} +
    find "$TEMPLATE_DIR/kyverno-image" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-resource/|\1../kyverno-resource/|g' {} +
    find "$TEMPLATE_DIR/kyverno-image" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)jmespath/|\1../jmespath/|g' {} +
fi

# Fix links FROM kyverno-network TO other subdirectories
if [ -d "$TEMPLATE_DIR/kyverno-network" ]; then
    echo "Fixing links in kyverno-network/ to other subdirectories..."
    find "$TEMPLATE_DIR/kyverno-network" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-mutation/|\1../kyverno-mutation/|g' {} +
    find "$TEMPLATE_DIR/kyverno-network" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-pod-security/|\1../kyverno-pod-security/|g' {} +
    find "$TEMPLATE_DIR/kyverno-network" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-image/|\1../kyverno-image/|g' {} +
    find "$TEMPLATE_DIR/kyverno-network" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-generation/|\1../kyverno-generation/|g' {} +
    find "$TEMPLATE_DIR/kyverno-network" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-resource/|\1../kyverno-resource/|g' {} +
    find "$TEMPLATE_DIR/kyverno-network" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)jmespath/|\1../jmespath/|g' {} +
fi

# Fix links FROM kyverno-pod-security TO other subdirectories
if [ -d "$TEMPLATE_DIR/kyverno-pod-security" ]; then
    echo "Fixing links in kyverno-pod-security/ to other subdirectories..."
    find "$TEMPLATE_DIR/kyverno-pod-security" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-mutation/|\1../kyverno-mutation/|g' {} +
    find "$TEMPLATE_DIR/kyverno-pod-security" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-network/|\1../kyverno-network/|g' {} +
    find "$TEMPLATE_DIR/kyverno-pod-security" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-image/|\1../kyverno-image/|g' {} +
    find "$TEMPLATE_DIR/kyverno-pod-security" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-generation/|\1../kyverno-generation/|g' {} +
    find "$TEMPLATE_DIR/kyverno-pod-security" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-resource/|\1../kyverno-resource/|g' {} +
    find "$TEMPLATE_DIR/kyverno-pod-security" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)jmespath/|\1../jmespath/|g' {} +
fi

# Fix links FROM kyverno-resource TO other subdirectories
if [ -d "$TEMPLATE_DIR/kyverno-resource" ]; then
    echo "Fixing links in kyverno-resource/ to other subdirectories..."
    find "$TEMPLATE_DIR/kyverno-resource" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-mutation/|\1../kyverno-mutation/|g' {} +
    find "$TEMPLATE_DIR/kyverno-resource" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-network/|\1../kyverno-network/|g' {} +
    find "$TEMPLATE_DIR/kyverno-resource" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-image/|\1../kyverno-image/|g' {} +
    find "$TEMPLATE_DIR/kyverno-resource" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-generation/|\1../kyverno-generation/|g' {} +
    find "$TEMPLATE_DIR/kyverno-resource" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)kyverno-pod-security/|\1../kyverno-pod-security/|g' {} +
    find "$TEMPLATE_DIR/kyverno-resource" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)jmespath/|\1../jmespath/|g' {} +
fi

# Fix links FROM opa-image TO other subdirectories
if [ -d "$TEMPLATE_DIR/opa-image" ]; then
    echo "Fixing links in opa-image/ to other subdirectories..."
    find "$TEMPLATE_DIR/opa-image" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)opa-pod-security/|\1../opa-pod-security/|g' {} +
    find "$TEMPLATE_DIR/opa-image" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)opa-rbac/|\1../opa-rbac/|g' {} +
    find "$TEMPLATE_DIR/opa-image" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)opa-resource/|\1../opa-resource/|g' {} +
    find "$TEMPLATE_DIR/opa-image" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)jmespath/|\1../jmespath/|g' {} +
fi

# Fix links FROM opa-pod-security TO other subdirectories
if [ -d "$TEMPLATE_DIR/opa-pod-security" ]; then
    echo "Fixing links in opa-pod-security/ to other subdirectories..."
    find "$TEMPLATE_DIR/opa-pod-security" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)opa-image/|\1../opa-image/|g' {} +
    find "$TEMPLATE_DIR/opa-pod-security" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)opa-rbac/|\1../opa-rbac/|g' {} +
    find "$TEMPLATE_DIR/opa-pod-security" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)opa-resource/|\1../opa-resource/|g' {} +
    find "$TEMPLATE_DIR/opa-pod-security" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)jmespath/|\1../jmespath/|g' {} +
fi

# Fix links FROM opa-rbac TO other subdirectories
if [ -d "$TEMPLATE_DIR/opa-rbac" ]; then
    echo "Fixing links in opa-rbac/ to other subdirectories..."
    find "$TEMPLATE_DIR/opa-rbac" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)opa-image/|\1../opa-image/|g' {} +
    find "$TEMPLATE_DIR/opa-rbac" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)opa-pod-security/|\1../opa-pod-security/|g' {} +
    find "$TEMPLATE_DIR/opa-rbac" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)opa-resource/|\1../opa-resource/|g' {} +
    find "$TEMPLATE_DIR/opa-rbac" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)jmespath/|\1../jmespath/|g' {} +
fi

# Fix links FROM opa-resource TO other subdirectories
if [ -d "$TEMPLATE_DIR/opa-resource" ]; then
    echo "Fixing links in opa-resource/ to other subdirectories..."
    find "$TEMPLATE_DIR/opa-resource" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)opa-image/|\1../opa-image/|g' {} +
    find "$TEMPLATE_DIR/opa-resource" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)opa-pod-security/|\1../opa-pod-security/|g' {} +
    find "$TEMPLATE_DIR/opa-resource" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)opa-rbac/|\1../opa-rbac/|g' {} +
    find "$TEMPLATE_DIR/opa-resource" -name "*.md" -type f -exec sed -i '' 's|\([^/]\)jmespath/|\1../jmespath/|g' {} +
fi

echo "Done fixing cross-subdirectory links!"
echo ""
echo "Running mkdocs build --strict to verify..."
mkdocs build --strict
