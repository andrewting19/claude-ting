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
    # Point PostgreSQL to host
    docker_cmd="$docker_cmd -e POSTGRES_HOST=\"host.docker.internal\""

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

    # Expose CDP port for browser automation (optional, use -p 9222:9222 in extra_args)
    docker_cmd="$docker_cmd ubuntu-dev claude --dangerously-skip-permissions"

    # Execute the command
    eval $docker_cmd
}

# Alias for easier access
alias clauded='claude-docker'

# Browser-enabled variant
claudedb() {
    claude-docker "${1:-.}" "-e ENABLE_BROWSER=1 ${2}"
}

codex-docker() {
    local path="$(pwd)"
    local docker_extra_args=""
    local codex_args=""

    # Check if first arg is a codex subcommand
    case "$1" in
        resume|exec|e|login|logout|mcp|mcp-server|app-server|completion|sandbox|debug|apply|a|cloud|features|help)
            # Pass all args to codex
            codex_args="$@"
            ;;
        *)
            # First arg is a path (or default to current dir)
            path="${1:-.}"
            if [[ "$path" != /* ]]; then
                path="$(pwd)/$path"
            fi
            # Second arg is docker extra args
            docker_extra_args="${2}"
            ;;
    esac

    # Create ~/.codex directory if it doesn't exist
    /bin/mkdir -p "$HOME/.codex"

    local docker_cmd="/usr/local/bin/docker run -it --rm"

    docker_cmd="$docker_cmd -e HOST_PATH=\"$path\""
    # Point PostgreSQL to host
    docker_cmd="$docker_cmd -e POSTGRES_HOST=\"host.docker.internal\""
    # Ensure MCP inside container points to host gateway
    docker_cmd="$docker_cmd -e DEV_SESSIONS_GATEWAY_URL=\"${DEV_SESSIONS_GATEWAY_URL:-http://host.docker.internal:6767}\""
    docker_cmd="$docker_cmd -e CODEX_HOME=/root/.codex"
    docker_cmd="$docker_cmd -v \"$path:/workspace\""
    docker_cmd="$docker_cmd -w /workspace"
    docker_cmd="$docker_cmd -v \"$HOME/.local/share/nvim:/root/.local/share/nvim\""
    docker_cmd="$docker_cmd -v \"$HOME/.codex:/root/.codex\""

    if [ -n "$docker_extra_args" ]; then
        docker_cmd="$docker_cmd $docker_extra_args"
    fi

    docker_cmd="$docker_cmd ubuntu-dev codex --dangerously-bypass-approvals-and-sandbox"

    if [ -n "$codex_args" ]; then
        docker_cmd="$docker_cmd $codex_args"
    fi

    eval $docker_cmd
}

alias codexed='codex-docker'

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
echo ""
echo "Codex:"
echo "  codexed"
echo "  # First run prompts for login (or run 'codex login' inside)"
echo ""
echo "Usage:"
echo "  codexed                    # Current directory"
echo "  codexed /path/to/project   # Specific path"
echo "  codexed . \"-p 3000:3000\"   # With port mapping"
echo ""
echo "Browser automation (adds Playwright MCP for web browsing):"
echo "  claudedb                        # Current dir with browser"
echo "  claudedb /path/to/project       # Specific path with browser"
echo "  claudedb . \"-p 9222:9222\"       # With external CDP access"
echo "  # Starts Xvfb, Chromium with CDP, and adds Playwright MCP to agent config"
echo ""

# Skills installation prompt
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -d "$SCRIPT_DIR/skills" ]]; then
    echo "---"
    echo ""
    read -p "Install Claude Code skills (architect, handoff, dev-control)? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        "$SCRIPT_DIR/skills/install.sh"
        echo ""
        echo "Skills installed. Available commands:"
        echo "  /architect   - Strategic orchestration mode"
        echo "  /handoff     - Hand off to fresh dev session"
        echo "  /dev-control - Orchestrate dev sessions in real-time"
    fi
fi
