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

Two authentication methods are supported: OAuth (recommended) and API key (optional).

### OAuth Authentication (Recommended)

OAuth credentials from your host machine are automatically synced to the container via an entrypoint script.

**How It Works:**
1. Host's `~/.claude.json` is mounted read-only as `/root/.claude.host.json`
2. Entrypoint script extracts OAuth tokens (`oauthAccount`, `userID`, etc.)
3. Credentials are merged into container's `/root/.claude.json` at startup
4. `~/.claude` directory is mounted read-write to persist authentication

**First-Time Setup:**
```bash
# Option 1: Authenticate on host (recommended)
claude auth login

# Option 2: Authenticate in container (first run only)
claude-docker .
# Inside container:
/login
```

Once authenticated, all future containers automatically have access.

### API Key Authentication (Optional)

If `ANTHROPIC_API_KEY` is set in your shell environment, it will be automatically passed through to the container. Useful for CI/CD or automated workflows.

## Common Commands

### Building and Rebuilding
```bash
# Build or rebuild the Docker image after changes
docker build -f Dockerfile.ubuntu-dev -t ubuntu-dev .
```

### Testing Changes
```bash
# Test the Docker container directly
docker run -it --rm -v "$(pwd):/workspace" -w /workspace ubuntu-dev /bin/bash

# Test with the shell function
source ~/.zshrc
claude-docker .
```

## Key Implementation Details

### Docker Configuration
- Base image: Ubuntu 24.04
- Working directory: `/workspace`
- Entrypoint script handles OAuth credential merging at startup
- Claude Code runs with `--dangerously-skip-permissions` flag due to container environment constraints

### Shell Function
The `claude-docker` function in `~/.zshrc` handles:
- **Path conversion**: Relative paths are converted to absolute before mounting
- **OAuth credential mounting**: `~/.claude.json` is mounted read-only as `/root/.claude.host.json`
- **Persistence**: `~/.claude` directory is mounted read-write for auth persistence
- **Full paths**: Uses `/usr/local/bin/docker` to avoid PATH issues on macOS

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
