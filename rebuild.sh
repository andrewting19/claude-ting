#!/bin/bash

# Parse flags
BUILD_ARGS=""
for arg in "$@"; do
    case "$arg" in
        --no-cache)
            BUILD_ARGS="$BUILD_ARGS --no-cache"
            ;;
        --update)
            BUILD_ARGS="$BUILD_ARGS --build-arg CLI_VERSION=$(date +%s)"
            ;;
    esac
done

# Build the Docker image
echo "Building ubuntu-dev Docker image..."
docker build -f Dockerfile.ubuntu-dev -t ubuntu-dev . $BUILD_ARGS

echo ""
echo "✓ Docker image built successfully!"
echo ""