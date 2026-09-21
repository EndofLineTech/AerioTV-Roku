import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const root = new URL('../', import.meta.url);

export function assertPackageEntries(entries) {
  if (!entries.includes('manifest')) throw new Error('Package must contain manifest at its root');
  for (const required of ['LICENSE.md', 'NOTICE.md']) {
    if (!entries.includes(required)) throw new Error(`Package is missing ${required}`);
  }
  if (!entries.some(entry => entry.startsWith('source/'))) throw new Error('Package is missing source files');
  if (!entries.some(entry => entry.startsWith('components/'))) throw new Error('Package is missing component files');

  const excluded = /(^|\/)(?:\.beads|node_modules|out|scripts|tests)(?:\/|$)|(^|\/)\.env[^/]*$|(^|\/)(?:package(?:-lock)?\.json|\.gitignore)$/;
  const invalid = entries.find(entry => excluded.test(entry));
  if (invalid) throw new Error(`Package contains excluded development file: ${invalid}`);
}

function packageEntries(archive) {
  const listing = execFileSync('unzip', ['-Z1', archive], { encoding: 'utf8' });
  return listing.split('\n').map(entry => entry.trim()).filter(Boolean);
}

function packageFile(archive, entry) {
  return execFileSync('unzip', ['-p', archive, entry], { encoding: 'utf8' });
}

function versionFromManifest(manifest) {
  const values = Object.fromEntries(manifest.split('\n')
    .filter(line => line.includes('='))
    .map(line => {
      const index = line.indexOf('=');
      return [line.slice(0, index), line.slice(index + 1).trim()];
    }));
  return [values.major_version, values.minor_version, values.build_version].join('.');
}

export function verifyPackage() {
  const archive = fileURLToPath(new URL('out/aeriotv-roku.zip', root));
  const packageVersion = JSON.parse(readFileSync(new URL('package.json', root), 'utf8')).version;
  execFileSync('unzip', ['-tqq', archive], { stdio: 'inherit' });
  const entries = packageEntries(archive);
  assertPackageEntries(entries);
  const manifestVersion = versionFromManifest(packageFile(archive, 'manifest'));
  if (manifestVersion !== packageVersion) {
    throw new Error(`Version mismatch: package ${packageVersion}, ZIP manifest ${manifestVersion}`);
  }
  console.log(`Verified out/aeriotv-roku.zip (${packageVersion}, ${entries.length} files)`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) verifyPackage();
