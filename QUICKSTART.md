# Quick Start

Get Claude and Codex running in Docker containers in just a few minutes.

## Host Setup (one-time, on your Mac)

Before using `clauded` or `codexed`, run these once on your host machine:

```bash
# Install dev-sessions globally
npm install -g dev-sessions

# Install the gateway as a system daemon (auto-starts on login)
dev-sessions gateway install

# Install skills for Claude and Codex
dev-sessions install-skill --global
```

> **macOS**: After running `gateway install`, it will print the path to the node binary. Grant that binary **Full Disk Access** in System Settings → Privacy & Security → Full Disk Access. This lets the gateway read Claude transcripts from `~/.claude/`.

## 1. Build the Docker Image (≈3 minutes)

```bash
cd /Users/andrew/Documents/git_repos/claude-ting
docker build -f Dockerfile.ubuntu-dev -t ubuntu-dev .
```

## 2. Add Shell Functions

```bash
# Add to your ~/.zshrc (or run the setup script)
source setup-claude-codex.sh
```

## 3. Smoke Test

```bash
# Start Claude in this repo (or any workspace)
clauded .
```

Inside Claude, try delegating a task:

```
Please use the /dev-sessions skill to start a new session and hand off a task.
```

You should see a response like:
```
✓ Created dev session: riven-jg
Workspace: /path/to/your/project
```

Attach from another terminal:

```bash
tmux attach -t dev-riven-jg
```

You now have a second Claude running with the delegated context.

## Common Commands

```bash
# List active dev sessions
dev-sessions list

# Check gateway status
dev-sessions gateway status

# Kill a session
dev-sessions kill riven-jg
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| **Gateway unreachable** | Run `dev-sessions gateway status`; if not running, `dev-sessions gateway install` |
| **Full Disk Access** | macOS only — grant the node binary FDA in System Settings → Privacy & Security |
| **Auth failed** | `clauded` → `/login`, `codexed` → `codex login` |
| **Port conflict** | Set `DEV_SESSIONS_GATEWAY_PORT=<port>` before `gateway install` |

## Want More Detail?

See [`README.md`](./README.md) for architecture, volume mounts, and advanced usage.
