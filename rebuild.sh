#!/bin/bash

set -euo pipefail

build_args=()

for arg in "$@"; do
    case "$arg" in
        --no-cache)
            build_args+=(--no-cache)
            ;;
        --update)
            build_args+=(--build-arg "CLI_VERSION=$(date +%s)")
            ;;
    esac
done

echo "Building ubuntu-dev Docker image..."
docker build "${build_args[@]}" -f Dockerfile.ubuntu-dev -t ubuntu-dev .

echo ""
echo "✓ Docker image built successfully!"
echo ""
