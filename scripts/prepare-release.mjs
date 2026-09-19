import { createHash } from 'node:crypto';
import { copyFileSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const root = new URL('../', import.meta.url);
const version = JSON.parse(readFileSync(new URL('package.json', root), 'utf8')).version;
if (!/^\d+\.\d+\.\d+$/.test(version)) throw new Error('Expected a numeric Roku release version');
const manifest = Object.fromEntries(readFileSync(new URL('manifest', root), 'utf8')
  .split('\n').filter(line => line.includes('=')).map(line => {
    const i = line.indexOf('=');
    return [line.slice(0, i), line.slice(i + 1).trim()];
  }));
const rokuVersion = [manifest.major_version, manifest.minor_version, manifest.build_version].join('.');
if (version !== rokuVersion) throw new Error(`Version mismatch: npm ${version}, Roku ${rokuVersion}`);

const source = new URL('out/aeriotv-roku.zip', root);
const bytes = readFileSync(source);
if (bytes.length < 100 || bytes.readUInt32LE(0) !== 0x04034b50) throw new Error('Build ZIP is missing or invalid');
const directory = new URL('out/release/', root);
mkdirSync(directory, { recursive: true });
const filename = `aeriotv-roku-v${version}.zip`;
copyFileSync(source, new URL(filename, directory));
const checksum = createHash('sha256').update(bytes).digest('hex');
writeFileSync(new URL('SHA256SUMS', directory), `${checksum}  ${filename}\n`);
console.log(fileURLToPath(new URL(filename, directory)));
console.log(`${checksum}  ${filename}`);
