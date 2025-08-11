# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository provides a Docker-based setup for running Claude Code CLI in an isolated Ubuntu development container. The system allows users to run Claude Code without installing it directly on their macOS system, providing a consistent and isolated development environment.

## Architecture

The project consists of three main components:
1. **Docker Image** (Dockerfile.ubuntu-dev): Ubuntu 24.04 container with development tools and Claude Code CLI
2. **Shell Function** (claude-docker): Zsh function that manages Docker container execution with proper volume mounts
3. **Volume Mounts**: Project directory and Neovim configuration are mounted into the container

## Authentication Setup

### Problem
Claude Code CLI uses OAuth by default, which requires browser-based authentication. This doesn't work well in Docker containers where browser access may be limited or unavailable.

### Solution
The project uses Claude Code's API helper method with a custom script that provides the API key from an environment variable. This allows seamless authentication within the containerized environment.

### Implementation Details

#### Helper Script
A shell script at `~/.claude/anthropic_key.sh` that echoes the API key:
```bash
#!/bin/bash
echo "$ANTHROPIC_API_KEY"
```

#### Claude Configuration
The `~/.claude/settings.json` file is configured to use the helper script:
```json
{
  "apiKeyHelper": "~/.claude/anthropic_key.sh"
}
```

#### Environment Variable Passing
The `claude-docker` function passes the host's `ANTHROPIC_API_KEY` environment variable to the container:
```bash
-e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"
```

### Requirements
- User must have `ANTHROPIC_API_KEY` set in their shell environment
- The API key must be a valid Anthropic API key with appropriate permissions
- The helper script and settings files are automatically created during Docker image build

## Common Commands

### Building and Rebuilding
```bash
# Build or rebuild the Docker image after changes
docker build -f Dockerfile.ubuntu-dev -t ubuntu-dev .
```

### Testing Changes
```bash
# Test the Docker container directly
docker run -it --rm --user dev -v "$(pwd):/home/dev/workspace" -w /home/dev/workspace ubuntu-dev /bin/bash

# Test Claude Code in the container
docker run -it --rm --user dev -v "$(pwd):/home/dev/workspace" -w /home/dev/workspace ubuntu-dev claude --dangerously-skip-permissions
```

## Key Implementation Details

### Docker Configuration
- Base image: Ubuntu 24.04
- Non-root user: `dev` with sudo access
- Working directory: `/home/dev/workspace`
- Claude Code runs with `--dangerously-skip-permissions` flag due to container environment constraints

### Shell Function Path Handling
The `claude-docker` function in setup-claude-docker.sh handles both relative and absolute paths by converting relative paths to absolute before mounting:
```bash
if [[ "$path" != /* ]]; then
    path="$(pwd)/$path"
fi
```

The function uses full paths for system commands (`/bin/mkdir`, `/usr/local/bin/docker`) to avoid PATH issues on macOS and builds the Docker command dynamically using `eval` to properly handle optional volume mounts (like `.claude.json`).

### Port Mapping Support

The function accepts extra Docker arguments as a second parameter, enabling port mapping for web development:

```bash
claude-docker . "-p 3000:3000"
```

## Development Considerations

When modifying this project:

1. Changes to the Docker image require rebuilding with `docker build`
2. The container is ephemeral - removed after each session
3. The shell function uses `/usr/local/bin/docker` full path to avoid PATH issues on macOS
4. Volume mounts preserve project files and Neovim configuration between sessions
