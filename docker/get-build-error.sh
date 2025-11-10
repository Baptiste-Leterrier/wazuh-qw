#!/bin/bash
# Get detailed compilation error from Docker build
# This will show the actual C++ compilation error

set -e

cd "$(dirname "$0")"

echo "=========================================="
echo "Docker Build Error Extractor"
echo "=========================================="
echo ""

# Make sure we're using the latest Dockerfile
if grep -q 'USER_BINARYINSTALL="y"' Dockerfile 2>/dev/null; then
    echo "⚠️  WARNING: You're using the OLD Dockerfile!"
    echo "   Please pull the latest changes or copy Dockerfile.fixed:"
    echo ""
    echo "   cp Dockerfile.fixed Dockerfile"
    echo ""
    read -p "Fix this automatically? (yes/no): " -r
    if [[ $REPLY =~ ^[Yy]es$ ]]; then
        cp Dockerfile.fixed Dockerfile
        echo "✓ Dockerfile updated"
    else
        echo "Aborted. Please update Dockerfile first."
        exit 1
    fi
fi

echo "Building with full error output..."
echo "This will save to: build-detailed-error.log"
echo ""

# Build with maximum verbosity and single job
BUILD_JOBS=1 docker compose build \
    --no-cache \
    --progress=plain \
    2>&1 | tee build-detailed-error.log

echo ""
echo "=========================================="
echo "Build completed. Checking for errors..."
echo "=========================================="
echo ""

# Extract the actual error
if grep -q "Error 2" build-detailed-error.log; then
    echo "❌ Build failed. Extracting compilation errors:"
    echo ""

    # Look for actual C++ errors
    echo "=== C++ Compilation Errors ==="
    grep -E "error:|error :|undefined reference|multiple definition" build-detailed-error.log | tail -20

    echo ""
    echo "=== Last 50 lines of build ==="
    tail -50 build-detailed-error.log

    echo ""
    echo "Full log saved to: build-detailed-error.log"
    echo ""
    echo "Common solutions:"
    echo "  1. Not enough RAM - Try BUILD_JOBS=1"
    echo "  2. Check the errors above for missing headers"
    echo "  3. Share build-detailed-error.log for help"
else
    echo "✓ Build succeeded!"
fi
