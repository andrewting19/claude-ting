#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { execSync } from 'child_process';

/**
 * Gateway server URL
 * - DEV_SESSIONS_GATEWAY_URL is a docker-specific override so we don't have to edit host config
 * - Otherwise defer to the value provided by Claude's MCP config (GATEWAY_URL)
 * - Finally fall back to host.docker.internal so containers work out-of-the-box
 */
const GATEWAY_URL =
  process.env.DEV_SESSIONS_GATEWAY_URL ||
  process.env.GATEWAY_URL ||
  'http://host.docker.internal:6767';

/**
 * League of Legends champion names and roles for generating creator IDs
 */
const CHAMPIONS = [
  'ahri', 'akali', 'alistar', 'amumu', 'anivia', 'annie', 'ashe', 'azir',
  'bard', 'blitz', 'brand', 'braum', 'cait', 'camille', 'cass', 'chogath',
  'corki', 'darius', 'diana', 'draven', 'mundo', 'ekko', 'elise', 'evelynn',
  'ezreal', 'fiddle', 'fiora', 'fizz', 'galio', 'garen', 'gnar', 'gragas',
  'graves', 'hecarim', 'heimer', 'illaoi', 'irelia', 'ivern', 'janna', 'jarvan',
  'jax', 'jayce', 'jhin', 'jinx', 'kaisa', 'kalista', 'karma', 'karthus',
  'kassadin', 'kata', 'kayle', 'kayn', 'kennen', 'khazix', 'kindred', 'kled',
  'kogmaw', 'leblanc', 'lee', 'leona', 'lissandra', 'lucian', 'lulu', 'lux',
  'malph', 'malz', 'mao', 'master-yi', 'mf', 'morgana', 'nami', 'nasus',
  'nautilus', 'neeko', 'nidalee', 'nocturne', 'nunu', 'olaf', 'orianna', 'ornn',
  'pantheon', 'poppy', 'pyke', 'qiyana', 'quinn', 'rakan', 'rammus', 'reksai',
  'renekton', 'rengar', 'riven', 'rumble', 'ryze', 'sejuani', 'senna', 'sett',
  'shaco', 'shen', 'shyvana', 'singed', 'sion', 'sivir', 'skarner', 'sona',
  'soraka', 'swain', 'sylas', 'syndra', 'tahm', 'taliyah', 'talon', 'taric',
  'teemo', 'thresh', 'tristana', 'trundle', 'tryndamere', 'tf', 'twitch', 'udyr',
  'urgot', 'varus', 'vayne', 'veigar', 'velkoz', 'vi', 'viego', 'viktor',
  'vladimir', 'volibear', 'warwick', 'wukong', 'xayah', 'xerath', 'xin',
  'yasuo', 'yone', 'yorick', 'yuumi', 'zac', 'zed', 'zeri', 'ziggs',
  'zilean', 'zoe', 'zyra'
];

const ROLES = ['top', 'jg', 'mid', 'adc', 'sup'];

/**
 * Simple seeded random generator using process ID
 * Returns a deterministic value between 0 and max-1
 */
function seededRandom(seed: number, max: number): number {
  // Simple linear congruential generator
  const a = 1664525;
  const c = 1013904223;
  const m = 2 ** 32;
  return ((a * seed + c) % m) % max;
}

/**
 * Gets a unique identifier for this session
 * - If running in tmux: uses tmux session name without "dev-" prefix (e.g., "fizz-top")
 * - Otherwise: generates champion-role ID seeded by process ID (e.g., "riven-jg")
 */
function getCreatorId(): string {
  // Check if running in tmux
  if (process.env.TMUX) {
    try {
      // Get current tmux session name
      let sessionName = execSync('tmux display-message -p "#S"', {
        encoding: 'utf-8',
        timeout: 1000,
      }).trim();

      if (sessionName) {
        // Strip "dev-" prefix if present (tmux sessions are "dev-fizz-top", we want "fizz-top")
        if (sessionName.startsWith('dev-')) {
          sessionName = sessionName.substring(4);
        }
        return sessionName;
      }
    } catch (error) {
      // Fall through to generate ID
      console.error('Failed to get tmux session name:', error);
    }
  }

  // Not in tmux - generate champion-role ID seeded by process ID
  const pid = process.pid;

  // Use PID to deterministically select champion and role
  const championIndex = seededRandom(pid, CHAMPIONS.length);
  const roleIndex = seededRandom(pid * 2, ROLES.length); // Multiply by 2 for different seed

  return `${CHAMPIONS[championIndex]}-${ROLES[roleIndex]}`;
}

/**
 * Makes an HTTP request to the gateway server
 */
async function gatewayRequest(path: string, options: RequestInit = {}): Promise<any> {
  const url = `${GATEWAY_URL}${path}`;

  try {
    const response = await fetch(url, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        ...options.headers,
      },
    });

    const data = await response.json() as any;

    if (!response.ok) {
      throw new Error(data.error || `HTTP ${response.status}: ${response.statusText}`);
    }

    return data;
  } catch (error: any) {
    throw new Error(`Gateway request failed: ${error.message}`);
  }
}

/**
 * MCP Server for Dev Sessions
 */
const server = new Server(
  {
    name: 'dev-sessions',
    version: '1.0.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

/**
 * List available tools
 */
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: 'create_dev_session',
        description: `Creates a new developer session.

This spawns a fresh developer that you can hand off work to. The new developer will run independently, and you can communicate with them by sending messages.

Use this when you want to:
- Delegate a subtask to another developer
- Hand off the next phase of development
- Parallelize work across multiple developer sessions

The session is created in the same workspace directory as your current session.`,
        inputSchema: {
          type: 'object',
          properties: {
            description: {
              type: 'string',
              description: 'Brief description of what this dev session is for (e.g., "Implementing user authentication")',
            },
            cli: {
              type: 'string',
              enum: ['claude', 'codex'],
              description: 'Which CLI to use: "claude" (default) or "codex"',
            },
          },
          required: [],
        },
      },
      {
        name: 'list_dev_sessions',
        description: `Lists all active developer sessions that were created through this system.

Shows session IDs, descriptions, workspace paths, and creation times. Use this to see what other developers are available to communicate with.`,
        inputSchema: {
          type: 'object',
          properties: {},
          required: [],
        },
      },
      {
        name: 'send_dev_message',
        description: `Sends a message to another developer session.

Use this to communicate with developers you've created. The message will appear as user input to the target developer, as if the user typed it directly.

IMPORTANT: Only send messages to sessions you created. The message will be delivered exactly as provided, so format it clearly (e.g., start with "## Context" or "## Task" for clarity).

Safety: This tool verifies that a developer is actually running in the target session before sending the message. If the developer has exited, the send will fail to prevent accidentally executing shell commands.`,
        inputSchema: {
          type: 'object',
          properties: {
            sessionId: {
              type: 'string',
              description: 'The session ID to send the message to (e.g., "riven-jg")',
            },
            message: {
              type: 'string',
              description: 'The message to send to the developer',
            },
          },
          required: ['sessionId', 'message'],
        },
      },
      {
        name: 'read_dev_output',
        description: `Reads recent output from a developer session.

Use this to check what another developer has output recently. This is useful for monitoring their progress or checking if they have questions for you.

Timing: Wait 30-60s before reading for complex tasks; simple queries may complete in ~10s.

Returns the last N lines of terminal output from the session.`,
        inputSchema: {
          type: 'object',
          properties: {
            sessionId: {
              type: 'string',
              description: 'The session ID to read output from (e.g., "riven-jg")',
            },
            lines: {
              type: 'number',
              description: 'Number of lines to read (default: 100, max: 1000)',
            },
          },
          required: ['sessionId'],
        },
      },
    ],
  };
});

/**
 * Handle tool calls
 */
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case 'create_dev_session': {
        // Get workspace path - use HOST_PATH if in Docker, otherwise use current directory
        let hostPath = process.env.HOST_PATH;

        // If HOST_PATH not set, we're running on host - use current working directory
        if (!hostPath) {
          hostPath = process.cwd();
          console.error(`HOST_PATH not set, using current directory: ${hostPath}`);
        }

        // Get optional description, cli, and creator from args
        const description = (args as any).description || 'Dev session handoff';
        const cli = (args as any).cli || 'claude'; // Default to claude
        const creator = getCreatorId();

        // Create session via gateway
        const result = await gatewayRequest('/create-session', {
          method: 'POST',
          body: JSON.stringify({
            hostPath,
            description,
            creator,
            cli,
          }),
        });

        return {
          content: [
            {
              type: 'text',
              text: `✓ Created dev session: ${result.sessionId}

Workspace: ${result.workspacePath}

The new developer is now running and ready to receive messages. Use send_dev_message with sessionId "${result.sessionId}" to communicate with them.`,
            },
          ],
        };
      }

      case 'list_dev_sessions': {
        // List sessions via gateway (auto-prunes stale sessions)
        const result = await gatewayRequest('/list-sessions');

        if (result.sessions.length === 0) {
          return {
            content: [
              {
                type: 'text',
                text: 'No dev sessions found.',
              },
            ],
          };
        }

        // Format sessions as a table
        let output = `Found ${result.sessions.length} dev session(s):\n\n`;

        for (const session of result.sessions) {
          output += `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`;
          output += `Session ID: ${session.sessionId}\n`;
          output += `Description: ${session.description}\n`;
          output += `Creator: ${session.creator}\n`;
          output += `Workspace: ${session.workspacePath}\n`;
          output += `Status: ${session.status}\n`;
          output += `Created: ${session.createdAt}\n`;
          output += `Last Used: ${session.lastUsed}\n`;
        }

        return {
          content: [
            {
              type: 'text',
              text: output,
            },
          ],
        };
      }

      case 'send_dev_message': {
        const { sessionId, message } = args as any;

        if (!sessionId) {
          throw new Error('sessionId is required');
        }

        if (!message) {
          throw new Error('message is required');
        }

        // Send message via gateway
        const result = await gatewayRequest('/send-message', {
          method: 'POST',
          body: JSON.stringify({
            sessionId,
            message,
          }),
        });

        return {
          content: [
            {
              type: 'text',
              text: `✓ Message sent to ${sessionId}

The other developer should now see your message and respond to it. Use read_dev_output with sessionId "${sessionId}" to check their response.`,
            },
          ],
        };
      }

      case 'read_dev_output': {
        const { sessionId, lines } = args as any;

        if (!sessionId) {
          throw new Error('sessionId is required');
        }

        // Build query params
        const params = new URLSearchParams();
        params.append('sessionId', sessionId);
        if (lines) {
          params.append('lines', lines.toString());
        }

        // Read output via gateway
        const result = await gatewayRequest(`/read-output?${params.toString()}`);

        return {
          content: [
            {
              type: 'text',
              text: `Output from ${sessionId} (last ${result.lines} lines):\n\n${result.output}`,
            },
          ],
        };
      }

      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error: any) {
    return {
      content: [
        {
          type: 'text',
          text: `Error: ${error.message}`,
        },
      ],
      isError: true,
    };
  }
});

/**
 * Start the server
 */
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);

  // Log to stderr so it doesn't interfere with stdio protocol
  console.error('Dev Sessions MCP server running');
  console.error(`Gateway URL: ${GATEWAY_URL}`);
}

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
