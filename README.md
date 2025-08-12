# Claude Docker Setup

> Run Claude Code CLI with **no permission prompts** in a secure Docker container — get 10x faster operations while keeping your Mac safe.

This repository provides a Docker-based setup for running Claude Code CLI in a containerized Ubuntu environment, enabling the `--dangerously-skip-permissions` flag for dramatically faster, more flexible operation.

## ✨ Benefits

### 🚀 **10x Faster Operations**
Claude Code runs with `--dangerously-skip-permissions` in the container:
- **No permission prompts** — operations execute immediately
- **Unrestricted file access** — Claude can read, write, and modify without asking
- **Batch operations** — perform hundreds of file changes without interruption

### 🔒 **Complete Safety**
- **Container isolation** protects your Mac from unintended changes
- **Volume mounting** gives access only to specified project directories
- **Non-root user** runs with limited privileges inside the container

### 🛠️ **Professional Development Environment**
- **Ubuntu 24.04** with essential dev tools pre-installed
- **Languages included**: Python 3, Node.js, npm
- **Tools included**: git, vim, neovim, ripgrep, fd-find, bat, jq, htop
- **Consistent environment** across all your projects

## 🎯 Quick Example

```bash
# Run Claude in current directory
clauded

# Run Claude in a specific project
clauded /path/to/my-project

# Develop a web app with port mapping
clauded . "-p 3000:3000"
```

That's it! Claude Code runs instantly without any permission dialogs.

## 🚀 Quickstart

### Prerequisites

- **macOS** (Intel or Apple Silicon)
- **Docker Desktop** installed and running
- **Anthropic API key** as `ANTHROPIC_API_KEY` environment variable

### Installation (2 minutes)

1. **Clone and setup**:
   ```bash
   git clone https://github.com/yourusername/claude-ting.git
   cd claude-ting
   source setup-claude-docker.sh
   ```

2. **Add to your shell** (`~/.zprofile` or `~/.zshrc`):
   ```bash
   source /path/to/claude-ting/setup-claude-docker.sh
   ```

3. **Reload shell**:
   ```bash
   source ~/.zprofile
   ```

You're ready to go! Try `clauded` in any project directory.

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

## 📦 Installation Details

### System Requirements

| Requirement | Details |
|------------|----------|
| **OS** | macOS (Intel or Apple Silicon) |
| **Docker** | Docker Desktop for Mac |
| **Shell** | Zsh (default on macOS) |
| **API Key** | `ANTHROPIC_API_KEY` environment variable |
| **Claude Config** | Optional: existing `~/.claude` directory |

### Manual Setup

If the quickstart script doesn't work for your setup:

1. **Build the Docker image**:
   ```bash
   docker build -f Dockerfile.ubuntu-dev -t ubuntu-dev .
   ```

2. **Add the shell function to `~/.zprofile`**:
   ```bash
   # Copy the claude-docker function from setup-claude-docker.sh
   # or source the file directly:
   source /path/to/claude-ting/setup-claude-docker.sh
   ```

3. **Configure API authentication** (if needed):
   ```bash
   # Create helper script
   mkdir -p ~/.claude
   echo '#!/bin/bash\necho "$ANTHROPIC_API_KEY"' > ~/.claude/anthropic_key.sh
   chmod +x ~/.claude/anthropic_key.sh
   
   # Create settings file
   echo '{"apiKeyHelper": "~/.claude/anthropic_key.sh"}' > ~/.claude/settings.json
   ```

## 💻 Usage Guide

### Basic Commands

```bash
# Run Claude in current directory
clauded

# Run Claude in a specific project
clauded /path/to/project

# Use relative paths
clauded ../other-project
```

### Web Development

For web apps, map ports to access them from your browser:

```bash
# Single port
clauded . "-p 3000:3000"

# Multiple ports (e.g., app + Vite)
clauded . "-p 3000:3000 -p 5173:5173"

# With environment variables
clauded . "-p 8080:8080 -e NODE_ENV=development"
```

**Port mapping format**: `-p HOST:CONTAINER` (e.g., `-p 3000:3000` makes `localhost:3000` work)

## 📁 Project Structure

```text
claude-ting/
├── Dockerfile.ubuntu-dev     # Ubuntu 24.04 + dev tools + Claude Code
├── setup-claude-docker.sh    # Shell function and auto-setup script
├── README.md                 # This documentation
└── CLAUDE.md                 # Instructions for Claude Code itself
```

## 🔧 Technical Details

### Docker Command Breakdown

| Flag | Purpose |
|------|------|
| `-it` | Interactive terminal for Claude's UI |
| `--rm` | Auto-cleanup after exit |
| `--user dev` | Non-root for security |
| `-v $path:/home/dev/workspace` | Mount your project |
| `-e ANTHROPIC_API_KEY` | Pass API key |
| `-v ~/.claude:/home/dev/.claude` | Claude configuration |
| `--dangerously-skip-permissions` | **The magic flag** — no prompts! |

### IS_SANDBOX Environment Variable

**Important**: The `IS_SANDBOX=true` environment variable is required when running Claude Code with `--dangerously-skip-permissions` while having root/sudo access in the container. This is automatically set in the Docker image to ensure Claude Code accepts the flag in the containerized environment.

### Authentication System

Since OAuth doesn't work in containers, we use Claude's API helper method:

1. **Host**: `ANTHROPIC_API_KEY` environment variable
2. **Container**: Helper script at `~/.claude/anthropic_key.sh`
3. **Claude**: Reads API key via helper script
4. **Result**: Seamless authentication without browser

**Note on Authentication Methods**: Claude may display a warning about "conflicting authentication methods" because both the `ANTHROPIC_API_KEY` environment variable and the API helper script are present. This warning is harmless since both methods use the same API key. The key difference is:
- **Direct environment variable**: Requires manual confirmation (y/n) during Docker build
- **API helper script**: Works automatically without user interaction

We use the helper script approach for a smoother experience. The environment variable could be renamed to avoid the warning, but since it doesn't affect functionality, we keep the standard `ANTHROPIC_API_KEY` name for simplicity.

## 🐛 Troubleshooting

### Common Issues

| Problem | Solution |
|---------|----------|
| **"docker: command not found"** | Install Docker Desktop and ensure it's running |
| **"Missing API key"** | Export `ANTHROPIC_API_KEY` in your shell profile |
| **Can't access files** | Check Docker Desktop file sharing permissions |
| **Port already in use** | Change the host port: `-p 3001:3000` |

### Debug Commands

```bash
# Check API key
echo $ANTHROPIC_API_KEY

# Test helper script
~/.claude/anthropic_key.sh

# Verify Claude settings
cat ~/.claude/settings.json

# Test container directly
docker run --rm ubuntu-dev claude --version
```

## 🔄 Updating

### Update Claude Code or tools:

1. Edit `Dockerfile.ubuntu-dev`
2. Rebuild:
   ```bash
   docker build -f Dockerfile.ubuntu-dev -t ubuntu-dev .
   ```

### Update the shell function:

1. Pull latest changes
2. Source the setup script again:
   ```bash
   source setup-claude-docker.sh
   ```

## 📝 Important Notes

- **Ephemeral containers**: Each session starts fresh (only mounted files persist)
- **Project dependencies**: Install in your project, not the Docker image
- **Performance**: First run pulls the image; subsequent runs are instant
- **Security**: Container runs as non-root user with limited system access

## 🤝 Contributing

Contributions welcome! Feel free to:
- Add more development tools to the Dockerfile
- Improve the setup script
- Share your use cases and configurations

## 📄 License

MIT License - Use freely in your projects
