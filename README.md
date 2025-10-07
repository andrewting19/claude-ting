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
- **Ephemeral environment** resets between sessions

### 🛠️ **Professional Development Environment**
- **Ubuntu 24.04** with essential dev tools pre-installed
- **Languages included**: Python 3.12, Node.js 22, Bun
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
- **Claude account** for authentication

### Installation (2 minutes)

1. **Clone and build**:
   ```bash
   git clone https://github.com/yourusername/claude-ting.git
   cd claude-ting
   docker build -f Dockerfile.ubuntu-dev -t ubuntu-dev .
   ```

2. **Add function to your shell** (`~/.zshrc`):
   ```bash
   # Copy the claude-docker function from setup-claude-docker.sh
   # or add it manually (see CLAUDE.md for the function code)
   ```

3. **First-time authentication**:
   ```bash
   clauded
   # Inside container:
   /login
   # Follow the browser OAuth flow
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
   - Programming languages (Python 3.12, Node.js 22, Bun)
   - Utilities (ripgrep, fd-find, bat, jq, htop)
   - Claude Code CLI (`@anthropic-ai/claude-code`)
   - Entrypoint script for OAuth credential merging

2. **Shell Function (`claude-docker`)**: A Zsh function that:
   - Accepts a path argument (defaults to current directory)
   - Converts relative paths to absolute paths
   - Mounts OAuth credentials from host for automatic authentication
   - Passes through to Claude with `--dangerously-skip-permissions` flag

3. **Volume Mounts**:
   - Project directory → `/workspace` (working directory)
   - Neovim config → `/root/.local/share/nvim` (shared editor data)
   - Claude config → `~/.claude` directory (OAuth persistence)
   - Host OAuth credentials → `/root/.claude.host.json` (read-only merge source)

## 📦 Installation Details

### System Requirements

| Requirement | Details |
|------------|----------|
| **OS** | macOS (Intel or Apple Silicon) |
| **Docker** | Docker Desktop for Mac |
| **Shell** | Zsh (default on macOS) |
| **Authentication** | Claude account (OAuth) or API key (optional) |

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
| `-v $path:/workspace` | Mount your project |
| `-v ~/.claude.json:/root/.claude.host.json:ro` | OAuth credential source (read-only) |
| `-v ~/.claude:/root/.claude` | Claude configuration (persistent) |
| `--dangerously-skip-permissions` | **The magic flag** — no prompts! |

### IS_SANDBOX Environment Variable

The `IS_SANDBOX=1` environment variable is set in the Docker image to ensure Claude Code accepts the `--dangerously-skip-permissions` flag in the containerized environment.

### Authentication System

Two authentication methods are supported:

**OAuth (Recommended)**
1. **First time**: Run `/login` inside container, authenticate via browser
2. **OAuth tokens**: Saved to `~/.claude.json` on host
3. **Subsequent runs**: Entrypoint script merges OAuth credentials into container
4. **Result**: Seamless authentication across all containers

**API Key (Optional)**
- Set `ANTHROPIC_API_KEY` environment variable on host
- Automatically passed through to container if present
- Useful for CI/CD or automated workflows

## 🐛 Troubleshooting

### Common Issues

| Problem | Solution |
|---------|----------|
| **"docker: command not found"** | Install Docker Desktop and ensure it's running |
| **Authentication failed** | Run `clauded` then `/login` inside container |
| **Can't access files** | Check Docker Desktop file sharing permissions |
| **Port already in use** | Change the host port: `-p 3001:3000` |

### Debug Commands

```bash
# Check if OAuth credentials exist
ls -la ~/.claude.json

# Verify Claude auth status
clauded
# Inside container:
claude auth status

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

- **Ephemeral containers**: Each session starts fresh (mounted files and OAuth credentials persist)
- **Project dependencies**: Install in your project, not the Docker image
- **Performance**: First build takes ~5 minutes; subsequent runs are instant
- **Security**: Container isolation protects your Mac from unintended changes

## 🤝 Contributing

Contributions welcome! Feel free to:
- Add more development tools to the Dockerfile
- Improve the setup script
- Share your use cases and configurations

## 📄 License

MIT License - Use freely in your projects


## Credit to this repo for auth hack: https://github.com/icanhasjonas/run-claude-docker/tree/main?tab=readme-ov-file#authentication-issues