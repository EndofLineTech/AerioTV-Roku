# Full-application pairing test build

This is the real AerioTV application with the normal Welcome/Manage entry,
receiver, provider verification, confirmation, credential/connection transaction
and Guide handoff. It is **not** the standalone probe, a fake provider scene or a
memory-registry harness.

The only application overrides are the device-key-conditioned test entropy
provider, a visible pairing-screen warning and the test title/manifest marker.
`source/Main.brs`, `AerioScene`, the receiver Task, verification Tasks and
`PhoneSetupStore` remain byte-identical to the normal base ZIP.

**This is a controlled developer test, not an approved production/Store release.**
The source works in native tests, but its minimum cryptographic entropy has not
been established. The default shipping provider remains fail-closed. Use a
disposable/test provider account for initial phone testing. Do not infer security
approval, profile/PIN import, Sync enablement or unsupported guide settings from
a successful receipt.

New-account transfers now **save automatically after successful provider
verification and open the guide**. Sending from the phone authorizes addition;
there is no second Save confirmation. Duplicate accounts still require an explicit
Cancel / Add Anyway / Replace choice. See the auto-guide candidate below.

## Build

```sh
npm run verify
python3 scripts/build-pairing-test.py --enable-device-key-test
```

Artifacts are separate from `out/release/`:

```text
out/pairing-tests/aeriotv-roku-v<version>-pairing-test.zip
out/pairing-tests/SHA256SUMS-pairing-test-v<version>
```

Verify the checksum from inside `out/pairing-tests/` before installing. The builder
records the normal base ZIP's SHA256 inside `pairing-test-build.json`; it does not
overwrite that base ZIP or modify production source. It refuses probe inputs,
already-enabled inputs, old bases missing the uppercase-key fix and release output
directories. It requires explicit opt-in on every invocation.

The normal package verifier, release preparer and signed-package naming tool
reject the marked candidate. Do not rename it to a Beta/Store ZIP or submit it to
Roku Packager as a release candidate. No signing-key regeneration is required.

## Owner phone test

1. Install the exact checksum-verified test ZIP using the Roku Developer Mode
   installer on the target Roku. This replaces the development-slot app; it is
   not a Store installation. Keep the verified normal ZIP for rollback.
2. On a new installation choose **Set up from phone**. With saved connections,
   open **Connection > Manage saved connections > Set up from another device**.
   From the Guide, **Settings > Connection > Open connection settings** reaches
   the same Connection screen.
3. Confirm the **PAIRING TEST BUILD** warning. Wait for the QR and six-digit code.
   Keep the phone and Roku on the same network.
4. In AerioTV on the phone, open **Settings > Playlists > your test playlist >
   Set up another device**. Select the discovered Roku and enter its six-digit
   code, or scan the Roku's QR. Discovery is advertised only while that setup
   session is active. **New Code** replaces the key/code; reopen the phone's
   device list if it still shows the previous session.
5. Wait for Roku provider verification. Read the omission/session-only warnings.
    A received HTTP 200 means receipt, **not** saved credentials or verified access.
6. A verified new account is added automatically and opens the guide. **Send only
   when intending to change the Roku's saved connections.** Session-only and
   unsupported-setting notices are nonblocking; details are in **Settings >
   Diagnostics**. Duplicates offer **Cancel / Add Anyway / Replace**,
   with Replace focused. Replace retains the existing slot identity. Four slots
   is the maximum. Never choose Forget merely to make an automated test pass.
7. Confirm the authorized lineup and Guide. Then relaunch to test the documented
   persistence policy: Dispatcharr's verified API key can be remembered; Xtream
   credentials and token-bearing M3U URLs remain session-only.
8. Restore the verified normal ZIP when finished. Restoring code does **not** undo
   a connection added/replaced during the test. Do not send a valid new account
   if the existing roster must remain unchanged: verification can complete and
   commit before a remote Cancel is processed.

Do not attach QR/code screenshots, keys, credentials, URLs with tokens or raw
console dumps to test reports. Record only provider type, step, outcome, timing,
whether Save was chosen, and any non-sensitive error text.

## Automated no-save smoke

Supply `ROKU_HOST` and `ROKU_DEV_PASSWORD` through the environment, then run:

```sh
node scripts/test-pairing-app-native.mjs \
  out/pairing-tests/aeriotv-roku-v<version>-pairing-test.zip \
  out/native-parity-normal.zip
```

This macOS/Swift runner uses the actual full-app ZIP and remote-control UI. It
reads the live QR, checks that New Code replaces it with a different key, then
sends a fresh X25519/HKDF/AES-GCM envelope containing a synthetic
M3U URL on a closed Roku loopback port, checks real provider-verification failure,
retries without resending, and cancels back to normal setup. It never selects
Save, Add Anyway, Replace or Forget. It does not claim that the full Guide/save
path or a real phone sender passed. Native startup can perform the app's usual
reads/refreshes for an existing selected connection.

The synthetic URL deliberately fails verification. This is essential now that a
successful new-account verification commits automatically; not pressing Save is
no longer sufficient to make an arbitrary valid-payload test non-mutating.

The runner requires the previously verified normal 0.3.100 restore ZIP SHA256
`eb09f4b9705262d11efba05a7b27281ff6272f2b22ff0f003805d9e20224a610` and restores
it in `finally`. UI recognition emits only allowlisted state booleans/counts;
screenshots are deleted immediately and QR links/codes never logged. Results are
in `out/pairing-app-native-results.json`.

Only when intentionally handing the test app to the owner, use
`--discovery --leave-installed`. After all no-save checks pass, this opens a
fresh discoverable pairing session, verifies the active test app, and leaves it
installed. Failures still restore the verified normal ZIP. Do not combine this
handoff option with `--expiry-only`.

On the tested OS15.3.4 Roku, the full-app entry/QR, encrypted receipt into real
verification, retry and cancellation all pass for the 0.3.100 candidate. Real
iPhone/Android receipt, explicit Save/Replace, playback and relaunch are separate
owner acceptance steps—not inferred from this automated smoke.

## Bonjour discovery checks — 2026-11-11

For the later Xtream channel-logo fix and its updated test ZIP, see
[XTREAM-CHANNEL-LOGOS.md](XTREAM-CHANNEL-LOGOS.md). The discovery-only artifact
below remains preserved as the earlier verified rollback build.

The receiver advertises `_aeriotv-setup._tcp.local.` (not the companion service
`_aeriotv._tcp`). Public TXT contains only `v=1`, `name`, a standard padded-base64
32-byte `pk`, and `kind=tv`. The code is never advertised. The Task owns bounded
DNS parsing, multicast responses, name probing/conflict suffixes, SRV/TXT/A cache
flush, key refresh, and TTL-zero goodbyes on cancellation, receipt and expiry.
Nothing is advertised when the default shipping entropy gate refuses setup.

To run the additional no-save checks, append `--discovery` to the smoke command.
Append both `--discovery --expiry-only` for a separate real ten-minute expiry run.
These use macOS `NWBrowser` with the actual iOS TXT filters, then Apple's
`DNSServiceResolve`/`DNSServiceGetAddrInfo` and curl HTTP contact at the **discovered**
IPv4 endpoint. New Code, three-wrong-code TXT replacement, receipt and cancel
removal are exercised through the real app. Evidence files are
`out/pairing-discovery-native-results.json` and
`out/pairing-discovery-expiry-native-results.json`.

The helper also attempts the iOS `NWConnection` handshake, but that path has not
reached ready on this Mac (direct-IP Network.framework connections also fail).
Do not treat the independent Bonjour + curl checks as proof that the iPhone's
own Network.framework path passed. Actual iPhone discovery/transfer is an owner
acceptance step; the Mac test establishes valid advert contents, IPv4 resolution,
reachable receiver, refresh and lifecycle removal.

Discovery test candidate:
`out/pairing-tests/discovery/aeriotv-roku-v0.3.100-pairing-test.zip`, SHA256
`28343bb7dbedd91c7c0ed353a8915cd1485a79f67b599ae193fcf2e78b149601`.
It retains the same developer-only entropy warning and release/signing guards.

This exact candidate passes the final eleven-check no-save/handoff smoke and a
real ten-minute discovery expiry run (eleven refreshes, two successful goodbyes
and socket stops across New Code and expiry). It was left installed with a fresh
discoverable session for the owner. One earlier expiry-removal timeout was not
reproduced after adding lifecycle diagnostics; its cause is **not claimed fixed**
and remains tracked in `AerioTV-Roku-e3e.2.9.1`.

The UI harness now checks the actual setup QR instead of OCR of the random key
fingerprint. Run its offline synthetic-image regressions on macOS with
`swift scripts/test-pairing-ui.swift`. No screenshots or QR payloads are logged.

## Automatic guide handoff candidate — 2026-11-11

`AerioTV-Roku-ufu`: new accounts skip the redundant confirmation, while verified
identity matching, four-slot capacity, concurrent-roster checks and the single
atomic credential/roster Flush remain mandatory. Duplicates retain explicit
choices and Replace focus. Omission/session-only text moves to a nonblocking
guide notice/footer plus individual Diagnostics records; Sync is not enabled.

Unit tests prove automatic commit/handoff with no dialog, stale-roster refusal,
write rollback and full-roster refusal. The isolated real-HTTP native controller
suite passes eleven checks, including four automatic new-account cases **without
remote Select**, nonblocking disclosures, duplicate choices, cancellation and
capacity refusal. It uses a memory registry and a stubbed application navigation
handoff, followed by real GuideTask JSON/XMLTV loads—not owner-account saves or
proof of the full production GuideView after a real phone transfer. Evidence:
`out/setup-apply-http-native-results.json`.

Updated full-app developer candidate:
`out/pairing-tests/auto-guide/aeriotv-roku-v0.3.100-pairing-test.zip`, SHA256
`40bd99329ff0c33fb4be807690970ba7d2ddd3b4add64bee0f9f7b079739794c`.
Only the phone import controller/model and base-checksum marker differ from the
owner-confirmed Xtream-logo build. The logo fix, discovery and explicit developer
entropy warning remain; no signed Beta/Store/security approval is implied.
