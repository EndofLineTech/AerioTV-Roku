import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

const checker = fileURLToPath(new URL('./check-roku-beacon-trace.mjs', import.meta.url));
const launch = '100\tAppLaunchComplete\n';
const epg = (start, end) => `${launch}${start}\tEPGLaunchInitiate\n${end}\tEPGLaunchComplete\n`;

// Synthetic CLI unit-test vectors only. These aren't Roku captures.
function run(t, mode, trace) {
    const directory = mkdtempSync(join(tmpdir(), 'roku-beacon-trace-'));
    t.after(() => rmSync(directory, { recursive: true }));
    const path = join(directory, 'trace.tsv');
    writeFileSync(path, trace);
    return spawnSync(process.execPath, [checker, mode, path], { encoding: 'utf8' });
}

test('launch mode checks exactly one launch and no EPG markers', (t) => {
    const result = run(t, 'launch', launch);
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(JSON.parse(result.stdout), { mode: 'launch', sequenceValid: true });
    for (const trace of ['', launch + launch, epg(200, 300)]) {
        assert.equal(run(t, 'launch', trace).status, 1);
    }
});

test('EPG mode measures both intervals; eligibility uses initiate, not complete', (t) => {
    const boundary = run(t, 'epg', epg(5100, 5450).replaceAll('\n', '\r\n'));
    assert.equal(boundary.status, 0, boundary.stderr);
    assert.deepEqual(JSON.parse(boundary.stdout), {
        mode: 'epg', sequenceValid: true,
        launchToInitiateMs: 5000, initiateToCompleteMs: 350, epgInitiationWithinFiveSeconds: true,
    });
    const late = run(t, 'epg', epg(5101, 5450));
    assert.equal(late.status, 1);
    assert.deepEqual(JSON.parse(late.stdout), {
        mode: 'epg', sequenceValid: true,
        launchToInitiateMs: 5001, initiateToCompleteMs: 349, epgInitiationWithinFiveSeconds: false,
    });
    assert.equal(run(t, 'epg', epg(100, 100)).status, 0, 'ties retain recorded row order');
});

test('EPG mode rejects incomplete, duplicate, out-of-order and regressing traces', (t) => {
    for (const trace of [
        launch, epg(200, 300) + '400\tEPGLaunchInitiate\n500\tEPGLaunchComplete\n',
        '200\tEPGLaunchInitiate\n300\tEPGLaunchComplete\n',
        launch + '200\tEPGLaunchComplete\n300\tEPGLaunchInitiate\n',
        epg(99, 300), epg(200, 199), launch + epg(200, 300),
    ]) {
        const result = run(t, 'epg', trace);
        assert.equal(result.status, 1);
        assert.equal(result.stdout, '', 'invalid trace must not report timing');
    }
});

test('malformed or unsanitized input is rejected without echoing the line', (t) => {
    for (const trace of [
        '-1\tAppLaunchComplete\n', '1.2\tAppLaunchComplete\n',
        '9007199254740993\tAppLaunchComplete\n', '100 AppLaunchComplete\n',
        launch + '\n', launch + 'private-data\n', '1\tAppLaunchComplete\tprivate-data\n',
        '100\tAppLaunchComplete\r', '100\tAppLaunchComplete\u2028',
    ]) {
        const result = run(t, 'launch', trace);
        assert.equal(result.status, 1);
        assert.equal(result.stdout, '');
        assert.match(result.stderr, /invalid beacon trace row \d+/);
        assert.doesNotMatch(result.stderr, /private-data/);
    }
});
