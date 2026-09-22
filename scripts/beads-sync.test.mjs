import assert from 'node:assert/strict';
import test from 'node:test';
import { parseSqlResult, syncBeads } from './beads-sync.mjs';

test('SQL errors fail even when bd exits zero', () => {
  assert.throws(() => parseSqlResult({ status: 0, stdout: '{"error":"query failed"}' }), /query failed/);
  assert.throws(() => parseSqlResult({ status: 1, stderr: 'connection failed' }), /connection failed/);
  assert.throws(() => parseSqlResult({ status: 0, stdout: '{}' }), /Unexpected/);
  assert.deepEqual(parseSqlResult({ status: 0, stdout: '{"rows_affected":0}' }), { rows_affected: 0 });
});

function fixture({ url = 'git+https://github.com/EndofLineTech/AerioTV-Roku.git', branch = 'main', dirty = false } = {}) {
  const calls = [];
  return { calls, query(sql) {
    calls.push(sql);
    if (sql.includes('dolt_remotes')) return [{ name: 'origin', url }];
    if (sql.includes('active_branch')) return [{ branch, head: 'test-head' }];
    if (sql.includes('dolt_status')) return dirty ? [{ table_name: 'issues' }] : [];
    return { rows_affected: 0 };
  } };
}

test('sync refuses changed destination, wrong branch, dirty data and invalid actions', () => {
  for (const options of [{ url: 'https://example.test/other.git' }, { branch: 'other' }, { dirty: true }]) {
    const f = fixture(options);
    assert.throws(() => syncBeads('push', f.query));
    assert.ok(!f.calls.some(sql => sql.startsWith('CALL')));
  }
  assert.throws(() => syncBeads('force', () => assert.fail('must not query')));
});

test('push is non-forced and pull is fast-forward only', () => {
  const push = fixture();
  assert.equal(syncBeads('push', push.query).head, 'test-head');
  assert.ok(push.calls.includes("CALL dolt_push('origin', 'main')"));
  const pull = fixture();
  syncBeads('pull', pull.query);
  assert.ok(pull.calls.includes("CALL dolt_pull('--ff-only', 'origin', 'main')"));
});
