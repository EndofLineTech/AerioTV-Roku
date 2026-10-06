# Roku upload candidate 0.3.92

This candidate advances committed `dev` v0.3.91 with the PO-approved EPG
category-color removal and bounded first-paint logo prefetch. Unfocused
program cells remain neutral; focus, status badges, real logos and program
details remain. The EPG color performance investigation is documented in
`GUIDE-FIRST-PAINT-0.3.91.md` and removal acceptance in
`GUIDE-CATEGORY-COLORS-REMOVED-0.3.91.md`.

`npm run release:prepare` passed all model, package, Python tooling,
BrightScript compilation and ZIP checks; the exact source ZIP has 195 files.
The Streaming Stick 4K 3820RW2 / Roku OS 15.3.4 accepted the versioned ZIP
in its dev slot and ECP reported `dev` v0.3.92. A native local capture after
installation showed the authorized 36-channel EPG with neutral unfocused
program backgrounds, distinct focused selection, LIVE/NEW pills and provider
logos. Screenshots remain ignored locally and contain account-specific titles.

Roku's Packager reported the previously recorded **matching Dev ID** and an
installed-source MD5 identical to the versioned ZIP. It generated a new
same-key encrypted `.pkg`, which passed the previous Roku package header
check. The two exact artifacts also pass `SHA256SUMS-v0.3.92`:

| Artifact | Local path (from project root) | SHA-256 |
| --- | --- | --- |
| **Streaming Store upload** | `out/release/P3eb49c7a66676e95c3e6c655e25c5cec.pkg` | `1609ac3686207a5d032736d677bcda95cc584f98651091f294ecd8f535f6976d` |
| Developer Mode sideload source | `out/release/aeriotv-roku-v0.3.92.zip` | `2ecf60cd883a25fd3bd26cd79226d4f15752405fef809cafe2dba9688f0a4bae` |

Both paths are ignored local artifacts, not Git-tracked binaries. Upload the
`.pkg` for Roku Developer Dashboard analysis; the ZIP is only for sideloading.
Static and App Behavior Analysis on this signed candidate have **not** run.
Previously reported cloud-device reboot and deep-link/sample requirements
remain unresolved; a local sideload launch is not a Store acceptance claim.
No account credentials or signing password are recorded in this document.
