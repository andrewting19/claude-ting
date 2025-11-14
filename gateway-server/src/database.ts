import Database from 'better-sqlite3';
import { toTmuxSessionName } from './champion-ids';

export interface DevSession {
  session_id: string;
  tmux_session_name: string;
  description: string;
  creator: string;
  workspace_path: string;
  created_at: number;
  last_used: number;
  status: 'active' | 'inactive';
}

export class SessionDatabase {
  private db: Database.Database;

  constructor(dbPath: string = '/data/sessions.db') {
    this.db = new Database(dbPath);
    this.initializeSchema();
  }

  private initializeSchema() {
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS dev_sessions (
        session_id TEXT PRIMARY KEY,
        tmux_session_name TEXT NOT NULL UNIQUE,
        description TEXT NOT NULL,
        creator TEXT NOT NULL,
        workspace_path TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        last_used INTEGER NOT NULL,
        status TEXT NOT NULL CHECK(status IN ('active', 'inactive'))
      );

      CREATE INDEX IF NOT EXISTS idx_status ON dev_sessions(status);
      CREATE INDEX IF NOT EXISTS idx_created_at ON dev_sessions(created_at DESC);
    `);
  }

  createSession(
    sessionId: string,
    description: string,
    creator: string,
    workspacePath: string
  ): DevSession {
    const now = Date.now();
    const tmuxSessionName = toTmuxSessionName(sessionId);

    const session: DevSession = {
      session_id: sessionId,
      tmux_session_name: tmuxSessionName,
      description,
      creator,
      workspace_path: workspacePath,
      created_at: now,
      last_used: now,
      status: 'active'
    };

    const stmt = this.db.prepare(`
      INSERT INTO dev_sessions (
        session_id, tmux_session_name, description, creator,
        workspace_path, created_at, last_used, status
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `);

    stmt.run(
      session.session_id,
      session.tmux_session_name,
      session.description,
      session.creator,
      session.workspace_path,
      session.created_at,
      session.last_used,
      session.status
    );

    return session;
  }

  getSession(sessionId: string): DevSession | null {
    const stmt = this.db.prepare('SELECT * FROM dev_sessions WHERE session_id = ?');
    const result = stmt.get(sessionId) as DevSession | undefined;
    return result || null;
  }

  listSessions(status?: 'active' | 'inactive'): DevSession[] {
    let query = 'SELECT * FROM dev_sessions';
    const params: any[] = [];

    if (status) {
      query += ' WHERE status = ?';
      params.push(status);
    }

    query += ' ORDER BY last_used DESC';

    const stmt = this.db.prepare(query);
    return stmt.all(...params) as DevSession[];
  }

  updateLastUsed(sessionId: string) {
    const stmt = this.db.prepare(`
      UPDATE dev_sessions
      SET last_used = ?
      WHERE session_id = ?
    `);
    stmt.run(Date.now(), sessionId);
  }

  updateStatus(sessionId: string, status: 'active' | 'inactive') {
    const stmt = this.db.prepare(`
      UPDATE dev_sessions
      SET status = ?, last_used = ?
      WHERE session_id = ?
    `);
    stmt.run(status, Date.now(), sessionId);
  }

  deleteSession(sessionId: string) {
    const stmt = this.db.prepare('DELETE FROM dev_sessions WHERE session_id = ?');
    stmt.run(sessionId);
  }

  close() {
    this.db.close();
  }
}
