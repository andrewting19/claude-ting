# Quick Start - Dev Sessions

Bring up the Claude handoff system in just a few minutes.

## 1. Bootstrap Everything (≈3 minutes)

```bash
cd /Users/andrew/Documents/git_repos/claude-ting
./dev-sessions/scripts/bootstrap-dev-sessions.sh
```

What this does:
- Enables SSH + provisions the `~/.ssh/claude_gateway` key (macOS)
- Creates `dev-sessions/gateway/.env` with your paths
- Builds & launches the gateway via Docker Compose
- Builds + globally links the MCP client (`dev-sessions-mcp`)
- Ensures `~/.claude/config.json` references the dev-sessions MCP

Flags:
- `--skip-ssh-setup` (if you've already run it once)
- `--skip-gateway` or `--skip-mcp` to run individual pieces

Re-run the script any time; it is idempotent.

## 2. Smoke Test

```bash
# Start Claude in this repo (or any workspace)
clauded .
```

Inside Claude, ask:

```
Please use the create_dev_session tool to start a new session.
```

You should see a response similar to:
```
✓ Created dev session: riven-jg
Workspace: /Users/andrew/Documents/git_repos/claude-ting
```

Attach from another terminal:

```bash
tmux attach -t dev-riven-jg
```

You now have a second Claude running with the delegated context.

## Common Commands

```bash
# Check gateway status/logs
cd dev-sessions/gateway
docker compose ps
docker compose logs -f

# Restart gateway
docker compose restart

# Stop / start later
docker compose stop
docker compose start

# Legacy docker commands still work because the container is named dev-sessions-gateway
docker logs -f dev-sessions-gateway
docker start dev-sessions-gateway
docker stop dev-sessions-gateway
```

```bash
# List dev sessions on the host
tmux ls

# Kill a particular session
tmux kill-session -t dev-riven-jg
```

## Manual Steps (If You Prefer)

1. `./dev-sessions/scripts/setup-gateway-ssh.sh`
2. `cp dev-sessions/gateway/.env.example dev-sessions/gateway/.env` (edit values)
3. `cd dev-sessions/gateway && docker compose up -d --build`
4. `cd dev-sessions/mcp && npm install && npm run build && npm link`
5. `docker build -f Dockerfile.ubuntu-dev -t ubuntu-dev .`

## Troubleshooting

```bash
# Gateway isn’t healthy
cd dev-sessions/gateway
docker compose logs -f

# SSH fails
ssh -i ~/.ssh/claude_gateway localhost "echo test"

# Re-run the helper
./dev-sessions/scripts/setup-gateway-ssh.sh

# MCP binary missing inside Docker
docker run -it --rm ubuntu-dev which dev-sessions-mcp
```

## Want More Detail?

See [`dev-sessions/README.md`](./dev-sessions/README.md) for:
- Architecture diagrams
- Tool behavior and safety constraints
- Troubleshooting playbooks
- Future roadmap ideas
