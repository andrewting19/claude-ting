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
if [ ${#build_args[@]} -gt 0 ]; then
    docker build "${build_args[@]}" -f Dockerfile.ubuntu-dev -t ubuntu-dev .
else
    docker build -f Dockerfile.ubuntu-dev -t ubuntu-dev .
fi

echo ""
echo "✓ Docker image built successfully!"
echo ""
