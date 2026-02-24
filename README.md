# Claude Docker Setup

> Run Claude Code **and** OpenAI Codex CLIs with **no permission prompts** in a secure Docker container — get 10x faster operations while keeping your Mac safe.

This repository provides a Docker-based setup for running Claude Code CLI (and now Codex CLI) in a containerized Ubuntu environment, enabling the `--dangerously-skip-permissions` / `--dangerously-bypass-approvals-and-sandbox` flags for dramatically faster, more flexible operation.

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

# Run with browser automation (Playwright MCP)
claudedb
```

That's it! Claude Code runs instantly without any permission dialogs.

```bash
# Run Codex in the current directory
codexed

# Trust a repo once, then run hands-free
codexed /path/to/my-project

# Same port-mapping / env passthrough support
codexed . "-p 3000:3000 -e NODE_ENV=development"
```

Codex launches with `--dangerously-bypass-approvals-and-sandbox` inside the same container, so you get the same "no prompt" workflow backed by Docker isolation.

## 🚀 Quickstart

### Prerequisites

- **macOS** (Intel or Apple Silicon)
- **Docker Desktop** installed and running
- **Claude account** for Claude CLI authentication
- **ChatGPT plan with Codex access** (Plus, Pro, Business, Edu, Enterprise) for the Codex CLI

### Host Setup (one-time)

Before using `clauded` or `codexed`, run these once on your Mac:

```bash
# Install dev-sessions globally
npm install -g dev-sessions

# Install the gateway as a system daemon (auto-starts on login)
dev-sessions gateway install

# Install skills for Claude and Codex
dev-sessions install-skill --global
```

> **macOS**: After running `gateway install`, it prints the path to the node binary. Grant that binary **Full Disk Access** in System Settings → Privacy & Security → Full Disk Access. This lets the gateway read Claude transcripts from `~/.claude/`.

### Installation (2 minutes)

1. **Clone and build**:
   ```bash
   git clone https://github.com/yourusername/claude-ting.git
   cd claude-ting
   docker build -f Dockerfile.ubuntu-dev -t ubuntu-dev .
   ```

2. **Add functions to your shell** (`~/.zshrc`):
   ```bash
   # Copy the claude-docker and codex-docker helpers from setup-claude-codex.sh
   # (or add them manually from the README)
   ```

3. **First-time authentication**:
   ```bash
   clauded
   # Inside container:
   /login
   # Follow the browser OAuth flow
   ```

   ```bash
   codexed
   # Inside container, run Codex login when prompted
   codex login
   ```

You're ready to go! Try `clauded` or `codexed` in any project directory.

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
   - Codex CLI (`@openai/codex`)
   - Entrypoint script for OAuth credential merging and default MCP config generation (creates `dev-sessions` block if missing; prefers runtime env `DEV_SESSIONS_GATEWAY_URL`, default `http://host.docker.internal:6767`)

2. **Shell Functions (`claude-docker`, `codex-docker`, `claudedb`)**: Zsh helpers that:
   - Accepts a path argument (defaults to current directory)
   - Converts relative paths to absolute paths
   - Mounts OAuth credentials from host for automatic authentication (`~/.claude` or `~/.codex`)
   - Passes `DEV_SESSIONS_GATEWAY_URL` (default `http://host.docker.internal:6767`) so MCP traffic hits the host gateway when running inside Docker
   - Launch the correct CLI with the "no approval" flags (`--dangerously-skip-permissions` for Claude, `--dangerously-bypass-approvals-and-sandbox` for Codex)
   - `claudedb` variant enables browser automation with Chromium + Playwright MCP

3. **Volume Mounts**:
   - Project directory → `/workspace` (working directory)
   - Neovim config → `/root/.local/share/nvim` (shared editor data)
   - Claude config → `~/.claude` directory (OAuth persistence)
   - Claude per-project state (auto-memory, etc.) → maps host `~/.claude/projects/<sanitized-cwd>/` into Docker's `~/.claude/projects/-workspace/` to avoid cross-project collisions
   - Host OAuth credentials → `/root/.claude.host.json` (read-only merge source)
   - Codex config → `~/.codex` directory (contains `auth.json`, `config.toml`, prompts, etc.)

## 📦 Installation Details

### System Requirements

| Requirement | Details |
|------------|----------|
| **OS** | macOS (Intel or Apple Silicon) |
| **Docker** | Docker Desktop for Mac |
| **Shell** | Zsh (default on macOS) |
| **Authentication** | Claude account (OAuth) or API key (optional), **and** a ChatGPT plan with Codex access for Codex CLI |

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

Swap `clauded` for `codexed` in the commands above to launch the Codex CLI with the exact same container mounts and environment.

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

All of these flags work identically with `codexed` if you prefer the Codex workflow.

### Browser Automation

Use `claudedb` to launch Claude with browser automation enabled. This starts Chromium with CDP (Chrome DevTools Protocol) and adds the Playwright MCP server:

```bash
# Current directory with browser
claudedb

# Specific project with browser
claudedb /path/to/project

# With external CDP access (for debugging)
claudedb . "-p 9222:9222"
```

When browser is enabled:
- Xvfb virtual display starts on `:99`
- Chromium launches with CDP on port 9222
- Playwright MCP provides tools: `browser_navigate`, `browser_click`, `browser_snapshot`, `browser_fill_form`, etc.

### Codex CLI workflow

- `codexed` launches `codex --dangerously-bypass-approvals-and-sandbox` (alias `--yolo`) so the CLI never asks for approvals. We rely on Docker for isolation, as recommended in the [Codex security guide](https://developers.openai.com/codex/security/).
- Codex stores credentials and config in `~/.codex`. The helper mounts your host directory at `/root/.codex`, so authenticate once via `codex login` (either locally or inside the container) and the resulting `auth.json` is reused for every run.
- The container entrypoint creates a minimal `~/.codex/config.toml` if it doesn't exist.
- Set `CODEX_HOME` on the host if you keep credentials elsewhere. The helper passes `CODEX_HOME=/root/.codex` inside the container so Codex always finds the mounted directory.

## 📁 Project Structure

```text
claude-ting/
├── Dockerfile.ubuntu-dev     # Ubuntu 24.04 + dev tools + Claude Code
├── setup-claude-codex.sh     # Shell function and auto-setup script
├── README.md                 # This documentation
└── CLAUDE.md                 # Instructions for Claude Code itself
```

## 🤖 Dev Sessions (Multi-Agent Handoff)

Claude and Codex containers have built-in support for spawning and communicating with other agent sessions via the [`dev-sessions`](https://www.npmjs.com/package/dev-sessions) CLI. This enables task delegation and parallel development workflows — one Claude can hand off work to another and monitor its progress.

**What it does:**
- Create new Claude Code or Codex sessions from within an existing session
- Send context/instructions to spawned sessions
- Read output from other sessions to monitor progress
- Automatic session tracking and cleanup

**Quick example:**
```
User: "Hand off the auth implementation to another Claude"
Claude: [uses /dev-sessions skill to create a session, sends context, returns tmux attach command]
```

The gateway daemon runs on your host machine and handles routing between containers and sessions. See [Host Setup](#host-setup-one-time) above to get it running.

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
| `--dangerously-bypass-approvals-and-sandbox` | Codex equivalent of the magic flag (only used by `codexed`) |

### IS_SANDBOX Environment Variable

The `IS_SANDBOX=1` environment variable is set in the Docker image to ensure Claude Code accepts the `--dangerously-skip-permissions` flag in the containerized environment.

### Authentication System

Two authentication methods are supported for Claude, and Codex has a very similar flow:

**Claude OAuth (Recommended)**
1. **First time**: Run `/login` inside `clauded`, authenticate via browser
2. **Tokens**: Saved to `~/.claude.json` on host
3. **Subsequent runs**: Entrypoint merges OAuth details into `/root/.claude.json`
4. **Result**: Seamless authentication across all containers

**Claude API Key (Optional)**
- Set `ANTHROPIC_API_KEY` environment variable on host
- Automatically passed through to container if present
- Useful for CI/CD or automated workflows

**Codex ChatGPT Login (Recommended)**
1. Run `codexed` and follow the CLI login prompt (`codex login`)
2. Credentials are stored in `~/.codex/auth.json` (or whatever `CODEX_HOME` points to)
3. Because that directory is mounted read/write, future `codexed` sessions automatically reuse the login

**Codex API key (Optional)**
- Follow the official guidance: `printenv OPENAI_API_KEY | codex login --with-api-key`
- The helper passes `OPENAI_API_KEY` into the container so you can forward the secret via STDIN even when running in Docker

## 🐛 Troubleshooting

### Common Issues

| Problem | Solution |
|---------|----------|
| **"docker: command not found"** | Install Docker Desktop and ensure it's running |
| **Authentication failed** | `clauded` → `/login`, `codexed` → `codex login` (or copy `~/.codex/auth.json`) |
| **Can't access files** | Check Docker Desktop file sharing permissions |
| **Port already in use** | Change the host port: `-p 3001:3000` |
| **MCP / dev-sessions unreachable** | Ensure `DEV_SESSIONS_GATEWAY_URL` is set to `http://host.docker.internal:6767` (default), rebuild the image, and re-source the helper so `codexed`/`clauded` pass it through |

### Debug Commands

```bash
# Check if OAuth credentials exist
ls -la ~/.claude.json

# Check if Codex auth exists
ls -la ~/.codex/auth.json

# Verify Claude auth status
clauded
# Inside container:
claude auth status

# Test container directly
docker run --rm ubuntu-dev claude --version

# Test Codex CLI
docker run --rm ubuntu-dev codex --version

# Verify MCP gateway DNS from inside the container (should resolve host.docker.internal)
docker run --rm ubuntu-dev getent hosts host.docker.internal
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
   source setup-claude-codex.sh
   ```

## 📝 Important Notes

- **Ephemeral containers**: Each session starts fresh (mounted files and OAuth credentials persist)
- **Project dependencies**: Install in your project, not the Docker image
- **Performance**: First build takes ~5 minutes; subsequent runs are instant
- **Security**: Container isolation protects your Mac from unintended changes
- **Codex MCP config**: The entrypoint auto-inserts the `dev-sessions` MCP block into `~/.codex/config.toml`. Delete or edit that block if you prefer a different configuration.

## 🤝 Contributing

Contributions welcome! Feel free to:
- Add more development tools to the Dockerfile
- Improve the setup script
- Share your use cases and configurations

## 📄 License

MIT License - Use freely in your projects


## Credit to this repo for auth hack: https://github.com/icanhasjonas/run-claude-docker/tree/main?tab=readme-ov-file#authentication-issues
