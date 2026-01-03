#!/bin/bash

# Parse flags
NO_CACHE=""
if [[ "$1" == "--no-cache" ]]; then
    NO_CACHE="--no-cache"
fi

# Build the Docker image
echo "Building ubuntu-dev Docker image..."
docker build -f Dockerfile.ubuntu-dev -t ubuntu-dev . $NO_CACHE

echo ""
echo "✓ Docker image built successfully!"
echo ""