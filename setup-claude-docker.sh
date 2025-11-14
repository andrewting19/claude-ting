#!/bin/bash

# Build the Docker image
echo "Building ubuntu-dev Docker image..."
docker build -f Dockerfile.ubuntu-dev -t ubuntu-dev .

echo ""
echo "✓ Docker image built successfully!"
echo ""

# Print instructions for adding the function
cat << 'EOF'

Add this function to your ~/.zshrc:

claude-docker() {
    local path="${1:-.}"
    local extra_args="${2}"

    # Convert relative path to absolute
    if [[ "$path" != /* ]]; then
        path="$(pwd)/$path"
    fi

    # Create ~/.claude directory if it doesn't exist
    /bin/mkdir -p "$HOME/.claude"

    # Build docker command with optional mounts
    local docker_cmd="/usr/local/bin/docker run -it --rm"

    # Pass through API key if set (optional, OAuth is preferred)
    if [ -n "$ANTHROPIC_API_KEY" ]; then
        docker_cmd="$docker_cmd -e ANTHROPIC_API_KEY=\"$ANTHROPIC_API_KEY\""
    fi

    # Pass host workspace path for dev-sessions MCP
    docker_cmd="$docker_cmd -e HOST_PATH=\"$path\""

    docker_cmd="$docker_cmd -v \"$path:/workspace\""
    docker_cmd="$docker_cmd -w /workspace"
    docker_cmd="$docker_cmd -v \"$HOME/.local/share/nvim:/root/.local/share/nvim\""
    docker_cmd="$docker_cmd -v \"$HOME/.claude:/root/.claude\""

    # Mount .claude.json as .claude.host.json for OAuth credential merging
    if [ -f "$HOME/.claude.json" ]; then
        docker_cmd="$docker_cmd -v \"$HOME/.claude.json:/root/.claude.host.json:ro\""
    fi

    # Add extra args if provided
    if [ -n "$extra_args" ]; then
        docker_cmd="$docker_cmd $extra_args"
    fi

    docker_cmd="$docker_cmd ubuntu-dev claude --dangerously-skip-permissions"

    # Execute the command
    eval $docker_cmd
}

# Alias for easier access
alias clauded='claude-docker'

EOF

echo ""
echo "First-time authentication:"
echo "  clauded"
echo "  # Inside container, run:"
echo "  /login"
echo ""
echo "Usage:"
echo "  clauded                    # Current directory"
echo "  clauded /path/to/project   # Specific path"
echo "  clauded . \"-p 3000:3000\"   # With port mapping"
