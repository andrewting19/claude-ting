# Claude Docker Setup

This repository contains a Docker setup for running Claude Code CLI in an isolated Ubuntu container with development tools.

## Overview

Instead of installing Claude Code and various development tools directly on your macOS system, this setup:
- Runs Claude Code inside a Docker container
- Provides a consistent Ubuntu 24.04 development environment
- Includes common development tools (git, vim, neovim, python, node, etc.)
- Mounts your project directory into the container
- Maintains isolation between your host system and the development environment

## How It Works

### Architecture

```
Your Mac (Host)
    ↓
Docker Container (ubuntu-dev)
    ├── Ubuntu 24.04 base image
    ├── Claude Code CLI
    ├── Development tools
    └── Your project files (mounted volume)
```

### Key Components

1. **Dockerfile.ubuntu-dev**: Defines the Docker image with:
   - Ubuntu 24.04 as base
   - Essential development tools (git, vim, neovim, build-essential)
   - Programming languages (Python 3, Node.js, npm)
   - Utilities (ripgrep, fd-find, bat, jq, htop)
   - Claude Code CLI (`@anthropic-ai/claude-code`)
   - A non-root user `dev` for security

2. **Shell Function (`claude-docker`)**: A Zsh function that:
   - Accepts a path argument (defaults to current directory)
   - Converts relative paths to absolute paths
   - Runs the Docker container with appropriate volume mounts
   - Passes through to Claude with `--dangerously-skip-permissions` flag

3. **Volume Mounts**:
   - Project directory → `/home/dev/workspace` (working directory)
   - Neovim config → `/home/dev/.local/share/nvim` (shared editor data)
   - Claude config → `~/.claude` directory and `~/.claude.json` file

## Installation

### Prerequisites

- Docker Desktop for Mac installed and running
- Zsh shell (default on macOS)
- Anthropic API key set as `ANTHROPIC_API_KEY` environment variable

### Setup Steps

1. **Run the setup script** (handles Docker build and API configuration):

   ```bash
   cd /Users/andrewting/Documents/git_repos/claude-ting
   source setup-claude-docker.sh
   ```

   The script will:
   - Build the Docker image
   - Detect if you have `ANTHROPIC_API_KEY` set
   - Offer to configure Claude Code API authentication automatically

2. **Add or update the shell function in your ~/.zprofile**:

   ```bash
   claude-docker() {
       local path="${1:-.}"  # Default to current directory if no args
       local extra_args="${2}"
       
       # Convert relative path to absolute
       if [[ "$path" != /* ]]; then
           path="$(pwd)/$path"
       fi
       
       # Create ~/.claude directory if it doesn't exist
       /bin/mkdir -p "$HOME/.claude"
       
       # Build docker command with optional mounts
       local docker_cmd="/usr/local/bin/docker run -it --rm --user dev"
       docker_cmd="$docker_cmd -e ANTHROPIC_API_KEY=\"$ANTHROPIC_API_KEY\""
       docker_cmd="$docker_cmd -v \"$path:/home/dev/workspace\""
       docker_cmd="$docker_cmd -w /home/dev/workspace"
       docker_cmd="$docker_cmd -v \"$HOME/.local/share/nvim:/home/dev/.local/share/nvim\""
       docker_cmd="$docker_cmd -v \"$HOME/.claude:/home/dev/.claude\""
       
       # Add .claude.json mount if it exists
       if [ -f "$HOME/.claude.json" ]; then
           docker_cmd="$docker_cmd -v \"$HOME/.claude.json:/home/dev/.claude.json\""
       fi
       
       # Add extra args if provided
       if [ -n "$extra_args" ]; then
           docker_cmd="$docker_cmd $extra_args"
       fi
       
       docker_cmd="$docker_cmd ubuntu-dev claude --dangerously-skip-permissions"
       
       # Execute the command
       eval $docker_cmd
   }
   
   alias clauded='claude-docker'
   ```

3. **Reload your shell configuration**:

   ```bash
   source ~/.zprofile
   ```

## Usage

### Basic Usage

```bash
# Run Claude in current directory
clauded

# Run Claude in a specific project
clauded /path/to/project

# With extra Docker arguments (e.g., port mapping for web development)
clauded . "-p 3000:3000"
```

### Port Mapping Explanation

When developing web applications inside the container, you need port mapping to access the application from your browser:

- `-p 3000:3000` maps port 3000 from container → host
- This allows `localhost:3000` on your Mac to reach the app running in the container
- Format: `-p HOST_PORT:CONTAINER_PORT`

Example for a Node.js app:

```bash
clauded . "-p 3000:3000 -p 5173:5173"  # Maps both development and Vite ports
```

## File Structure

```text
claude-ting/
├── Dockerfile.ubuntu-dev    # Docker image definition
├── README.md               # This documentation
└── setup-claude-docker.sh  # Helper script (optional)
```

## How the Docker Command Works

The `docker run` command breakdown:

- `-it`: Interactive terminal (allows Claude's interactive mode)
- `--rm`: Remove container after exit (keeps things clean)
- `--user dev`: Run as non-root user for security
- `-v "$path:/home/dev/workspace"`: Mount your project into the container
- `-w /home/dev/workspace`: Set working directory
- `-e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"`: Pass API key to container
- `-v "$HOME/.local/share/nvim:..."`: Share Neovim data
- `-v "$HOME/.claude:/home/dev/.claude"`: Mount Claude config directory with helper script
- `-v "$HOME/.claude.json:/home/dev/.claude.json"`: Mount Claude settings file (if exists)
- `$extra_args`: Additional Docker arguments (ports, env vars, etc.)
- `ubuntu-dev`: The Docker image name
- `claude --dangerously-skip-permissions`: Run Claude without permission checks

## Authentication

### How It Works

Claude Code typically uses OAuth authentication, which doesn't work well in Docker containers. This setup uses an **API helper method** instead:

1. **API Key Environment Variable**: Your `ANTHROPIC_API_KEY` is passed to the Docker container
2. **Helper Script**: `~/.claude/anthropic_key.sh` echoes the API key when Claude requests it
3. **Configuration**: `~/.claude/settings.json` tells Claude to use the helper script
4. **Result**: Claude authenticates using your API key instead of OAuth

### Files Involved

- `~/.claude/anthropic_key.sh` - Script that returns your API key
- `~/.claude/settings.json` - Claude configuration pointing to the helper
- `~/.claude.json` - Additional Claude settings (mounted if exists)
- Environment variable `ANTHROPIC_API_KEY` - Your actual API key

## Troubleshooting

### "docker: command not found"

- The function uses the full path `/usr/local/bin/docker` to avoid PATH issues
- Ensure Docker Desktop is installed and running

### Container can't access files

- Check that the path you're mounting exists
- Ensure Docker Desktop has file sharing permissions for your directories

### Claude Code issues

- The container runs Claude with `--dangerously-skip-permissions` to bypass permission checks
- This is necessary because the container environment differs from a standard installation

### "Missing API key" error

1. **Check environment variable**: Ensure `ANTHROPIC_API_KEY` is set in your shell:
   ```bash
   echo $ANTHROPIC_API_KEY
   ```

2. **Verify helper script**:
   ```bash
   # Should output your API key
   ~/.claude/anthropic_key.sh
   ```

3. **Check Claude settings**:
   ```bash
   cat ~/.claude/settings.json
   # Should contain: "apiKeyHelper": "~/.claude/anthropic_key.sh"
   ```

4. **Test in container**:
   ```bash
   docker run --rm --user dev -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" -v "$HOME/.claude:/home/dev/.claude" ubuntu-dev bash -c 'echo "test" | claude --dangerously-skip-permissions'
   ```

## Benefits

1. **Isolation**: Your host system remains clean
2. **Consistency**: Same environment every time
3. **Portability**: Easy to recreate on other machines
4. **Security**: Runs as non-root user in container
5. **Flexibility**: Easy to add/remove tools by updating Dockerfile

## Updating

To update the tools or Claude Code version:

1. Edit `Dockerfile.ubuntu-dev`
2. Rebuild the image:

   ```bash
   docker build -f Dockerfile.ubuntu-dev -t ubuntu-dev .
   ```

## Notes

- The container is ephemeral - it's removed after each session
- Only your project files (mounted volume) persist between sessions
- Install project-specific dependencies inside your project, not in the Docker image
- The Docker image includes general-purpose development tools
