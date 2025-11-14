/**
 * League of Legends champion names and roles for generating session IDs
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
 * Generates a random League of Legends champion + role session ID
 * Format: "riven-jg", "blitz-adc", etc.
 */
export function generateSessionId(): string {
  const champion = CHAMPIONS[Math.floor(Math.random() * CHAMPIONS.length)];
  const role = ROLES[Math.floor(Math.random() * ROLES.length)];
  return `${champion}-${role}`;
}

/**
 * Converts session ID to tmux session name by adding "dev-" prefix
 * "riven-jg" -> "dev-riven-jg"
 */
export function toTmuxSessionName(sessionId: string): string {
  return `dev-${sessionId}`;
}

/**
 * Converts tmux session name back to session ID by removing "dev-" prefix
 * "dev-riven-jg" -> "riven-jg"
 */
export function fromTmuxSessionName(tmuxName: string): string | null {
  if (!tmuxName.startsWith('dev-')) {
    return null;
  }
  return tmuxName.substring(4);
}
