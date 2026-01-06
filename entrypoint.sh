#!/bin/bash

# Conditionally start browser automation (set ENABLE_BROWSER=1 to activate)
if [ "$ENABLE_BROWSER" = "1" ]; then
  if ! pgrep -x "Xvfb" > /dev/null; then
    echo "✓ Starting Xvfb on display :99"
    Xvfb :99 -screen 0 1920x1080x24 &
    sleep 1
  fi

  # Start Chromium with CDP (uses start-browser script)
  start-browser
  sleep 2
fi

# Ensure the dev-sessions gateway hostname resolves from Docker
if [ -z "$DEV_SESSIONS_GATEWAY_URL" ]; then
  export DEV_SESSIONS_GATEWAY_URL="http://host.docker.internal:6767"
fi

# Merge Claude OAuth config from host file if available
if [ -f "/root/.claude.host.json" ]; then
  # Extract OAuth and user data from host config
  CONFIG_KEYS="oauthAccount hasSeenTasksHint userID hasCompletedOnboarding lastOnboardingVersion subscriptionNoticeCount hasAvailableSubscription s1mAccessCache mcpServers"

  # Build jq expression for extraction
  JQ_EXPR=""
  for key in $CONFIG_KEYS; do
    if [ -n "$JQ_EXPR" ]; then JQ_EXPR="$JQ_EXPR, "; fi
    JQ_EXPR="$JQ_EXPR\"$key\": .$key"
  done

  # Extract config data and add bypass permissions
  HOST_CONFIG=$(jq -c "{$JQ_EXPR, \"bypassPermissionsModeAccepted\": true}" /root/.claude.host.json 2>/dev/null || echo "")

  if [ -n "$HOST_CONFIG" ] && [ "$HOST_CONFIG" != "null" ] && [ "$HOST_CONFIG" != "{}" ]; then
    if [ -f "/root/.claude.json" ]; then
      # Merge with existing container file
      jq ". * $HOST_CONFIG" /root/.claude.json > /root/.claude.json.tmp && mv /root/.claude.json.tmp /root/.claude.json
      echo "✓ OAuth credentials merged from host"
    else
      # Create new container file with host config
      echo "$HOST_CONFIG" | jq . > /root/.claude.json
      echo "✓ OAuth credentials imported from host"
    fi
  fi
fi

# Ensure dev-sessions MCP is configured in ~/.claude.json
if [ -f "/root/.claude.json" ]; then
  jq --arg gateway "$DEV_SESSIONS_GATEWAY_URL" \
     '.mcpServers = (.mcpServers // {}) |
      .mcpServers["dev-sessions"] = {
        "type": "stdio",
        "command": "dev-sessions-mcp",
        "args": [],
        "env": {
          "GATEWAY_URL": $gateway
        }
      }' \
     /root/.claude.json > /root/.claude.json.tmp && mv /root/.claude.json.tmp /root/.claude.json
  echo "✓ Ensured dev-sessions MCP entry in ~/.claude.json"

  # Add Playwright MCP if browser is enabled
  if [ "$ENABLE_BROWSER" = "1" ]; then
    jq --arg cdp "ws://localhost:${CHROME_CDP_PORT:-9222}" \
       '.mcpServers["playwright"] = {
          "type": "stdio",
          "command": "npx",
          "args": ["@playwright/mcp", "--cdp-endpoint", $cdp],
          "env": {}
        }' \
       /root/.claude.json > /root/.claude.json.tmp && mv /root/.claude.json.tmp /root/.claude.json
    echo "✓ Added Playwright MCP (connecting to CDP on port ${CHROME_CDP_PORT:-9222})"
  fi
fi

# Ensure MCP configuration exists (gets overwritten by mount)
if [ ! -f "/root/.claude/config.json" ]; then
  echo "✓ Creating MCP configuration"
  cat > /root/.claude/config.json << 'MCPEOF'
{
  "mcpServers": {
    "dev-sessions": {
      "command": "dev-sessions-mcp",
      "env": {
        "GATEWAY_URL": "http://host.docker.internal:6767"
      }
    }
  }
}
MCPEOF
else
  # MCP config exists, ensure dev-sessions is configured
  if ! grep -q "dev-sessions" /root/.claude/config.json 2>/dev/null; then
    echo "✓ Adding dev-sessions MCP to existing config"
    # Merge dev-sessions into existing mcpServers
    jq '.mcpServers["dev-sessions"] = {"command": "dev-sessions-mcp", "env": {"GATEWAY_URL": "http://host.docker.internal:6767"}}' \
      /root/.claude/config.json > /root/.claude/config.json.tmp && \
      mv /root/.claude/config.json.tmp /root/.claude/config.json
  else
    echo "✓ MCP configuration already present"
  fi
fi

# Add Playwright MCP to config.json if browser is enabled
if [ "$ENABLE_BROWSER" = "1" ] && [ -f "/root/.claude/config.json" ]; then
  jq --arg cdp "ws://localhost:${CHROME_CDP_PORT:-9222}" \
     '.mcpServers["playwright"] = {
        "command": "npx",
        "args": ["@playwright/mcp", "--cdp-endpoint", $cdp]
      }' \
     /root/.claude/config.json > /root/.claude/config.json.tmp && \
     mv /root/.claude/config.json.tmp /root/.claude/config.json
  echo "✓ Added Playwright MCP to config.json"
fi

# Prepare Codex config in a shadow copy to avoid modifying host ~/.codex
ORIG_CODEX_HOME="${CODEX_HOME:-/root/.codex}"
SHADOW_CODEX_HOME="/tmp/codex-home"
mkdir -p "$SHADOW_CODEX_HOME"
# Copy existing files for baseline
if [ -d "$ORIG_CODEX_HOME" ] && [ "$(ls -A "$ORIG_CODEX_HOME" 2>/dev/null)" ]; then
  cp -a "$ORIG_CODEX_HOME"/. "$SHADOW_CODEX_HOME"/
fi
# Keep history and sessions persisted on host; symlink them into the shadow copy
mkdir -p "$ORIG_CODEX_HOME"
touch "$ORIG_CODEX_HOME/history.jsonl"
mkdir -p "$ORIG_CODEX_HOME/sessions"
ln -sf "$ORIG_CODEX_HOME/history.jsonl" "$SHADOW_CODEX_HOME/history.jsonl"
ln -snf "$ORIG_CODEX_HOME/sessions" "$SHADOW_CODEX_HOME/sessions"

export CODEX_HOME="$SHADOW_CODEX_HOME"
CODEX_CONFIG="$CODEX_HOME/config.toml"

if [ ! -f "$CODEX_CONFIG" ]; then
  cat > "$CODEX_CONFIG" << CODEXEOF
tool_output_token_limit = 25000

[features]
web_search_request = true
view_image_tool = true

[mcp_servers."dev-sessions"]
command = "dev-sessions-mcp"

[mcp_servers."dev-sessions".env]
GATEWAY_URL = "$DEV_SESSIONS_GATEWAY_URL"
CODEXEOF
  echo "✓ Created Codex config with dev-sessions MCP entry (shadow copy)"
else
  # Ensure dev-sessions gateway URL is correct inside the shadow copy
  export DEV_GATEWAY="$DEV_SESSIONS_GATEWAY_URL"
  python - <<'PY'
import os, re, pathlib

config_path = os.environ["CODEX_CONFIG"]
gateway = os.environ["DEV_GATEWAY"]

text = pathlib.Path(config_path).read_text(encoding="utf-8")

if '[mcp_servers."dev-sessions"]' not in text:
    text += f'\n[mcp_servers."dev-sessions"]\ncommand = "dev-sessions-mcp"\n'

if '[mcp_servers."dev-sessions".env]' not in text:
    text += f'\n[mcp_servers."dev-sessions".env]\nGATEWAY_URL = "{gateway}"\n'
else:
    pattern = r'(\[mcp_servers\."dev-sessions"\.env\][^\[]*)'
    def repl(match):
        block = match.group(1)
        if "GATEWAY_URL" in block:
            block = re.sub(r'GATEWAY_URL\s*=.*', f'GATEWAY_URL = "{gateway}"', block)
        else:
            block = block.rstrip() + f'\nGATEWAY_URL = "{gateway}"\n'
        return block
    text = re.sub(pattern, repl, text, count=1, flags=re.S)

pathlib.Path(config_path).write_text(text, encoding="utf-8")
PY
  echo "✓ Updated dev-sessions gateway URL in Codex config shadow copy"
fi

# Execute the command
exec "$@"
