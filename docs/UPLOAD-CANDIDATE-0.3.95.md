# Roku signed candidate 0.3.95

This candidate integrates the previously native-tested 0.3.94 `live`,
`livefeed`, and `liveFeed` deep-link aliases into `dev` alongside owner-scoped
Dispatcharr live-HLS disconnect. Media IDs still resolve only against the
current authorized lineup. HLS uses the authenticated stream entry to acquire
an opaque per-client token before passing the returned playlist to Video;
Stop/retune/terminal failure send the owner's DELETE, never a shared-channel
Stop. An abrupt Home/power/network loss still relies on Dispatcharr's inactive
client reaper. Direct providers, DVR and MPEG-TS are unaffected.

`npm run release:prepare` passed the model, tool, compiler, package and ZIP
checks (198-file source ZIP); the production dependency audit found zero
vulnerabilities. The versioned ZIP installed on a Roku 3820RW2 / OS 15.3.4,
and its saved account loaded the authorized 36-channel guide. The Roku Packager
reported the existing matching developer ID and the installed ZIP's exact MD5.
The signed package has the same `Roku Channel PakV 2.0` header as the prior
0.3.94 package. These ignored local artifacts pass `SHA256SUMS-v0.3.95`:

| Artifact | Local path (from project root) | SHA-256 |
| --- | --- | --- |
| Signed Dashboard candidate | `out/release/P3af44c36c4e9cffd8f78f251b73684e0.pkg` | `ecc38bb253a35de318cc2a29b8207aaa0bcef42dfa2357d273bbe2b3c3527f3d` |
| Developer Mode ZIP | `out/release/aeriotv-roku-v0.3.95.zip` | `de05a95f70e21188def87c6a355acc9283063bf682d2cdc8ddef3f6fcc01152a` |

The same HLS source was tested in an isolated 0.3.94 Roku build: live HLS
reached native `playing`, a retune sent one owner DELETE (HTTP 204), and Stop
sent a second (HTTP 204). The 0.3.95 signed `.pkg` is created for Dashboard
upload; it is not itself installed as a separate app or cloud-certified. A
native `playing` event is not TV-side picture/audio confirmation. No private
channel IDs, server URL, session token or signing credentials are recorded.
