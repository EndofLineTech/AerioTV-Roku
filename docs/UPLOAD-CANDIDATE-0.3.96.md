# Roku signed VOD candidate 0.3.96

This candidate packages the VOD work committed to `dev` after the previous
signed v0.3.95 candidate: account-scoped Recently Watched, To Watch and
independent Favorites for Dispatcharr and direct Xtream-compatible connections.
The VOD implementation was exercised on Roku
3820RW2 / OS 15.3.4 before the version-only bump; see
[VOD saved lists](VOD-SAVED-LISTS.md#native-verification--2026-10-07).

`npm run release:prepare` passed model, tooling, compiler, build and ZIP checks
for the 198-file v0.3.96 source archive. The **exact versioned ZIP** installed
on the same Roku under its existing developer identity; ECP reported `dev`
v0.3.96 and a native screenshot showed the authorized 36-channel Main guide.
Roku's Packager reported the same recorded Dev ID as v0.3.95 and installed
source MD5 `87af33b657dfde8addad9ca7ac3ba3a2`, matching the versioned ZIP.
Using the existing signing key, Packager generated a same-identity encrypted
`.pkg`. Its `Roku Channel PakV 2.0` header matches the previous signed candidate.

| Artifact | Ignored local path (from project root) | SHA-256 |
| --- | --- | --- |
| Signed Dashboard upload candidate | `out/release/P6a9265facdf6378b1de4bfaf04c6e347.pkg` | `08ec952a8269be3b10efbb909dc7bc2da0183708d693d192650e5b5af26ccdb8` |
| Developer Mode sideload ZIP | `out/release/aeriotv-roku-v0.3.96.zip` | `80fbe66c280f4dc3d8c1c40a0519ad230304e90e827acd0fa16d999fbb55bc1f` |

Both pass `out/release/SHA256SUMS-v0.3.96`. The previous v0.3.95 ZIP and PKG
still pass their own checksum file. Upload the `.pkg`, not the ZIP, to Roku's
Developer Dashboard if pursuing a submission; no upload, cloud certification,
physical decoded picture/audio verification, or new end-of-title EOF test is
claimed here. Private device screenshots stay ignored under `out/`. No provider
URL, media identifier, account or signing credentials are included in this doc.

The version metadata lives in `manifest`, `package.json` and
`package-lock.json`; these ignored packages are not tracked Git release assets.
