# CLAUDE.md

Guidance for running this repository with Claude Code or Codex CLIs inside the provided Docker setup.

## What This Repo Provides
- Containerized workflow so both CLIs run with no approval prompts (`--dangerously-skip-permissions` for Claude, `--dangerously-bypass-approvals-and-sandbox` for Codex), relying on Docker for isolation.
- Ubuntu 24.04 image with pyenv Python 3.12, nvm Node 22, Bun, uv, common dev tools (git, neovim, ripgrep, fd-find, bat, jq, htop, gh), and global installs of `@anthropic-ai/claude-code`, `@openai/codex`, and `dev-sessions-mcp`.
- Optional browser automation via Xvfb + Chromium + Playwright MCP (enable with `ENABLE_BROWSER=1`).
- Entry point `/entrypoint.sh` that merges host OAuth, injects MCP config, and optionally starts browser automation.

## Key Components
- `Dockerfile.ubuntu-dev`: Builds the toolchain above, sets `IS_SANDBOX=1`, installs dev-sessions-mcp, and ensures `/root/.claude` and `/root/.codex` exist. Entry point auto-adds a `dev-sessions` MCP block to both `~/.claude.json` and `~/.codex/config.toml`.
 - `setup-claude-codex.sh`: Adds zsh helpers `claude-docker`/`codex-docker` (aliases `clauded`/`codexed`) plus `claudedb` for browser-enabled mode. They:
  - Mount the target project to `/workspace` and set it as `-w`.
  - Mount `~/.local/share/nvim`, plus `~/.claude` or `~/.codex` for persistent auth/config.
  - Map Claude's per-project state dir (`~/.claude/projects/<sanitized-cwd>/...`) into Docker's `~/.claude/projects/-workspace` so auto-memory doesn't collide across projects.
  - Mount `~/.claude.json` read-only as `/root/.claude.host.json` for OAuth merging.
  - Pass `HOST_PATH` (for dev-sessions MCP) and `CODEX_HOME=/root/.codex`; forward `ANTHROPIC_API_KEY` if set; accept extra Docker args (ports, env vars).
- `dev-sessions/`: Gateway + MCP client for handoff workflows. Bootstrap via `dev-sessions/scripts/bootstrap-dev-sessions.sh`; sample MCP config in `sample-mcp-config.json`.

## Authentication Behavior
- Claude: If host `~/.claude.json` exists, entrypoint merges selected OAuth/user fields and sets `bypassPermissionsModeAccepted=true` into `/root/.claude.json`. `~/.claude` is mounted read/write; run `/login` inside the container if fresh. `ANTHROPIC_API_KEY` is passed through when exported on the host.
- Codex: `~/.codex` is mounted; entrypoint only creates `config.toml` with the `dev-sessions` MCP if it is missing. Gateway selection happens via `DEV_SESSIONS_GATEWAY_URL` env (default `http://host.docker.internal:6767`). Login once via `codex login` (or pipe `OPENAI_API_KEY` to `codex login --with-api-key`).
- GitHub CLI: `gh` is installed but not auto-authenticated. On macOS, `gh` commonly stores the token in Keychain (not in `~/.config/gh/hosts.yml`), so mounting `~/.config/gh` alone is often insufficient. Prefer forwarding `GH_TOKEN` into the container (the helper functions do this automatically by calling `gh auth token`), or export `GH_TOKEN` yourself.

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

## Skills (Optional)
This repo includes custom Claude Code skills for orchestration workflows. Install them to `~/.claude/skills/` by running:

```bash
./skills/install.sh
```

Or run `./setup-claude-codex.sh` which prompts for skill installation.

**Available skills:**
- `/architect` - Strategic orchestration mode. Understand codebase deeply, plan, delegate implementation to sub-agents, verify, cleanup.
- `/handoff` - Hand off work to a fresh dev session when context is running long. Creates a briefing and spawns a tmux session you can attach to.
- `/dev-control` - Orchestrate another dev session in real-time via polling. Send tasks, sleep, check progress, send follow-ups.

## Browser Automation (Optional)
Browser support is **disabled by default** to avoid token overhead from the Playwright MCP. Use `claudedb` for easy browser-enabled sessions:

```bash
claudedb                        # Current dir with browser
claudedb /path/to/project       # Specific path with browser
claudedb . "-p 9222:9222"       # With external CDP access
```

When enabled:
- Xvfb starts on `:99` (virtual display)
- Chromium launches with CDP on port 9222
- Playwright MCP is added to agent config (provides `browser_navigate`, `browser_click`, `browser_snapshot`, etc.)

The [Playwright MCP](https://github.com/microsoft/playwright-mcp) connects to the running Chromium via CDP and exposes browser control as tools. It uses the accessibility tree (not screenshots), making it fast and LLM-friendly.

### Manual browser control
You can also control the browser manually or via custom scripts:
- Run `start-browser` to launch Chromium with CDP (if not auto-started)
- **Raw CDP** via `websocket-client` (pre-installed):
```python
import websocket, json, base64
ws = websocket.create_connection("ws://127.0.0.1:9222/devtools/page/<TARGET_ID>")
ws.send(json.dumps({"id": 1, "method": "Page.captureScreenshot", "params": {"format": "png"}}))
result = json.loads(ws.recv())
# result["result"]["data"] is base64 PNG
```

## Maintenance Notes
- Rebuild with `rebuild.sh` for a no-cache build.
- Git is pre-configured system-wide (user/email set) and `safe.directory` is `*`.
- Containers are ephemeral; mounted directories (`/workspace`, `~/.claude`, `~/.codex`, `~/.local/share/nvim`) persist your changes and auth tokens.
