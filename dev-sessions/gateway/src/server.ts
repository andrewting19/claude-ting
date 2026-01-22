import express, { Request, Response } from 'express';
import cors from 'cors';
import { SessionDatabase } from './database';
import { TmuxExecutor } from './tmux-executor';
import { generateSessionId } from './champion-ids';

const app = express();
const PORT = process.env.PORT || 6767;
const MAX_SESSIONS_PER_CREATOR = parseInt(process.env.MAX_SESSIONS_PER_CREATOR || '10', 10);

// Get SSH connection info from environment (needed for SSH to host)
const SSH_USER = process.env.SSH_USER || process.env.USER;
const SSH_HOST = process.env.SSH_HOST || 'host.docker.internal';
const SSH_PORT = parseInt(process.env.SSH_PORT || '22', 10);

if (!SSH_USER) {
  console.error('ERROR: SSH_USER environment variable must be set');
  process.exit(1);
}

// Initialize database and tmux executor
const db = new SessionDatabase();
const tmux = new TmuxExecutor(SSH_HOST, SSH_USER, SSH_PORT);

// Middleware
app.use(cors());
app.use(express.json());

// Request logging
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

/**
 * POST /create-session
 * Creates a new developer session in tmux
 *
 * Body:
 *   - hostPath: string (workspace path on host)
 *   - description?: string (optional description)
 *   - creator?: string (optional creator identifier)
 *   - cli?: 'claude' | 'codex' (optional, defaults to 'claude')
 */
app.post('/create-session', async (req: Request, res: Response) => {
  try {
    const { hostPath, description, creator, cli, mode } = req.body;

    if (!hostPath || typeof hostPath !== 'string') {
      return res.status(400).json({
        error: 'hostPath is required and must be a string'
      });
    }

    // Validate hostPath to prevent injection
    // Must be an absolute path and not contain shell metacharacters (except /)
    if (!hostPath.startsWith('/')) {
      return res.status(400).json({
        error: 'hostPath must be an absolute path (start with /)'
      });
    }

    // Check for dangerous characters (allowing only alphanumeric, /, -, _, ., and spaces)
    if (!/^[a-zA-Z0-9\/_.\- ]+$/.test(hostPath)) {
      return res.status(400).json({
        error: 'hostPath contains invalid characters. Only alphanumeric, /, -, _, ., and spaces are allowed'
      });
    }

    // Validate cli parameter if provided
    const cliChoice = cli || 'claude';
    if (cliChoice !== 'claude' && cliChoice !== 'codex') {
      return res.status(400).json({
        error: 'cli must be either "claude" or "codex"'
      });
    }

    // Validate mode parameter if provided
    const modeChoice = mode || 'docker';
    if (modeChoice !== 'docker' && modeChoice !== 'native') {
      return res.status(400).json({
        error: 'mode must be either "docker" or "native"'
      });
    }

    // Rate limiting: Check active sessions for this creator
    const creatorId = creator || 'unknown';
    const activeSessionsForCreator = db.listSessions('active').filter(
      s => s.creator === creatorId
    );

    if (activeSessionsForCreator.length >= MAX_SESSIONS_PER_CREATOR) {
      return res.status(429).json({
        error: `Rate limit exceeded: ${creatorId} has ${activeSessionsForCreator.length} active sessions (max: ${MAX_SESSIONS_PER_CREATOR})`
      });
    }

    // Generate unique session ID
    let sessionId = generateSessionId();
    let attempts = 0;

    // Ensure uniqueness (unlikely to collide, but check anyway)
    while (db.getSession(sessionId) !== null && attempts < 10) {
      sessionId = generateSessionId();
      attempts++;
    }

    if (attempts >= 10) {
      return res.status(500).json({
        error: 'Failed to generate unique session ID after 10 attempts'
      });
    }

    // Create session in database
    const session = db.createSession(
      sessionId,
      description || 'Dev session handoff',
      creator || 'unknown',
      hostPath
    );

    // Create tmux session on host
    await tmux.createSession(session.tmux_session_name, hostPath, cliChoice, modeChoice);

    console.log(`✓ Created session: ${sessionId} (${session.tmux_session_name}) using ${cliChoice} (${modeChoice})`);

    res.json({
      sessionId,
      tmuxSessionName: session.tmux_session_name,
      workspacePath: hostPath,
      message: `Dev session created. Attach with: tmux attach -t ${session.tmux_session_name}`
    });
  } catch (error: any) {
    console.error('Error creating session:', error);
    res.status(500).json({
      error: error.message || 'Failed to create session'
    });
  }
});

/**
 * GET /list-sessions
 * Lists all dev sessions
 * Auto-prunes sessions whose tmux sessions no longer exist
 */
app.get('/list-sessions', async (req: Request, res: Response) => {
  try {
    // Prune stale sessions before listing
    await pruneDeletedSessions();

    const sessions = db.listSessions();

    res.json({
      sessions: sessions.map(s => ({
        sessionId: s.session_id,
        tmuxSessionName: s.tmux_session_name,
        description: s.description,
        creator: s.creator,
        workspacePath: s.workspace_path,
        createdAt: new Date(s.created_at).toISOString(),
        lastUsed: new Date(s.last_used).toISOString(),
        status: s.status
      }))
    });
  } catch (error: any) {
    console.error('Error listing sessions:', error);
    res.status(500).json({
      error: error.message || 'Failed to list sessions'
    });
  }
});

/**
 * POST /send-message
 * Sends a message to a Claude developer session
 *
 * Body:
 *   - sessionId: string
 *   - message: string
 */
app.post('/send-message', async (req: Request, res: Response) => {
  try {
    const { sessionId, message } = req.body;

    if (!sessionId || typeof sessionId !== 'string') {
      return res.status(400).json({
        error: 'sessionId is required and must be a string'
      });
    }

    if (!message || typeof message !== 'string') {
      return res.status(400).json({
        error: 'message is required and must be a string'
      });
    }

    // Get session from database
    const session = db.getSession(sessionId);
    if (!session) {
      return res.status(404).json({
        error: `Session not found: ${sessionId}`
      });
    }

    // Check if tmux session exists
    if (!(await tmux.sessionExists(session.tmux_session_name))) {
      db.updateStatus(sessionId, 'inactive');
      return res.status(404).json({
        error: `Tmux session ${session.tmux_session_name} no longer exists`
      });
    }

    // Send message (includes Claude safety checks)
    await tmux.sendMessage(session.tmux_session_name, message);

    // Update last used timestamp
    db.updateLastUsed(sessionId);

    console.log(`✓ Sent message to ${sessionId}`);

    res.json({
      success: true,
      sessionId,
      message: 'Message sent successfully'
    });
  } catch (error: any) {
    console.error('Error sending message:', error);
    res.status(500).json({
      error: error.message || 'Failed to send message'
    });
  }
});

/**
 * GET /read-output
 * Reads recent output from a Claude developer session
 *
 * Query params:
 *   - sessionId: string
 *   - lines?: number (default: 100, max: 1000)
 */
app.get('/read-output', async (req: Request, res: Response) => {
  try {
    const { sessionId, lines } = req.query;

    if (!sessionId || typeof sessionId !== 'string') {
      return res.status(400).json({
        error: 'sessionId is required and must be a string'
      });
    }

    // Get session from database
    const session = db.getSession(sessionId);
    if (!session) {
      return res.status(404).json({
        error: `Session not found: ${sessionId}`
      });
    }

    // Check if tmux session exists
    if (!(await tmux.sessionExists(session.tmux_session_name))) {
      db.updateStatus(sessionId, 'inactive');
      return res.status(404).json({
        error: `Tmux session ${session.tmux_session_name} no longer exists`
      });
    }

    // Parse lines parameter
    const numLines = lines ? parseInt(lines as string, 10) : 100;
    if (isNaN(numLines)) {
      return res.status(400).json({
        error: 'lines must be a number'
      });
    }

    // Read output
    const output = await tmux.readOutput(session.tmux_session_name, numLines);

    // Update last used timestamp
    db.updateLastUsed(sessionId);

    res.json({
      sessionId,
      output,
      lines: numLines
    });
  } catch (error: any) {
    console.error('Error reading output:', error);
    res.status(500).json({
      error: error.message || 'Failed to read output'
    });
  }
});

/**
 * GET /health
 * Health check endpoint
 */
app.get('/health', (req: Request, res: Response) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString()
  });
});

/**
 * Prunes deleted tmux sessions from database
 * Deletes sessions if their tmux session no longer exists
 */
async function pruneDeletedSessions() {
  const allSessions = db.listSessions();
  let prunedCount = 0;

  for (const session of allSessions) {
    if (!(await tmux.sessionExists(session.tmux_session_name))) {
      db.deleteSession(session.session_id);
      prunedCount++;
      console.log(`  🗑️  Deleted ${session.session_id} (tmux session no longer exists)`);
    }
  }

  return prunedCount;
}

// Start server
app.listen(PORT, async () => {
  console.log(`🚀 Dev Sessions Gateway running on port ${PORT}`);
  console.log(`📊 Database ready`);
  console.log(`🔗 SSH target: ${SSH_USER}@${SSH_HOST}:${SSH_PORT}`);

  // Prune stale sessions on startup
  console.log('🧹 Pruning stale sessions...');
  const prunedCount = await pruneDeletedSessions();
  if (prunedCount === 0) {
    console.log('  ✓ No stale sessions found');
  } else {
    console.log(`  ✓ Deleted ${prunedCount} stale session(s)`);
  }
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('Shutting down gracefully...');
  db.close();
  process.exit(0);
});
