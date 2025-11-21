# CLAUDE.md

Guidance for running this repository with Claude Code or Codex CLIs inside the provided Docker setup.

## What This Repo Provides
- Containerized workflow so both CLIs run with no approval prompts (`--dangerously-skip-permissions` for Claude, `--dangerously-bypass-approvals-and-sandbox` for Codex), relying on Docker for isolation.
- Ubuntu 24.04 image with pyenv Python 3.12, nvm Node 22, Bun, common dev tools (git, neovim, ripgrep, fd-find, bat, jq, htop), and global installs of `@anthropic-ai/claude-code`, `@openai/codex`, and `dev-sessions-mcp`.
- Entry point `/entrypoint.sh` that merges host OAuth, injects MCP config if missing, and sets `DEV_SESSIONS_GATEWAY_URL` (default `http://host.docker.internal:6767` at runtime).

## Key Components
- `Dockerfile.ubuntu-dev`: Builds the toolchain above, sets `IS_SANDBOX=1`, installs dev-sessions-mcp, and ensures `/root/.claude` and `/root/.codex` exist. Entry point auto-adds a `dev-sessions` MCP block to both `~/.claude.json` and `~/.codex/config.toml`.
 - `setup-claude-codex.sh`: Adds zsh helpers `claude-docker`/`codex-docker` (aliases `clauded`/`codexed`). They:
  - Mount the target project to `/workspace` and set it as `-w`.
  - Mount `~/.local/share/nvim`, plus `~/.claude` or `~/.codex` for persistent auth/config.
  - Mount `~/.claude.json` read-only as `/root/.claude.host.json` for OAuth merging.
  - Pass `HOST_PATH` (for dev-sessions MCP) and `CODEX_HOME=/root/.codex`; forward `ANTHROPIC_API_KEY` if set; accept extra Docker args (ports, env vars).
- `dev-sessions/`: Gateway + MCP client for handoff workflows. Bootstrap via `dev-sessions/scripts/bootstrap-dev-sessions.sh`; sample MCP config in `sample-mcp-config.json`.

## Authentication Behavior
- Claude: If host `~/.claude.json` exists, entrypoint merges selected OAuth/user fields and sets `bypassPermissionsModeAccepted=true` into `/root/.claude.json`. `~/.claude` is mounted read/write; run `/login` inside the container if fresh. `ANTHROPIC_API_KEY` is passed through when exported on the host.
- Codex: `~/.codex` is mounted; entrypoint only creates `config.toml` with the `dev-sessions` MCP if it is missing. Gateway selection happens via `DEV_SESSIONS_GATEWAY_URL` env (default `http://host.docker.internal:6767`). Login once via `codex login` (or pipe `OPENAI_API_KEY` to `codex login --with-api-key`).

## Typical Usage
```bash
# Build or rebuild the image
docker build -f Dockerfile.ubuntu-dev -t ubuntu-dev .

# Launch Claude
clauded                  # current dir
clauded /path/to/proj    # specific dir
clauded . "-p 3000:3000" # with port mapping

# Launch Codex
codexed
codexed /path/to/proj "-p 5173:5173 -e NODE_ENV=development"
```
Inside the container run `/login` (Claude) or `codex login` once to seed credentials.

## Dev-Sessions MCP Expectations
- `dev-sessions-mcp` is available in the image and auto-registered in both CLI configs.
- Gateway defaults to `host.docker.internal:6767` unless `DEV_SESSIONS_GATEWAY_URL` is set.
- `HOST_PATH` from the helper functions gives the MCP the correct workspace path.
- See `dev-sessions/README.md` for gateway details and tmux-based handoff flow.

## Maintenance Notes
- Rebuild with `rebuild.sh` for a no-cache build.
- Git is pre-configured system-wide (user/email set) and `safe.directory` is `*`.
- Containers are ephemeral; mounted directories (`/workspace`, `~/.claude`, `~/.codex`, `~/.local/share/nvim`) persist your changes and auth tokens.
