import { readFileSync } from 'node:fs';

const launch = 'AppLaunchComplete';
const initiate = 'EPGLaunchInitiate';
const complete = 'EPGLaunchComplete';
const rowPattern = /^([0-9]+)\t(AppLaunchComplete|EPGLaunchInitiate|EPGLaunchComplete)$/;

function checkTrace(mode, text) {
    const expected = mode === 'epg' ? [launch, initiate, complete] : [launch];
    const lines = text.split(/\r?\n/);
    if (lines.at(-1) === '') lines.pop();

    const timestamps = [];
    for (const [index, line] of lines.entries()) {
        const match = rowPattern.exec(line);
        const ms = match ? Number(match[1]) : NaN;
        if (!Number.isSafeInteger(ms) || match[0] !== line) throw new Error(`invalid beacon trace row ${index + 1}`);
        if (match[2] !== expected[index]) throw new Error(`unexpected beacon sequence at row ${index + 1}`);
        if (index > 0 && ms < timestamps[index - 1]) throw new Error(`timestamp regressed at row ${index + 1}`);
        timestamps.push(ms);
    }
    if (timestamps.length !== expected.length) throw new Error('incomplete beacon sequence');

    const result = { mode, sequenceValid: true };
    if (mode === 'epg') {
        result.launchToInitiateMs = timestamps[1] - timestamps[0];
        result.initiateToCompleteMs = timestamps[2] - timestamps[1];
        result.epgInitiationWithinFiveSeconds = result.launchToInitiateMs <= 5000;
    }
    return result;
}

const [mode, path, ...extra] = process.argv.slice(2);
if (!['launch', 'epg'].includes(mode) || !path || extra.length) {
    console.error('Usage: node scripts/check-roku-beacon-trace.mjs <launch|epg> <sanitized-session.tsv>');
    process.exitCode = 2;
} else {
    try {
        let text;
        try {
            text = readFileSync(path, 'utf8');
        } catch {
            throw new Error('cannot read beacon trace');
        }
        const result = checkTrace(mode, text);
        console.log(JSON.stringify(result));
        if (result.epgInitiationWithinFiveSeconds === false) process.exitCode = 1;
    } catch (error) {
        console.error(error.message);
        process.exitCode = 1;
    }
}
