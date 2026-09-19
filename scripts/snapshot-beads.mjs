import { spawnSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';

// Read-only archival export for the installed Dolt-backed bd version.
// This is a reviewable backup, not a replacement for the live issue database.
const snapshot = { format: 1, tables: {} };
for (const table of ['issues', 'dependencies', 'comments', 'labels']) {
  const result = spawnSync('bd', ['sql', `SELECT * FROM ${table}`, '--json'], { encoding: 'utf8' });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(result.stderr || `Failed to export ${table}`);
  const rows = JSON.parse(result.stdout);
  if (!Array.isArray(rows)) throw new Error(`Unexpected ${table} response`);
  rows.sort((a, b) => JSON.stringify(a).localeCompare(JSON.stringify(b)));
  snapshot.tables[table] = rows;
  console.log(`${table}: ${rows.length}`);
}
writeFileSync(new URL('../.beads/backlog-snapshot.json', import.meta.url), JSON.stringify(snapshot, null, 2) + '\n');
