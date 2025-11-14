# Dev Sessions - Claude Handoff System

A powerful system for handing off tasks between Claude Code instances using tmux sessions.

## Quick Start

Already have the system set up? Here's how to use it:

```bash
# 1. Start the gateway (if not already running)
docker start dev-sessions-gateway

# 2. Start Claude in your project
clauded /path/to/your/project

# 3. From within Claude, create a dev session
# Claude will use the MCP tools automatically when you ask to:
# - "Create a new dev session for implementing auth"
# - "List active dev sessions"
# - "Send a message to session riven-jg"
```

If you haven't set up the system yet, continue reading the Setup Instructions below.

## Overview

This system allows a Claude Code instance to spawn and communicate with other Claude instances, enabling task delegation and parallel development workflows. It consists of three components:

1. **Gateway Server**: HTTP API server that manages tmux sessions via SSH
2. **MCP Client**: Model Context Protocol client that exposes dev session tools to Claude
3. **Updated Claude Docker**: Enhanced `clauded` command with MCP support

## Architecture

```
Claude Code Instance 1 (in Docker)
    ↓ (calls MCP tool)
MCP Client (stdio wrapper in container)
    ↓ (HTTP request to host.docker.internal:6767)
Gateway Server (Docker container)
    ↓ (SSH to host via host.docker.internal)
Host Machine - Creates tmux session
    ↓ (runs: clauded <workspace>)
Claude Code Instance 2 (new Docker container in tmux)
```

**Key Components:**
- Gateway uses `host.docker.internal` for Docker-to-host networking
- Sessions are created by running `clauded .` in tmux (not raw `claude`)
- MCP client requires `HOST_PATH` environment variable to pass workspace path
- Creator tracking uses tmux session names (or PID-based IDs for non-tmux sessions)

## Setup Instructions

### Prerequisites

- macOS (for SSH setup script)
- Docker installed
- Node.js 20+ installed on host (for MCP testing)
- tmux installed on host

### Step 1: Run SSH Setup

This enables SSH server on your Mac and creates SSH keys for the gateway:

```bash
cd setup-scripts
./setup-gateway-ssh.sh
```

This script:
- Enables Remote Login (SSH server) on macOS
- Generates SSH keys (`~/.ssh/claude_gateway`)
- Adds the key to `~/.ssh/authorized_keys`
- Configures `~/.zshenv` with Homebrew paths (required for SSH non-interactive sessions)
- Tests the SSH connection

**Why .zshenv?**
- SSH non-interactive sessions don't load `~/.zshrc`
- tmux needs access to commands like `clauded` which may be in Homebrew paths
- `.zshenv` is loaded for all shell sessions (interactive and non-interactive)

### Step 2: Build the Gateway Server

```bash
cd gateway-server
docker build -t dev-sessions-gateway .
```

### Step 3: Start the Gateway Server

```bash
docker run -d \
  --name dev-sessions-gateway \
  -p 6767:6767 \
  -v ~/.ssh/claude_gateway:/root/.ssh/id_ed25519:ro \
  -v ~/dev-sessions-gateway.db:/data/sessions.db \
  -e SSH_USER=$USER \
  -e MAX_SESSIONS_PER_CREATOR=10 \
  dev-sessions-gateway
```

**Environment Variables:**
- `SSH_USER`: Your username on the host machine (required)
- `MAX_SESSIONS_PER_CREATOR`: Maximum concurrent sessions per creator (default: 10)
- `PORT`: Gateway server port (default: 6767)

Check that it's running:

```bash
curl http://localhost:6767/health
# Should return: {"status":"healthy","timestamp":"..."}
```

### Step 4: Install MCP Client (Host)

For testing and host usage:

```bash
cd dev-sessions-mcp
npm install
npm run build
npm link
```

Verify installation:

```bash
which dev-sessions-mcp
# Should show: /usr/local/bin/dev-sessions-mcp
```

### Step 5: Build Claude Docker Image

Rebuild the ubuntu-dev image with MCP client installed:

```bash
docker build -f Dockerfile.ubuntu-dev -t ubuntu-dev .
```

### Step 6: Configure Claude Code MCP

Add the dev-sessions MCP to your Claude Code configuration.

**For Docker Claude** (already configured via Dockerfile):
The MCP is automatically available in the Docker container.

**For Host Claude** (optional):
Edit `~/.claude/config.json` and add:

```json
{
  "mcpServers": {
    "dev-sessions": {
      "command": "dev-sessions-mcp",
      "env": {
        "GATEWAY_URL": "http://localhost:6767"
      }
    }
  }
}
```

### Step 7: Reload Shell Config

```bash
source ~/.zshrc
```

## Usage

### Starting Claude with Dev Sessions

```bash
# Start Claude in your project directory
clauded /path/to/your/project
```

The `clauded` command now automatically:
- Passes `HOST_PATH` environment variable to the container (critical for dev sessions)
- Makes dev-sessions MCP available to Claude
- Mounts OAuth credentials from host (`~/.claude.json` → `/root/.claude.host.json`)
- Persists auth state via `~/.claude` directory mount
- Sets `DEV_SESSIONS_GATEWAY_URL` inside Docker so the MCP talks to the gateway via `host.docker.internal`

**Why HOST_PATH matters:**
- When you create a dev session from inside a container, the MCP client needs to know the *host* path, not the container path
- The container sees `/workspace`, but tmux on the host needs the actual path like `/Users/andrew/project`
- `clauded` automatically sets `HOST_PATH` to the host path before mounting it as `/workspace`

### Creating a Dev Session

From within Claude Code:

```
User: "I need to hand off the authentication implementation to another Claude instance"

Claude: "Let me create a new dev session for you"
[Calls create_dev_session tool]

Result: ✓ Created dev session: riven-jg
        To attach: tmux attach -t dev-riven-jg
```

### Sending Context to New Claude

```
Claude: "Let me send the context to the new Claude instance"
[Calls send_dev_message with sessionId="riven-jg"]

Message sent: ## Context

I've completed the database schema and API endpoints for user management.
Next steps are to implement the authentication middleware and JWT token
handling. The relevant files are:

- src/models/User.ts (completed)
- src/routes/auth.ts (needs implementation)
- src/middleware/auth.ts (needs creation)

Please review the existing code and implement the authentication system.
Let me know if you have any questions!
```

### Attaching to the New Claude

On your host terminal:

```bash
tmux attach -t dev-riven-jg
```

You'll see the new Claude instance with your context message already loaded!

### Listing Active Sessions

```
User: "What dev sessions are currently active?"

Claude: [Calls list_dev_sessions tool]

Found 2 dev session(s):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Session ID: riven-jg
Description: Implementing authentication system
Workspace: /Users/andrew/project
Status: active
Created: 2024-11-12T17:30:00.000Z
Attach: tmux attach -t dev-riven-jg
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Session ID: blitz-sup
Description: Refactoring database queries
Workspace: /Users/andrew/project
Status: active
Created: 2024-11-12T16:45:00.000Z
Attach: tmux attach -t dev-blitz-sup
```

**Note:** The `list_dev_sessions` tool automatically prunes (deletes) sessions whose tmux sessions no longer exist. This keeps the database clean and ensures you only see active sessions.

### Reading Session Output

```
Claude: [Calls read_dev_output with sessionId="riven-jg"]

Output from riven-jg (last 100 lines):
[Shows recent terminal output from that Claude instance]
```

## Available MCP Tools

Claude Code instances have access to these tools:

### `create_dev_session`

Creates a new Claude developer session in tmux.

**Parameters:**
- `description` (optional): Brief description of the session purpose

**Returns:**
- Session ID (e.g., "riven-jg")
- tmux session name (e.g., "dev-riven-jg")
- Attach command

**How it works:**
1. Generates unique champion-role session ID
2. Creates database entry with session metadata
3. Creates tmux session on host via SSH
4. Changes to workspace directory and runs `clauded .`
5. Waits 5 seconds for API key prompt to appear
6. Auto-dismisses prompt by sending Enter (uses OAuth credentials)
7. Returns session info to caller

**Validation:**
- `hostPath` must be absolute (start with `/`)
- Only allows alphanumeric, `/`, `-`, `_`, `.`, and spaces in paths
- Enforces rate limit per creator (default: 10 active sessions)

### `list_dev_sessions`

Lists all developer sessions created through this system.

**Parameters:**
- `status` (optional): Filter by "active" or "inactive"

**Returns:**
- List of sessions with metadata

### `send_dev_message`

Sends a message to another Claude instance.

**Parameters:**
- `sessionId` (required): Target session ID
- `message` (required): Message text

**Safety:**
- Verifies Claude is running before sending (checks for `claude` or `docker.*ubuntu-dev.*claude` processes)
- Uses literal mode (`tmux send-keys -l`) to prevent command injection
- Sends two Enter keys: first creates newline, second submits (required by Claude Code's input handling)

**Returns:**
- Success confirmation

**Error Handling:**
- Returns 404 if session doesn't exist
- Returns 404 and marks session inactive if tmux session no longer exists
- Throws error if Claude is not running (prevents accidental shell command execution)

### `read_dev_output`

Reads recent output from a dev session.

**Parameters:**
- `sessionId` (required): Target session ID
- `lines` (optional): Number of lines to read (default: 100, max: 1000)

**Returns:**
- Recent terminal output

## Session ID Format

Sessions are named using League of Legends champions + roles:
- Format: `{champion}-{role}`
- Examples: `riven-jg`, `blitz-adc`, `yasuo-mid`, `thresh-sup`
- Actual tmux names: `dev-{session-id}` (e.g., `dev-riven-jg`)
- Roles: `top`, `jg` (jungle), `mid`, `adc`, `sup` (support)

This makes sessions memorable and fun to reference!

**Champion Pool:** 145+ champions including:
- `ahri`, `akali`, `alistar`, `amumu`, `anivia`, `annie`, `ashe`, `azir`
- `bard`, `blitz`, `brand`, `braum`, `cait`, `camille`, etc.
- Full list in `gateway-server/src/champion-ids.ts`

**ID Generation:**
- Gateway generates random champion-role combinations
- Retries up to 10 times if collision occurs (extremely rare)
- Each combination is unique per active session

## Creator Tracking

The MCP client automatically tracks which session created new sessions:
- **If running in tmux:** Uses the tmux session name (with "dev-" prefix stripped)
  - Example: Session `dev-fizz-top` creates sessions with creator ID `fizz-top`
- **If not in tmux:** Generates a deterministic champion-role ID based on process ID
  - Example: PID 12345 might get creator ID `riven-jg`
- **Rate limiting:** Each creator can have max 10 active sessions (configurable via `MAX_SESSIONS_PER_CREATOR`)

## Troubleshooting

### Gateway server not accessible

```bash
# Check if gateway is running
docker ps | grep dev-sessions-gateway

# Check gateway logs
docker logs dev-sessions-gateway

# Test gateway health
curl http://localhost:6767/health
```

### SSH connection fails

```bash
# Test SSH manually
ssh -i ~/.ssh/claude_gateway localhost "echo test"

# Check SSH server status
sudo systemsetup -getremotelogin

# Re-run setup if needed
./setup-scripts/setup-gateway-ssh.sh
```

### MCP not available in Claude

```bash
# Verify MCP is installed in Docker
docker run -it --rm ubuntu-dev which dev-sessions-mcp

# Check Claude config
cat ~/.claude/config.json

# Rebuild Docker image if needed
docker build -f Dockerfile.ubuntu-dev -t ubuntu-dev .
```

### Session creation fails

```bash
# Check if tmux is installed on host
which tmux

# Check gateway logs for errors
docker logs dev-sessions-gateway -f

# Verify SSH keys are mounted correctly
docker exec dev-sessions-gateway ls -la /root/.ssh/
```

### HOST_PATH not set error

If you see `HOST_PATH not set, using current directory` in the logs:

**Problem:** The `clauded` command is not passing the `HOST_PATH` environment variable.

**Solution:**
1. Check that you're using the updated `claude-docker` function in `~/.zshrc`
2. Reload your shell config: `source ~/.zshrc`
3. Verify the function includes: `-e HOST_PATH="$path"`
4. Make sure you're calling `clauded /path/to/project`, not raw `docker run`

**Alternative (testing):** Manually set HOST_PATH when running Docker:
```bash
docker run -it --rm \
  -e HOST_PATH="$(pwd)" \
  -v "$(pwd):/workspace" \
  -w /workspace \
  ubuntu-dev
```

### Created session opens in wrong directory

**Problem:** The new Claude session opens in a different directory than expected.

**Symptoms:** Session is created but runs `clauded` in the wrong workspace.

**Cause:** The `HOST_PATH` environment variable contains the container path `/workspace` instead of the actual host path.

**Solution:** Ensure the `clauded` function sets `HOST_PATH` to the absolute host path *before* mounting to `/workspace`.

## Database

The gateway server uses SQLite to track session metadata:

**Location:** `~/dev-sessions-gateway.db`

**Schema:**
```sql
CREATE TABLE dev_sessions (
  session_id TEXT PRIMARY KEY,
  tmux_session_name TEXT NOT NULL UNIQUE,
  description TEXT NOT NULL,
  creator TEXT NOT NULL,
  workspace_path TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  last_used INTEGER NOT NULL,
  status TEXT CHECK(status IN ('active', 'inactive'))
);

CREATE INDEX idx_status ON dev_sessions(status);
CREATE INDEX idx_created_at ON dev_sessions(created_at DESC);
```

**Auto-Pruning:**
- On gateway startup: Deletes sessions whose tmux sessions no longer exist
- On `list_dev_sessions` calls: Prunes stale sessions before returning results
- On `send_dev_message` and `read_dev_output`: Marks session inactive if tmux session doesn't exist
- Keeps database synchronized with actual tmux state

## Stopping the Gateway

```bash
docker stop dev-sessions-gateway
docker rm dev-sessions-gateway
```

## Starting Gateway on System Boot (Optional)

To have the gateway start automatically:

```bash
docker update --restart unless-stopped dev-sessions-gateway
```

## Security Notes

1. **SSH Keys**: Gateway has read-only access to SSH private key
2. **Limited Scope**: Gateway can only create tmux sessions running `clauded`
3. **Process Verification**: Messages only sent when Claude is confirmed running
4. **Literal Mode**: All text sent literally (no command interpretation)
5. **Database Isolation**: Session tracking isolated to gateway's SQLite DB

## Gateway API Reference

The gateway server exposes these HTTP endpoints:

### `POST /create-session`
Creates a new tmux session running Claude Code.

**Request:**
```json
{
  "hostPath": "/Users/andrew/project",
  "description": "Implementing auth system",
  "creator": "riven-jg"
}
```

**Response:**
```json
{
  "sessionId": "fizz-top",
  "tmuxSessionName": "dev-fizz-top",
  "workspacePath": "/Users/andrew/project",
  "message": "Dev session created. Attach with: tmux attach -t dev-fizz-top"
}
```

### `GET /list-sessions`
Lists all dev sessions (auto-prunes stale sessions).

**Response:**
```json
{
  "sessions": [
    {
      "sessionId": "fizz-top",
      "tmuxSessionName": "dev-fizz-top",
      "description": "Implementing auth system",
      "creator": "riven-jg",
      "workspacePath": "/Users/andrew/project",
      "createdAt": "2024-11-12T17:30:00.000Z",
      "lastUsed": "2024-11-12T17:35:00.000Z",
      "status": "active"
    }
  ]
}
```

### `POST /send-message`
Sends a message to a Claude session.

**Request:**
```json
{
  "sessionId": "fizz-top",
  "message": "Please implement the login endpoint"
}
```

**Response:**
```json
{
  "success": true,
  "sessionId": "fizz-top",
  "message": "Message sent successfully"
}
```

### `GET /read-output?sessionId=fizz-top&lines=100`
Reads recent terminal output from a session.

**Response:**
```json
{
  "sessionId": "fizz-top",
  "output": "...(terminal output)...",
  "lines": 100
}
```

### `GET /health`
Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-11-12T17:30:00.000Z"
}
```

## Dependencies

**Gateway Server:**
- Node.js 20+
- Express.js 4.18
- better-sqlite3 9.2
- TypeScript 5.3

**MCP Client:**
- Node.js 20+
- @modelcontextprotocol/sdk 0.6.0
- TypeScript 5.3

**Host Requirements:**
- tmux
- SSH server (Remote Login on macOS)
- Docker

## Future Enhancements

Potential improvements:
- Session tags/categories
- Inter-session communication (Claude-to-Claude chat)
- Web UI for session management
- Session recording/playback
- Resource usage monitoring
- Configurable session TTL (time-to-live)
- Session pause/resume functionality

## License

MIT
