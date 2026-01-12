# Claude Code Skills

Custom skills for orchestration workflows with Claude Code.

## Installation

```bash
./install.sh
```

This copies skills to `~/.claude/skills/`. Alternatively, run `./setup-claude-codex.sh` from the repo root which prompts for skill installation.

## Available Skills

### `/architect`

Strategic orchestration mode for complex tasks. Use when you want Claude to:
- Understand the codebase deeply before acting
- Plan and break work into discrete tasks
- Delegate implementation to sub-agents (via Task tool)
- Verify results and run cleanup passes

Key principle: Use your context for high-value strategic thinking, delegate mechanical implementation work.

### `/handoff`

Hand off work to a fresh dev session when context is running long. Instead of compacting (and losing nuance), this:
- Creates a comprehensive briefing with goals, state, relevant files, next steps
- Spawns a new dev session via the dev-sessions MCP
- The new agent reads the code, presents its understanding, and waits for you to attach and say "continue"

Requires: dev-sessions MCP running (see `dev-sessions/README.md`)

### `/dev-control`

Orchestrate another dev session in real-time without attaching. The control loop:
1. Create session / send task
2. Sleep (30-120s based on complexity)
3. Read output to check progress
4. Send follow-ups as needed
5. Repeat until complete

Different from `/handoff` - there you pass the baton, here you remain in control.

Requires: dev-sessions MCP running
