#!/bin/bash

# Build the Docker image (no cache)
echo "Building ubuntu-dev Docker image..."
docker build -f Dockerfile.ubuntu-dev -t ubuntu-dev . --no-cache

echo ""
echo "✓ Docker image built successfully!"
echo ""