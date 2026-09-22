import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';

const root = fileURLToPath(new URL('../', import.meta.url));

// bd 0.56.1 can return a SQL error as JSON with exit status zero.
export function parseSqlResult(result) {
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(result.stderr || 'bd sql failed');
  const value = JSON.parse(result.stdout);
  if (value?.error) throw new Error(value.error);
  if (!Array.isArray(value) && typeof value?.rows_affected !== 'number') {
    throw new Error('Unexpected bd sql response');
  }
  return value;
}

function sql(query) {
  return parseSqlResult(spawnSync('bd', ['sql', query, '--json'], {
    cwd: root, encoding: 'utf8', timeout: 300000,
  }));
}

export function syncBeads(action, query = sql) {
  if (!['push', 'pull'].includes(action)) throw new Error('Usage: node scripts/beads-sync.mjs push|pull');
  const remotes = query('SELECT name, url FROM dolt_remotes');
  const remote = remotes.find(row => row.name === 'origin');
  const approved = 'https://github.com/EndofLineTech/AerioTV-Roku.git';
  if (!remote || ![approved, 'git+' + approved].includes(remote.url)) {
    throw new Error('Approved Dolt origin is missing or changed. See docs/BEADS-SYNC.md.');
  }
  const state = query("SELECT active_branch() AS branch, dolt_hashof('HEAD') AS head")[0];
  if (state?.branch !== 'main') throw new Error('Expected Beads main branch; refusing to sync another branch.');
  if (query('SELECT * FROM dolt_status').length) {
    throw new Error('Uncommitted Beads changes: review with bd vc status and commit with bd vc commit before syncing.');
  }
  // Use supported server procedures: bd dolt push/pull skip store initialization
  // in bd 0.56.1. Never force-push or implicitly merge divergent issue histories.
  query(action === 'push' ? "CALL dolt_push('origin', 'main')" : "CALL dolt_pull('--ff-only', 'origin', 'main')");
  return query("SELECT active_branch() AS branch, dolt_hashof('HEAD') AS head")[0];
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const result = syncBeads(process.argv[2]);
    console.log(`Beads ${process.argv[2]} complete: ${result.branch} ${result.head}`);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
