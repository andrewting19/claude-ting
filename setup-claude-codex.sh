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
	    # Note: in zsh, `path` is a special array tied to $PATH. Don't use it as a local var name.
	    local workspace_path="${1:-.}"
	    local extra_args="${2}"

	    # Convert relative path to absolute
	    if [[ "$workspace_path" != /* ]]; then
	        workspace_path="$(pwd)/$workspace_path"
	    fi
	    # Canonicalize so per-project Claude state matches native runs (no ".." segments).
	    if [[ -d "$workspace_path" ]]; then
	        workspace_path="$(cd "$workspace_path" && pwd -P)"
	    fi

	    # Create ~/.claude directory if it doesn't exist
	    /bin/mkdir -p "$HOME/.claude"
    # Ensure per-project Claude state (including auto-memory) does not collide in Docker.
    # Claude stores per-project state at: ~/.claude/projects/<sanitized-cwd>/...
	    # In Docker the CWD is always /workspace, so without this all projects share ~/.claude/projects/-workspace.
	    local sanitized_cwd
	    sanitized_cwd="${workspace_path//[^A-Za-z0-9]/-}"
	    local host_project_state_dir="$HOME/.claude/projects/${sanitized_cwd}"
	    /bin/mkdir -p "$host_project_state_dir"

    # Build docker command with optional mounts
    local docker_cmd="/usr/local/bin/docker run -it --rm"

    # Pass through API key if set (optional, OAuth is preferred)
    if [ -n "$ANTHROPIC_API_KEY" ]; then
        docker_cmd="$docker_cmd -e ANTHROPIC_API_KEY=\"$ANTHROPIC_API_KEY\""
	    fi

	    # Pass host workspace path for dev-sessions MCP
	    docker_cmd="$docker_cmd -e HOST_PATH=\"$workspace_path\""
	    # Point PostgreSQL to host
	    docker_cmd="$docker_cmd -e POSTGRES_HOST=\"host.docker.internal\""

	    docker_cmd="$docker_cmd -v \"$workspace_path:/workspace\""
	    docker_cmd="$docker_cmd -w /workspace"
	    docker_cmd="$docker_cmd -v \"$HOME/.local/share/nvim:/root/.local/share/nvim\""
	    docker_cmd="$docker_cmd -v \"$HOME/.claude:/root/.claude\""
    # Map Docker's /workspace project-state dir to the host's project-specific state dir.
    docker_cmd="$docker_cmd -v \"$host_project_state_dir:/root/.claude/projects/-workspace\""

    # Mount .claude.json as .claude.host.json for OAuth credential merging
	    if [ -f "$HOME/.claude.json" ]; then
	        docker_cmd="$docker_cmd -v \"$HOME/.claude.json:/root/.claude.host.json:ro\""
	    fi

	    # Mount gh CLI config.
	    # On macOS, hosts.yml commonly does NOT contain an oauth_token (it lives in Keychain),
	    # and mounting such a hosts.yml into Linux makes `gh auth status` report an invalid
	    # "default" token. Mount config.yml always, and only mount hosts.yml if it has a token.
	    if [ -f "$HOME/.config/gh/config.yml" ]; then
	        docker_cmd="$docker_cmd -v \"$HOME/.config/gh/config.yml:/root/.config/gh/config.yml:ro\""
	    fi
	    if [ -f "$HOME/.config/gh/hosts.yml" ] && grep -q "oauth_token:" "$HOME/.config/gh/hosts.yml" 2>/dev/null; then
	        docker_cmd="$docker_cmd -v \"$HOME/.config/gh/hosts.yml:/root/.config/gh/hosts.yml:ro\""
	    fi

	    # Forward GitHub auth into the container.
	    # On macOS, gh stores the token in the system keychain (not in ~/.config/gh/hosts.yml),
	    # so mounting ~/.config/gh alone does not authenticate gh inside a Linux container.
	    # Important: avoid embedding the token into the docker command string (ps/history); use env export.
	    local gh_token_env=""
	    if [ -n "$GH_TOKEN" ]; then
	        gh_token_env="$GH_TOKEN"
	    elif command -v gh >/dev/null 2>&1; then
	        gh_token_env="$(gh auth token 2>/dev/null || true)"
	    fi
	    if [ -n "$gh_token_env" ]; then
	        docker_cmd="$docker_cmd -e GH_TOKEN"
	    fi

	    # Add extra args if provided
	    if [ -n "$extra_args" ]; then
	        docker_cmd="$docker_cmd $extra_args"
    fi

	    # Expose CDP port for browser automation (optional, use -p 9222:9222 in extra_args)
	    docker_cmd="$docker_cmd ubuntu-dev claude --dangerously-skip-permissions"

	    # Execute the command
	    if [ -n "$gh_token_env" ]; then
	        ( export GH_TOKEN="$gh_token_env"; eval $docker_cmd )
	    else
	        eval $docker_cmd
	    fi
	}

# Alias for easier access
alias clauded='claude-docker'

# Browser-enabled variant
claudedb() {
    claude-docker "${1:-.}" "-e ENABLE_BROWSER=1 ${2}"
}

codex-docker() {
	    # Note: in zsh, `path` is a special array tied to $PATH. Don't use it as a local var name.
	    local workspace_path="$(pwd)"
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
	            workspace_path="${1:-.}"
	            if [[ "$workspace_path" != /* ]]; then
	                workspace_path="$(pwd)/$workspace_path"
	            fi
	            # Second arg is docker extra args
	            docker_extra_args="${2}"
	            ;;
    esac

    # Ensure host Codex state exists (created by running native Codex at least once)
    /bin/mkdir -p "$HOME/.codex"
    local codex_host_home="$HOME/.codex"
    local codex_history="$codex_host_home/history.jsonl"
    local codex_sessions="$codex_host_home/sessions"
    if [ ! -f "$codex_history" ] || [ ! -d "$codex_sessions" ]; then
        echo "codexed error: expected host Codex history/sessions to exist."
        echo "Missing:"
        [ ! -f "$codex_history" ] && echo "  $codex_history"
        [ ! -d "$codex_sessions" ] && echo "  $codex_sessions/"
        echo "Run native Codex once on the host to create these, then retry."
        return 1
    fi

	    local docker_cmd="/usr/local/bin/docker run -it --rm"

	    docker_cmd="$docker_cmd -e HOST_PATH=\"$workspace_path\""
	    # Point PostgreSQL to host
	    docker_cmd="$docker_cmd -e POSTGRES_HOST=\"host.docker.internal\""
	    # Ensure MCP inside container points to host gateway
	    docker_cmd="$docker_cmd -e DEV_SESSIONS_GATEWAY_URL=\"${DEV_SESSIONS_GATEWAY_URL:-http://host.docker.internal:6767}\""
	    docker_cmd="$docker_cmd -e CODEX_HOME=/root/.codex"
	    docker_cmd="$docker_cmd -v \"$workspace_path:/workspace\""
	    docker_cmd="$docker_cmd -w /workspace"
	    docker_cmd="$docker_cmd -v \"$HOME/.local/share/nvim:/root/.local/share/nvim\""
	    docker_cmd="$docker_cmd -v \"$HOME/.codex:/root/.codex\""
	    # Mount gh CLI config.
	    # On macOS, hosts.yml commonly does NOT contain an oauth_token (it lives in Keychain),
	    # and mounting such a hosts.yml into Linux makes `gh auth status` report an invalid
	    # "default" token. Mount config.yml always, and only mount hosts.yml if it has a token.
	    if [ -f "$HOME/.config/gh/config.yml" ]; then
	        docker_cmd="$docker_cmd -v \"$HOME/.config/gh/config.yml:/root/.config/gh/config.yml:ro\""
	    fi
	    if [ -f "$HOME/.config/gh/hosts.yml" ] && grep -q "oauth_token:" "$HOME/.config/gh/hosts.yml" 2>/dev/null; then
	        docker_cmd="$docker_cmd -v \"$HOME/.config/gh/hosts.yml:/root/.config/gh/hosts.yml:ro\""
	    fi
	    # Forward GitHub auth into the container.
	    # On macOS, gh stores the token in the system keychain (not in ~/.config/gh/hosts.yml),
	    # so mounting ~/.config/gh alone does not authenticate gh inside a Linux container.
	    # Important: avoid embedding the token into the docker command string (ps/history); use env export.
	    local gh_token_env=""
	    if [ -n "$GH_TOKEN" ]; then
	        gh_token_env="$GH_TOKEN"
	    elif command -v gh >/dev/null 2>&1; then
	        gh_token_env="$(gh auth token 2>/dev/null || true)"
	    fi
	    if [ -n "$gh_token_env" ]; then
	        docker_cmd="$docker_cmd -e GH_TOKEN"
	    fi
	    # Persist transcripts to host ~/.codex via bind mounts into the shadow home
	    docker_cmd="$docker_cmd -v \"$codex_history:/root/.codex-shadow/history.jsonl\""
	    docker_cmd="$docker_cmd -v \"$codex_sessions:/root/.codex-shadow/sessions\""

    if [ -n "$docker_extra_args" ]; then
        docker_cmd="$docker_cmd $docker_extra_args"
    fi

    docker_cmd="$docker_cmd ubuntu-dev codex --dangerously-bypass-approvals-and-sandbox"

	    if [ -n "$codex_args" ]; then
	        docker_cmd="$docker_cmd $codex_args"
	    fi

	    if [ -n "$gh_token_env" ]; then
	        ( export GH_TOKEN="$gh_token_env"; eval $docker_cmd )
	    else
	        eval $docker_cmd
	    fi
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
