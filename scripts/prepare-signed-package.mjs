import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { constants, copyFileSync, existsSync, readFileSync, writeFileSync } from 'node:fs';
import { basename, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const hash = bytes => createHash('sha256').update(bytes).digest('hex');

function releaseVersion(directory) {
  const version = JSON.parse(readFileSync(join(directory, 'package.json'), 'utf8')).version;
  if (!/^\d+\.\d+\.\d+$/.test(version)) throw new Error('Expected a numeric Roku release version');
  if (manifestVersion(readFileSync(join(directory, 'manifest'), 'utf8')) !== version) {
    throw new Error('package.json and manifest versions differ');
  }
  return version;
}

function manifestVersion(manifest) {
  const values = Object.fromEntries(manifest.split('\n').filter(line => line.includes('='))
    .map(line => {
      const index = line.indexOf('=');
      return [line.slice(0, index), line.slice(index + 1).trim()];
    }));
  return [values.major_version, values.minor_version, values.build_version].join('.');
}

function checkExistingChecksums(file, zipName, zipHash, pkgHash) {
  if (!existsSync(file)) return;
  for (const line of readFileSync(file, 'utf8').trim().split('\n')) {
    const match = /^([0-9a-f]{64})  ([^/\s]+)$/.exec(line);
    if (!match) throw new Error(`Malformed checksum record in ${basename(file)}`);
    const [, recordedHash, name] = match;
    if (name === zipName && recordedHash === zipHash) continue;
    if ((/^P[0-9a-f]{32}\.pkg$/.test(name) || name === zipName.replace(/\.zip$/, '.pkg')) && recordedHash === pkgHash) continue;
    throw new Error(`Existing ${basename(file)} conflicts with this package; use a new version`);
  }
}

export function prepareSignedPackage(sourcePath, directory = root) {
  if (!sourcePath) throw new Error('Provide the signed Roku P…pkg file as an argument');
  const version = releaseVersion(directory);
  const outputDirectory = join(directory, 'out/release');
  const zipName = `aeriotv-roku-v${version}.zip`;
  const zipPath = join(outputDirectory, zipName);
  const zipBytes = readFileSync(zipPath);
  if (zipBytes.length < 100 || zipBytes.readUInt32LE(0) !== 0x04034b50) throw new Error('Verified release ZIP is missing');
  const zipManifest = execFileSync('unzip', ['-p', zipPath, 'manifest'], { encoding: 'utf8' });
  if (manifestVersion(zipManifest) !== version) throw new Error('Release ZIP version differs');
  const pkgBytes = readFileSync(resolve(directory, sourcePath));
  const header = Buffer.from('Roku Channel PakV 2.0');
  if (pkgBytes.length < 1000 || !pkgBytes.subarray(0, header.length).equals(header)) {
    throw new Error('Expected a Roku-signed .pkg, not a sideload ZIP');
  }
  const zipHash = hash(zipBytes);
  const pkgHash = hash(pkgBytes);
  const pkgName = `aeriotv-roku-v${version}.pkg`;
  const destination = join(outputDirectory, pkgName);
  if (existsSync(destination) && !readFileSync(destination).equals(pkgBytes)) {
    throw new Error(`Existing ${pkgName} has different bytes; use a new version`);
  }
  checkExistingChecksums(join(outputDirectory, `SHA256SUMS-v${version}`), zipName, zipHash, pkgHash);
  checkExistingChecksums(join(outputDirectory, 'SHA256SUMS'), zipName, zipHash, pkgHash);
  if (!existsSync(destination)) copyFileSync(resolve(directory, sourcePath), destination, constants.COPYFILE_EXCL);
  const checksums = `${pkgHash}  ${pkgName}\n${zipHash}  ${zipName}\n`;
  writeFileSync(join(outputDirectory, `SHA256SUMS-v${version}`), checksums);
  writeFileSync(join(outputDirectory, 'SHA256SUMS'), checksums);
  return { destination, pkgHash, zipHash };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const { destination, pkgHash } = prepareSignedPackage(process.argv[2]);
  console.log(destination);
  console.log(`${pkgHash}  ${basename(destination)}`);
}
