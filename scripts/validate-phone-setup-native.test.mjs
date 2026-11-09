import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import net from 'node:net';
import http from 'node:http';
import { x25519Vectors } from './setup-x25519-vectors.mjs';

const script = resolve('scripts/validate-phone-setup-native.mjs');
for (const scenario of ['success', 'wrong-result', 'missing-result']) {
  test(`install-time console capture and restore: ${scenario}`, { timeout: 25000 }, async t => {
    const directory = mkdtempSync(join(process.env.OPENCODE_TMP_DIR ?? tmpdir(), 'native-runner-test-'));
    let consoleSocket;
    const events = [];
    const consoleServer = net.createServer(socket => {
      consoleSocket = socket;
      // This backlog must be discarded, not counted as a fresh case.
      socket.write('[setup-x25519] {"id":"stale","passed":false,"elapsedms":1}\n');
    });
    await new Promise(resolve => consoleServer.listen(0, '127.0.0.1', resolve));
    const control = http.createServer((request, response) => {
      const action = new URL(request.url, 'http://localhost').searchParams.get('action');
      events.push(action);
      if (action?.includes('setup-x25519-probe.zip')) {
        assert.ok(consoleSocket, 'console is connected before the installer auto-launches');
        const rows = x25519Vectors().map(row => ({ id: row.id, passed: scenario !== 'wrong-result', elapsedms: 100 }));
        if (scenario === 'missing-result') rows.pop();
        const summary = { complete: true, passed: scenario !== 'wrong-result', maximumms: 100 };
        for (const row of [...rows, summary]) consoleSocket.write(`[setup-x25519] ${JSON.stringify(row)}\n`);
        consoleSocket.write('[setup-x25519] complete-v1\n');
      }
      response.end(action ? 'Install Success' : '');
    });
    await new Promise(resolve => control.listen(0, '127.0.0.1', resolve));
    t.after(() => {
      consoleSocket?.destroy();
      consoleServer.close();
      control.close();
      rmSync(directory, { recursive: true });
    });
    mkdirSync(join(directory, 'out'));
    writeFileSync(join(directory, 'restore.zip'), 'synthetic placeholder, fake installer only');
    // Fake curl controls a local test server. No Roku or real credentials used.
    writeFileSync(join(directory, 'curl'), `#!${process.execPath}\n` +
      `const http=require('node:http'); const arg=process.argv.find(a=>a.startsWith('archive=@'));\n` +
      `const target=new URL(process.env.TEST_CONTROL); if(arg)target.searchParams.set('action',arg);\n` +
      `http.get(target,r=>r.pipe(process.stdout)).on('error',()=>process.exit(1));\n`, { mode: 0o755 });
    const result = await new Promise((resolve, reject) => {
      const child = spawn(process.execPath, [script, '--x25519', 'restore.zip'], {
        cwd: directory,
        env: { ...process.env, PATH: directory + ':' + process.env.PATH,
          ROKU_HOST: '127.0.0.1', ROKU_DEV_PASSWORD: 'synthetic-test-password',
          ROKU_CONSOLE_PORT: String(consoleServer.address().port),
          TEST_CONTROL: `http://127.0.0.1:${control.address().port}/`,
        }, timeout: 20000,
      });
      let stdout = '', stderr = '';
      child.stdout.on('data', chunk => { stdout += chunk; });
      child.stderr.on('data', chunk => { stderr += chunk; });
      child.on('error', reject);
      child.on('close', code => resolve({ code, stdout, stderr }));
    });
    assert.equal(result.code, scenario === 'success' ? 0 : scenario === 'wrong-result' ? 2 : 1, result.stderr);
    assert.equal(events.filter(action => action?.includes('restore.zip')).length, 1, 'restore attempted exactly once');
    assert.match(result.stdout, /Normal app restored/);
    assert.ok(!result.stdout.includes('synthetic-test-password') && !result.stderr.includes('synthetic-test-password'));
  });
}
