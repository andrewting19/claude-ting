#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_SESSIONS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
GATEWAY_DIR="${DEV_SESSIONS_ROOT}/gateway"
MCP_DIR="${DEV_SESSIONS_ROOT}/mcp"

SKIP_SSH=0
SKIP_GATEWAY=0
SKIP_MCP=0

print_usage() {
  cat <<'EOF'
Usage: ./dev-sessions/scripts/bootstrap-dev-sessions.sh [options]

Options:
  --skip-ssh-setup    Skip the macOS SSH setup helper (only if already configured)
  --skip-gateway      Skip building/starting the gateway container
  --skip-mcp          Skip building/linking the MCP client
  -h, --help          Show this help text
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-ssh-setup)
      SKIP_SSH=1
      shift
      ;;
    --skip-gateway)
      SKIP_GATEWAY=1
      shift
      ;;
    --skip-mcp)
      SKIP_MCP=1
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      print_usage
      exit 1
      ;;
  esac
done

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "❌ Missing dependency: $cmd"
    exit 1
  fi
}

check_node_version() {
  local version
  version="$(node -v | sed 's/v//')"
  local major="${version%%.*}"
  if [[ "$major" -lt 20 ]]; then
    echo "❌ Node.js 20+ is required. Found: v${version}"
    exit 1
  fi
}

ensure_mcp_config() {
  local config_dir="$HOME/.claude"
  local config_file="${config_dir}/config.json"
  local tmp_file="${config_file}.tmp"

  mkdir -p "$config_dir"

  if [[ ! -f "$config_file" ]]; then
    echo '{"mcpServers":{}}' > "$config_file"
  fi

  jq '.mcpServers = (.mcpServers // {}) |
      .mcpServers["dev-sessions"] = {
        "command": "dev-sessions-mcp",
        "env": { "GATEWAY_URL": "http://localhost:6767" }
      }' \
      "$config_file" > "$tmp_file"

  mv "$tmp_file" "$config_file"
  echo "✓ Ensured dev-sessions MCP entry in ${config_file}"
}

ensure_gateway_env() {
  local env_file="${GATEWAY_DIR}/.env"
  if [[ -f "$env_file" ]]; then
    echo "✓ Gateway .env already exists (${env_file})"
    return
  fi

  cat > "$env_file" <<EOF
SSH_USER=${SSH_USER:-$USER}
SSH_HOST=host.docker.internal
SSH_PORT=22
DEV_SESSIONS_GATEWAY_PORT=6767
MAX_SESSIONS_PER_CREATOR=10
CLAUDE_GATEWAY_SSH_KEY_PATH=$HOME/.ssh/claude_gateway
DEV_SESSIONS_DB_PATH=$HOME/dev-sessions-gateway.db
DEV_SESSIONS_GATEWAY_CONTAINER_NAME=dev-sessions-gateway
EOF

  echo "✓ Created gateway environment file at ${env_file}"
  echo "   (Edit this file if you need to customize ports, SSH host, or paths)"
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Dev Sessions Bootstrap"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

require_cmd docker
require_cmd tmux
require_cmd ssh
require_cmd node
require_cmd npm
require_cmd jq

if ! docker compose version >/dev/null 2>&1; then
  echo "❌ Docker Compose v2 is required (run 'docker compose version')."
  exit 1
fi

check_node_version

if [[ "$SKIP_SSH" -eq 0 ]]; then
  echo ""
  echo "→ Running SSH setup helper..."
  bash "${SCRIPT_DIR}/setup-gateway-ssh.sh"
else
  echo ""
  echo "↷ Skipping SSH setup helper (per flag)"
fi

if [[ ! -f "$HOME/.ssh/claude_gateway" ]]; then
  echo "❌ Expected SSH key at $HOME/.ssh/claude_gateway but it was not found."
  echo "   Re-run the setup helper or update the bootstrap script to point at your key."
  exit 1
fi

if [[ "$SKIP_GATEWAY" -eq 0 ]]; then
  echo ""
  echo "→ Preparing gateway environment..."
  ensure_gateway_env

  echo ""
  echo "→ Building and starting the gateway container..."
  (cd "$GATEWAY_DIR" && docker compose up -d --build)
else
  echo ""
  echo "↷ Skipping gateway build/start (per flag)"
fi

if [[ "$SKIP_MCP" -eq 0 ]]; then
  echo ""
  echo "→ Building and linking the dev-sessions MCP client..."
  (cd "$MCP_DIR" && npm install && npm run build && npm link)
  ensure_mcp_config
else
  echo ""
  echo "↷ Skipping MCP build/link (per flag)"
fi

echo ""
echo "✓ Bootstrap complete!"
gateway_status="$(docker ps --filter 'name=dev-sessions-gateway' --format '{{.Status}}')"
if [[ -z "$gateway_status" ]]; then
  gateway_status="not running"
fi

if command -v dev-sessions-mcp >/dev/null 2>&1; then
  mcp_path="$(command -v dev-sessions-mcp)"
else
  mcp_path="not linked"
fi

echo "- Gateway status: ${gateway_status}"
echo "- MCP command path: ${mcp_path}"
echo ""
echo "Next steps:"
echo "  1. Start Claude via 'clauded /path/to/workspace'"
echo "  2. Ask Claude to \"create a new dev session\" to verify MCP connectivity"
