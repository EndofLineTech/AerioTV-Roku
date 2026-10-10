# 0.3.97 beta test candidate

This candidate contains the bounded EPG-mapping detail fallback described in
[LARGE-EPG-MAPPINGS.md](LARGE-EPG-MAPPINGS.md), plus aggregate on-TV diagnostics
for follow-up logo loads. It does not claim to repair missing follow-up logos
until their diagnostic cause is known.

`npm run release:prepare` passed, producing a verified 199-file developer ZIP.
The exact ZIP was temporarily installed on a Roku 3820RW2 / OS 15.3.4;
Packager reported a matching source MD5 and the same established Dev ID as
the previous signed candidate. Packager encrypted the installed source with
the existing signing identity, and the prior v0.3.96 developer ZIP was
restored afterward.

| Artifact | Local path | SHA-256 |
| --- | --- | --- |
| **Beta channel upload** (signed) | `out/release/aeriotv-roku-v0.3.97.pkg` | `84d6accccc8fbd26171fa6c1ea599603a23d76378d4fb76e1b01599c0c0f9bd8` |
| Developer Mode ZIP | `out/release/aeriotv-roku-v0.3.97.zip` | `3ec28b07845043506b08b82ac3d5097e28a1ad2ae440e1e40652b902c69d64e8` |

Both artifacts pass `out/release/SHA256SUMS-v0.3.97`. Upload the **`.pkg`**, not
the ZIP, to the Beta channel. The encrypted `.pkg` is a Dashboard upload
candidate; it was not independently installed or submitted to the portal.
Credentials and account identifiers are not included in this document or the
package.
Roku's original opaque filename is retained locally for provenance; the
versioned copy has identical bytes and is the upload artifact. Future packages
use `npm run beta:package -- /path/to/P<hash>.pkg` after signing.

## Native smoke — Roku 3820RW2 / OS 15.3.4

Installed the exact source ZIP used for signing on the owner's Roku (dev
version reported 0.3.97). Its saved account loaded a populated **36-channel**
guide with real programs and the first six logos. ECP Down navigation scrolled
past the first six rows; the newly visible channel logos appeared in the
developer-mode screenshot. One current live tune reached native media-player
`play` with `error=false`; Back stopped it (`close`, `error=false`) and returned
to the guide. Developer-mode video screenshots render the hardware video plane
black, so this is not a picture/audio sign-off.

To exercise the otherwise-unreached oversized-list path on this smaller
account, a disposable ZIP derived from the exact source ZIP forced only
MappingTask's oversize branch and skipped its warm cache. Native console
reported `[guide-mapping] source=details links= 36 ms-after-lineup= 899`;
the guide showed programs and logos. Reinstalled the unmodified signed-source
0.3.97 ZIP afterward; ECP reported dev 0.3.97 and the guide remained usable.
The probe ZIP is ignored under `out/` and is **not** the signed beta package.
Private screenshots also remain ignored under `out/`.

The affected user's **91-channel** server with an actual >16 MB list and its
reported missing logos still needs a beta-account test. This device verifies
the per-ID request path with 36 authorized assignments, not the 91-channel
server's timing, permissions, or artwork.
