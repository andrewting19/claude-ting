# Quick Start - Dev Sessions

Get the Claude handoff system running in 5 minutes.

## 1. Setup SSH (30 seconds)

```bash
cd /Users/andrew/Documents/git_repos/claude-ting/setup-scripts
./setup-gateway-ssh.sh
```

Follow the prompts. This enables SSH and creates keys.

## 2. Build & Start Gateway (2 minutes)

```bash
cd /Users/andrew/Documents/git_repos/claude-ting/gateway-server

# Build the gateway Docker image
docker build -t dev-sessions-gateway .

# Start the gateway server
docker run -d \
  --name dev-sessions-gateway \
  -p 3000:3000 \
  -v ~/.ssh/claude_gateway:/root/.ssh/id_ed25519:ro \
  -v ~/dev-sessions-gateway.db:/data/sessions.db \
  -e SSH_USER=$USER \
  dev-sessions-gateway

# Verify it's running
curl http://localhost:3000/health
```

You should see: `{"status":"healthy","timestamp":"..."}`

## 3. Install MCP Client on Host (1 minute)

```bash
cd /Users/andrew/Documents/git_repos/claude-ting/dev-sessions-mcp

npm install
npm run build
npm link
```

Verify: `which dev-sessions-mcp` should show `/usr/local/bin/dev-sessions-mcp`

## 4. Rebuild Claude Docker Image (2 minutes)

```bash
cd /Users/andrew/Documents/git_repos/claude-ting

docker build -f Dockerfile.ubuntu-dev -t ubuntu-dev .
```

## 5. Reload Shell

```bash
source ~/.zshrc
```

## 6. Test It!

```bash
# Start Claude in this repo
clauded .
```

Inside Claude, try:

```
Hey Claude! Can you use the create_dev_session tool to create a new dev session?
```

Claude should:
1. Call the `create_dev_session` tool
2. Return a session ID like "riven-jg"
3. Tell you how to attach: `tmux attach -t dev-riven-jg`

Then try attaching in a new terminal:

```bash
tmux attach -t dev-riven-jg
```

You should see a new Claude instance running!

## Common Commands

**Start gateway:**
```bash
docker start dev-sessions-gateway
```

**Stop gateway:**
```bash
docker stop dev-sessions-gateway
```

**View gateway logs:**
```bash
docker logs -f dev-sessions-gateway
```

**List tmux sessions:**
```bash
tmux ls
```

**Kill a tmux session:**
```bash
tmux kill-session -t dev-riven-jg
```

## Troubleshooting

**Gateway health check fails:**
```bash
docker logs dev-sessions-gateway
# Look for errors
```

**SSH issues:**
```bash
ssh -i ~/.ssh/claude_gateway localhost "echo test"
# Should print "test"
```

**MCP not found in Docker:**
```bash
docker run -it --rm ubuntu-dev which dev-sessions-mcp
# Should show path
```

## What's Next?

See [DEV_SESSIONS_README.md](./DEV_SESSIONS_README.md) for:
- Detailed usage examples
- All available MCP tools
- Architecture explanation
- Advanced troubleshooting

## Quick Example: Handoff Workflow

1. **In Claude 1:**
   ```
   User: "I need to hand off implementing the API tests to another Claude"

   Claude: [Creates session "yasuo-mid"]
   Claude: [Sends context message about what needs testing]
   ```

2. **In your terminal:**
   ```bash
   tmux attach -t dev-yasuo-mid
   ```

3. **You see Claude 2 with the context loaded!**

That's it! You're ready to delegate tasks between Claude instances.
