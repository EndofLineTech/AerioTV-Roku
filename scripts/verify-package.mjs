import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const root = new URL('../', import.meta.url);

export function assertPackageEntries(entries) {
  if (!entries.includes('manifest')) throw new Error('Package must contain manifest at its root');
  for (const required of ['images/LICENSE.txt', 'images/NOTICE.txt', 'images/material-icons-LICENSE.txt']) {
    if (!entries.includes(required)) throw new Error(`Package is missing ${required}`);
  }
  if (!entries.some(entry => entry.startsWith('source/'))) throw new Error('Package is missing source files');
  if (!entries.some(entry => entry.startsWith('components/'))) throw new Error('Package is missing component files');

  const excluded = /(^|\/)(?:\.beads|node_modules|out|scripts|tests)(?:\/|$)|(^|\/)\.env[^/]*$|(^|\/)(?:package(?:-lock)?\.json|\.gitignore)$|^(?:LICENSE|NOTICE)\.md$/;
  const invalid = entries.find(entry => excluded.test(entry));
  if (invalid) throw new Error(`Package contains excluded development file: ${invalid}`);
  if (entries.includes('pairing-test-build.json')) throw new Error('Package is a pairing test build, not a shipping package');
  const probe = entries.find(entry => /(^|\/)(?:fixture-materials\.json|apply-cases\.json|SetupReceiverProbe[^/]*|SetupReceiverFixtureEntropy\.brs|SetupApply(?:Probe|Fixture)[^/]*)$/i.test(entry));
  if (probe) throw new Error(`Package contains synthetic setup probe: ${probe}`);
}

export function assertShippingManifest(manifest) {
  if (/^\s*aeriotv_pairing_test\s*=/mi.test(manifest) || /^\s*title\s*=.*pairing test/im.test(manifest)) {
    throw new Error('Pairing test builds cannot be used as Beta/Store packages');
  }
}

export function assertShippingArchive(archive) {
  assertPackageEntries(packageEntries(archive));
  assertShippingManifest(packageFile(archive, 'manifest'));
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
  const manifest = packageFile(archive, 'manifest');
  assertShippingManifest(manifest);
  const manifestVersion = versionFromManifest(manifest);
  if (manifestVersion !== packageVersion) {
    throw new Error(`Version mismatch: package ${packageVersion}, ZIP manifest ${manifestVersion}`);
  }
  console.log(`Verified out/aeriotv-roku.zip (${packageVersion}, ${entries.length} files)`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) verifyPackage();
