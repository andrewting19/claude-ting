#!/bin/bash

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Dev Sessions Gateway - SSH Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "⚠️  This script is designed for macOS"
    echo "   For other systems, enable SSH server manually"
    exit 1
fi

# Enable Remote Login (SSH server)
echo "1. Checking SSH server status..."
REMOTE_LOGIN=$(sudo systemsetup -getremotelogin 2>/dev/null | grep -i "on" || echo "off")

if [[ "$REMOTE_LOGIN" == "off" ]]; then
    echo "   Enabling Remote Login (SSH server)..."
    sudo systemsetup -setremotelogin on
    echo "   ✓ SSH server enabled"
else
    echo "   ✓ SSH server already enabled"
fi

# Create .ssh directory if it doesn't exist
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Generate SSH key for gateway if it doesn't exist
echo ""
echo "2. Setting up SSH key for gateway..."
KEY_FILE=~/.ssh/claude_gateway

if [ -f "$KEY_FILE" ]; then
    echo "   ✓ SSH key already exists: $KEY_FILE"
else
    echo "   Generating new SSH key..."
    ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -C "claude-gateway"
    echo "   ✓ SSH key generated: $KEY_FILE"
fi

# Add public key to authorized_keys
echo ""
echo "3. Adding key to authorized_keys..."
AUTHORIZED_KEYS=~/.ssh/authorized_keys

# Create authorized_keys if it doesn't exist
if [ ! -f "$AUTHORIZED_KEYS" ]; then
    touch "$AUTHORIZED_KEYS"
    chmod 600 "$AUTHORIZED_KEYS"
fi

# Check if key is already authorized
if grep -q "claude-gateway" "$AUTHORIZED_KEYS" 2>/dev/null; then
    echo "   ✓ Key already authorized"
else
    cat "${KEY_FILE}.pub" >> "$AUTHORIZED_KEYS"
    chmod 600 "$AUTHORIZED_KEYS"
    echo "   ✓ Key added to authorized_keys"
fi

# Test SSH connection
echo ""
echo "4. Testing SSH connection..."
if ssh -o StrictHostKeyChecking=no -o BatchMode=yes -i "$KEY_FILE" localhost "echo 'SSH test successful'" 2>/dev/null; then
    echo "   ✓ SSH connection successful!"
else
    echo "   ⚠️  SSH connection test failed"
    echo "   This might be okay if SSH is still starting up"
fi

# Configure .zshenv for SSH PATH
echo ""
echo "5. Configuring ~/.zshenv for SSH sessions..."
if ! grep -q "/opt/homebrew/bin" ~/.zshenv 2>/dev/null; then
    echo "   Adding Homebrew paths to ~/.zshenv..."
    # Backup existing .zshenv if it exists
    if [ -f ~/.zshenv ]; then
        cp ~/.zshenv ~/.zshenv.backup
        echo "   (Backup saved to ~/.zshenv.backup)"
    fi
    # Add Homebrew paths at the beginning
    echo '# Homebrew paths (needed for SSH non-interactive sessions)' > ~/.zshenv.tmp
    echo 'export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"' >> ~/.zshenv.tmp
    echo '' >> ~/.zshenv.tmp
    # Append existing content if any
    if [ -f ~/.zshenv ]; then
        cat ~/.zshenv >> ~/.zshenv.tmp
    fi
    mv ~/.zshenv.tmp ~/.zshenv
    echo "   ✓ Updated ~/.zshenv with Homebrew paths"
else
    echo "   ✓ ~/.zshenv already has Homebrew paths"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Setup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "  • Run the full bootstrap script (recommended):"
echo "      ./dev-sessions/scripts/bootstrap-dev-sessions.sh"
echo ""
echo "  • Or perform the manual steps:"
echo "      1. cd dev-sessions/gateway && docker build -t dev-sessions-gateway ."
echo "      2. docker run -d --name dev-sessions-gateway \\"
echo "           -p 6767:6767 \\"
echo "           -v ~/.ssh/claude_gateway:/root/.ssh/id_ed25519:ro \\"
echo "           -v ~/dev-sessions-gateway.db:/data/sessions.db \\"
echo "           -e SSH_USER=\$USER \\"
echo "           dev-sessions-gateway"
echo "      3. cd dev-sessions/mcp && npm install && npm run build && npm link"
echo ""
