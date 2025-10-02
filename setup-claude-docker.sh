#!/bin/bash

# Build the Docker image
echo "Building ubuntu-dev Docker image..."
docker build -f Dockerfile.ubuntu-dev -t ubuntu-dev .

# Check if ANTHROPIC_API_KEY is set and offer to configure Claude
if [ -n "$ANTHROPIC_API_KEY" ]; then
    echo ""
    echo "✓ ANTHROPIC_API_KEY environment variable detected!"
    echo ""
    read -p "Would you like to configure Claude Code to use this API key? (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Create ~/.claude directory if it doesn't exist
        mkdir -p "$HOME/.claude"
        
        # Create the API helper script
        echo "Creating API helper script..."
        cat > "$HOME/.claude/anthropic_key.sh" << 'HELPER_EOF'
#!/bin/bash
echo "$ANTHROPIC_API_KEY"
HELPER_EOF
        chmod +x "$HOME/.claude/anthropic_key.sh"
        
        # Update or create settings.json
        if [ -f "$HOME/.claude/settings.json" ]; then
            echo "Updating existing ~/.claude/settings.json..."
            # Use jq if available, otherwise use a simple approach
            if command -v jq &> /dev/null; then
                jq '. + {"apiKeyHelper": "~/.claude/anthropic_key.sh"}' "$HOME/.claude/settings.json" > "$HOME/.claude/settings.json.tmp" && \
                mv "$HOME/.claude/settings.json.tmp" "$HOME/.claude/settings.json"
            else
                # Simple approach without jq - just recreate the file
                echo '{"model": "opus", "apiKeyHelper": "~/.claude/anthropic_key.sh"}' > "$HOME/.claude/settings.json"
            fi
        else
            echo "Creating ~/.claude/settings.json..."
            echo '{"model": "opus", "apiKeyHelper": "~/.claude/anthropic_key.sh"}' > "$HOME/.claude/settings.json"
        fi
        
        echo "✓ API authentication configured successfully!"
    else
        echo "Skipping API configuration. You can set it up manually later."
    fi
else
    echo ""
    echo "⚠️  ANTHROPIC_API_KEY environment variable not found."
    echo "To use Claude Code in Docker, you'll need to:"
    echo "1. Set ANTHROPIC_API_KEY in your shell environment"
    echo "2. Re-run this setup script to configure API authentication"
    echo ""
fi

# Add this function to your shell configuration (~/.bashrc or ~/.zshrc)
cat << 'EOF'

# Add this function to your ~/.bashrc or ~/.zshrc file:

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
    docker_cmd="$docker_cmd -e ANTHROPIC_API_KEY=\"$ANTHROPIC_API_KEY\""
    docker_cmd="$docker_cmd -v \"$path:/workspace\""
    docker_cmd="$docker_cmd -w /workspace"
    docker_cmd="$docker_cmd -v \"$HOME/.local/share/nvim:/root/.local/share/nvim\""
    docker_cmd="$docker_cmd -v \"$HOME/.claude:/root/.claude\""
    
    # Add .claude.json mount if it exists
    if [ -f "$HOME/.claude.json" ]; then
        docker_cmd="$docker_cmd -v \"$HOME/.claude.json:/root/.claude.json\""
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
echo "To use this setup:"
echo "1. Run: source setup-claude-docker.sh"
echo "2. Add the function above to your ~/.bashrc or ~/.zshrc"
echo "3. Use: claude-docker /path/to/project"
echo "   Or: claude-docker . (for current directory)"
