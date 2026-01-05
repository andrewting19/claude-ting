import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

/**
 * Executes tmux commands on the host via SSH
 */
export class TmuxExecutor {
  private sshTarget: string;
  private sshOptions: string[];

  constructor(
    sshHost: string = 'localhost',
    sshUser?: string,
    sshPort: number = 22
  ) {
    // If user specified, use user@host format
    this.sshTarget = sshUser ? `${sshUser}@${sshHost}` : sshHost;

    // SSH options for non-interactive execution
    this.sshOptions = [
      '-o', 'StrictHostKeyChecking=no',
      '-o', 'BatchMode=yes',
      '-o', 'ConnectTimeout=5'
    ];

    if (sshPort !== 22) {
      this.sshOptions.push('-p', sshPort.toString());
    }
  }

  /**
   * Executes a command on the host via SSH
   */
  private async execSSH(command: string): Promise<string> {
    const escapedCommand = command
      .replace(/\\/g, '\\\\')
      .replace(/"/g, '\\"')
      .replace(/\$/g, '\\$')
      .replace(/`/g, '\\`');

    const sshCmd = `ssh ${this.sshOptions.join(' ')} ${this.sshTarget} "${escapedCommand}"`;

    try {
      const { stdout } = await execAsync(sshCmd, {
        encoding: 'utf-8',
        timeout: 10000
      });
      return stdout;
    } catch (error: any) {
      throw new Error(`SSH command failed: ${error.message}`);
    }
  }

  /**
   * Creates a new tmux session running clauded or codexed
   * Creates an interactive shell so .zshrc is loaded (for aliases, PATH, etc.)
   * Automatically dismisses the API key prompt
   */
  async createSession(tmuxSessionName: string, workspacePath: string, cli: 'claude' | 'codex' = 'claude'): Promise<void> {
    // Escape single quotes in workspace path for send-keys
    const escapedPath = workspacePath.replace(/'/g, "'\\''");

    // Choose the docker helper command based on cli
    const cliCommand = cli === 'codex' ? 'codexed' : 'clauded';

    // Create session without command (starts interactive shell)
    // Then send keys to cd and run the chosen cli
    // Wait 5 seconds for API key prompt to appear, then dismiss it
    const command = `tmux new-session -d -s ${tmuxSessionName} && tmux send-keys -t ${tmuxSessionName} 'cd ${escapedPath} && ${cliCommand} .' C-m && sleep 5 && tmux send-keys -t ${tmuxSessionName} C-m`;

    await this.execSSH(command);
  }

  /**
   * Checks if an AI CLI (Claude or Codex) is running in a tmux session
   * Returns true if claude, codex, or docker (running either) is found
   */
  async isCliRunning(tmuxSessionName: string): Promise<boolean> {
    try {
      const command = `tmux list-panes -t ${tmuxSessionName} -F '#{pane_tty}' | xargs -I {} ps -t {} | grep -E '(claude|codex|docker.*ubuntu-dev)'`;

      const output = await this.execSSH(command);
      return output.trim().length > 0;
    } catch (error) {
      // Grep returns non-zero exit code if no matches found
      return false;
    }
  }

  /**
   * Sends a message to a tmux session (literal text + Enter twice)
   * Checks that an AI CLI is running before sending
   * Both CLIs require two Enters: first creates newline, second submits
   */
  async sendMessage(tmuxSessionName: string, message: string): Promise<void> {
    // Check: CLI must be running before we send
    if (!(await this.isCliRunning(tmuxSessionName))) {
      throw new Error('No AI CLI (Claude/Codex) is running in this session - refusing to send message');
    }

    // Send the message literally through base64 + here-doc so no shell interprets it
    const encodedMessage = Buffer.from(message, 'utf8').toString('base64');
    const escapedSessionName = tmuxSessionName.replace(/'/g, "'\\''");
    const remoteScript = [
      `decoded=$(printf '%s' '${encodedMessage}' | base64 --decode)`,
      `tmux send-keys -l -t '${escapedSessionName}' "$decoded"`
    ].join('\n');

    await this.execSSH(`bash -s <<'EOF'\n${remoteScript}\nEOF\n`);

    // Send two Enters: first creates newline, second submits
    await this.execSSH(`tmux send-keys -t '${escapedSessionName}' C-m`);
    await this.execSSH(`tmux send-keys -t '${escapedSessionName}' C-m`);
  }

  /**
   * Reads recent output from a tmux session
   */
  async readOutput(tmuxSessionName: string, lines: number = 100): Promise<string> {
    // Limit to reasonable range
    const safeLines = Math.min(Math.max(lines, 1), 1000);

    const command = `tmux capture-pane -p -S -${safeLines} -t ${tmuxSessionName}`;

    try {
      return await this.execSSH(command);
    } catch (error: any) {
      throw new Error(`Failed to read tmux output: ${error.message}`);
    }
  }

  /**
   * Lists all tmux sessions on the host
   */
  async listAllTmuxSessions(): Promise<string[]> {
    try {
      const output = await this.execSSH('tmux list-sessions -F "#{session_name}"');
      return output.trim().split('\n').filter(s => s.length > 0);
    } catch (error) {
      // No sessions exist
      return [];
    }
  }

  /**
   * Kills a tmux session
   */
  async killSession(tmuxSessionName: string): Promise<void> {
    try {
      await this.execSSH(`tmux kill-session -t ${tmuxSessionName}`);
    } catch (error: any) {
      throw new Error(`Failed to kill session: ${error.message}`);
    }
  }

  /**
   * Checks if a tmux session exists
   */
  async sessionExists(tmuxSessionName: string): Promise<boolean> {
    try {
      await this.execSSH(`tmux has-session -t ${tmuxSessionName}`);
      return true;
    } catch (error) {
      return false;
    }
  }
}
