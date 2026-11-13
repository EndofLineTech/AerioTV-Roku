# Profile primitive qualification

Scope: `mrr.5`, `mrr.12`, `mrr.13`, `mrr.16`. This is evidence for prerequisite
work, **not** delivery of multi-user profiles, sync, certified PIN flows or a
signed release. Product/behavior contract: [PROFILES-CONTRACT.md](PROFILES-CONTRACT.md).

## Device and isolation

Native runs used the owner-authorized Streaming Stick4K3820RW2, OS16.0.4 build853,
1080p. The installed developer ZIP was matched through the installer's MD5 to
`out/pairing-tests/pill-ui/aeriotv-roku-v0.3.100-pairing-test.zip` before replacing
it. Its SHA256 is
`91f8b8b1f3c2f45e625588e198b8f0a66af963ea285d49e1a27483461afb8734`.
The primitive runner verifies the same MD5 again after restoring it, including
after failed assertions. The single development slot is temporarily replaced;
the probes never initialize the normal application or use real provider accounts.
No signing key, device policy, provider account or App Data was changed.

HTTP fixtures listen only for the authorized Roku on the local network, use
public synthetic values, validate the actual method/content type/UTF-8 length/
bytes, and shut down after each run. Registry capacity tests use a newly
UUID-namespaced section; they never enumerate/read owner application sections.
Every candidate's section is deleted/flushed and its own key list is verified
empty. UUID here names a disposable section; it is not approved cryptographic
randomness. Credentials remain in the process environment, not source/reports.

## Interim receiver (`mrr.12`)

The production validator/preparer/controller now:

- Tolerates unknown role/PIN types using the corrected empty/none contract.
- Uses only the default credential, ignores non-default credential material and
  never includes PIN hash/salt in its prepared or persisted slot.
- Treats a single entry as default regardless of its isDefault flag.
- Refuses Child/PIN-protected defaults before creating a verification Task or
  registry candidate, per explicit owner decision.
- Shows the exact multiple-profile notice on screen when extras were ignored;
  default-only/user-only imports receive no such notice.
- Keeps Sync opt-in, verified-account automatic guide handoff, duplicate
  Cancel/Add Anyway/Replace, capacity checks and failure rollback intact.

Host tests were written first; the native real-HTTP controller matrix then
passed14 cases, including duplicate flows, password exchange, XC/M3U, protected
default refusals, and a three-profile unprotected-default variant with unknown
enums. The fixture HTTP server rejects any non-fixture key, so attempting an
ignored credential fails the run. The original protected-default fixture16.5
must now refuse under the owner's decision6, not import an unrestricted slot.

Evidence: `out/setup-apply-http-native-results.json`. The actual notice capture
`out/profile-interim-multiple-notice.jpg` was inspected: readable, fully contained,
exact sentence. It is an isolated production-controller surface, not a real
authenticated household import. The shipping receiver remains entropy-gated.

## HTTP and strict JSON (`mrr.13`)

Native red tests confirmed that the old transport discarded error bodies and
sent POST instead of PUT/PATCH. Two additional native findings required explicit
handling rather than trusting off-device tests:

1. With `RetainBodyOnError(true)`, this firmware returns a failed GET body on
   `roUrlEvent.GetString()` without creating the requested tmp download file.
   The transport reads that bounded retained event body before tmp cleanup, with
   **no second request with the rejected key**. Normal successful GET downloads
   remain file-backed/bounded. A synthetic401 body was retained exactly.
2. `ParseJson(text,"d")` does not force every floating literal to roDouble.
   Integral1.0 is a native Float, and native FormatJson emits1, changing its JSON
   literal kind. FormatJson also shortens high-precision Doubles. `StrictJson`
   recursively preserves exact key spelling, emits `.0` for integral floating
   values, and uses17 significant digits for Double values. Unsupported values
   and excessive nesting fail closed. Callers must still validate schema, total
   UTF-8 budgets and before/after preservation before any App Data write.

The final native primitive matrix passes retained GET401, actual PUT/PATCH,
application/json, exact UTF-8 Content-Length and unchanged checked raw string
(no string quoting or second serialization). Extended fixture16.4 includes three
profile rows, a tombstone, favorites, shared/TV/mobile settings, integral/fractional
floats, emoji, null, case-sensitive unknown objects/row tails, millisecond
timestamps, high-precision/exponent Doubles and a large integer. An independent
Python JSON reader verifies equal values **and recursive literal types** for the
serialized round-trip, not only Roku's own equality. ISO Z parsing and whole-second
writing also pass. Host suites inject typed values because brs/JavaScript already
lose integral-float spelling and do not qualify native crypto/network behavior.

Evidence: `out/profile-primitives-final.json`,
`out/profile-primitives-double-format.json` and
`out/profile-primitives-registry-verified.json`. Earlier `before`, `diagnostic`,
`precision` and first `registry` reports are failed development investigations,
not acceptance. The earliest probe itself also had an incorrect expected PIN
hash/type assumption; these were corrected to the supplied vectors before final
acceptance. Final PIN hashes below exercise the reusable production helper.

The owner approved `platform: "roku"` and an app minimum of OS14.6 (the precision
parsing API's introduction). This device qualifies OS16.0.4, not every OS14.6
device. No Developer Dashboard minimum-firmware setting has been changed or
claimed verified; final delivery must enforce/verify the chosen floor, including
developer-launch safety. There is no fabricated minimum-OS manifest attribute.

## PIN storage/entropy boundary (`mrr.5`)

`UserProfilePin` provides pure normalization, v2 record validation, fixed-work
digest comparison, and native SHA256(raw salt bytes || ASCII normalized PIN).
All four supplied numbers/directions vectors pass with the actual Roku digest.
Comparison checks every one of64 valid digest characters without a mismatch
early exit. BrightScript does not provide a machine-level constant-time
guarantee; this is fixed-work application comparison, not a claimed hardened
cryptographic runtime. Malformed records never count as a successfully verified
PIN. No plaintext PIN/hash/salt is logged by the production helpers.

Threat boundary: an app-local4–6-entry PIN deters casual profile switching. It
does not override server permissions, encrypt API keys, secure against a person
with developer access, or provide high-entropy account authentication. Roku
registry storage is not Apple Keychain: keys/PIN records must be treated as
sensitive data within the signed application's Dev-ID registry boundary, not
claimed hardware-backed encryption. PIN hashes/salts appear remotely only in the
specified own-user roster category; credentials, Device Admin PIN, active choice
and backoff never enter App Data.

The owner selected import/verify-only. No salt-creation API is offered, production
PhoneSetupEntropy is unchanged, and experimental roDeviceCrypto is not treated
as approved CSPRNG. New-salt actions and Device Admin/kid-only onboarding remain
excluded. Child introduction requires imported adult PINs; adding unpinned full
access while Child exists must refuse/skip. Remember off/Forget and default-key
protection are mandatory in subsequent storage/switch integration, not claimed
implemented by these primitive helpers. Secrets must not enter diagnostics,
screenshots, non-secret metadata or general exports.

## Registry measurements (`mrr.16`)

The verified run started with30930 bytes available. All five synthetic four-slot
fixtures saved/read back successfully, each with a full24000-byte uncompressed
preference payload, profile metadata and one54-character synthetic key per user:

| Profiles per slot, including default | Remaining bytes while fixture saved |
| --- | ---: |
| 1 | 12215 |
| 2 | 12600 |
| 4 | 13439 |
| 6 | 14306 |
| 8 | 15210 |

These are additional fixtures beside the owner's existing data. Different
compression of fixed-size preference contents explains why more profiles do not
monotonically cost more: repetitive account defaults replace high-entropy filler
inside the same24KB payload. This is **not** a claim that adding profiles frees
production space, or that future fully populated households fit. Registry
recompression changes accounting by a few bytes; deletion/empty-key assertions
are the cleanup proof, not an equality assertion on compressed free space.

The owner selected four profiles per slot initially. Preserve explicit save
failure/rollback handling and remeasure real implementation, migrations, pending
sync/hold metadata and populated per-profile blobs. The32KB compressed Dev-ID
registry and current5KB/24KB uncompressed app limits are distinct constraints.

## Native dialog and beacon qualification (`mrr.16`)

The final `out/profile-dialogs-native.json` passes. The standalone fixture uses
StandardPinPadDialog and StandardKeyboardDialog, not imitation keypads. Native
Lit_0–Lit_9 input is accepted, PIN input is capped at6, and4/6-entry lengths are
observed. Numbers masking, password secure mode, email/password domains, Back,
Options, Home/relaunch and launch Back exit are exercised. A second-dialog
request while the launch gate is up is blocked, and the fixture's protected
content never becomes visible. Numbers, password and launch-gate captures were
actually inspected (`out/profile-dialog-*.jpg`). An initial screenshot exposed
the last password character even with secureMode enabled. The shared
`uiSecureTextInput` helper now also enables optional secureLastCharacter where
supported, including the existing credential editor. Final native fields and
the inspected password image confirm all four synthetic characters are masked.
Images remain private artifacts (the OS keyboard can show its own mobile-input
QR); they are not committed or suitable for public sharing without redaction.

Two corrections to assumptions in the supplied prose are required on OS16.0.4:

- `wasClosed` is an event signal whose payload is invalid/null, not boolean true.
  Treat the current dialog's signal as cancellation. Waiting for `getData() =
  true` would fail to react to Back and could break the launch exit path.
- Options (`Info` in ECP) toggles native keypad highlight and leaves the PIN pad
  open. It does not generate wasClosed here. The gate stays covered/locked. Home
  exits the app at OS level; do not rely on a final script callback to secure it.

`StartupBeaconModel` factors the existing scene helpers without changing current
startup behavior, and exposes completeStartupDialog for the eventual picker/PIN
close boundary. Native fixture calls AppDialogInitiate, waits2 seconds for
synthetic selection, completes the dialog, then waits3 seconds for a simulated
slow lineup before AppLaunchComplete. Charged time is3000ms, below15 seconds;
repeat-completion behavior is also covered by host tests. This qualifies the
primitive/accounting sequence, **not** the latency of a real profile-enabled app
or an entire real lineup. Actual picker/deep-link integration and slow-provider
launch acceptance remain `mrr.8/.9/.10` work. Public Directions PIN delivery stays
certification-blocked; all-Directions households never become a no-PIN exception.
The separate public-acceptance dependency is `mrr.19`; recording an approved
developer-only phase in `mrr.17` does not close or bypass that external gate.

Earlier failed dialog reports were development investigations (including harness
focus/void-event/ECP-key/exit-observation assumptions), not passing evidence. The
fixture never displayed protected content during those investigations and the
checksum-matched prior app was restored each time.

## Reproduction

Supply `ROKU_HOST` and `ROKU_DEV_PASSWORD` via the environment. Do not copy real
values into shell history or committed documents. From the repository root:

```sh
python3 -m unittest scripts/profile_probe_test.py
python3 scripts/test-profile-primitives-native.py --registry --restore /path/to/verified-prior.zip
python3 scripts/build-setup-apply-probe.py --real-http
node scripts/test-setup-apply-native.mjs /path/to/verified-prior.zip --real-http
python3 scripts/test-profile-dialogs-native.py --restore /path/to/verified-prior.zip
```

Use a restore ZIP matched to the **currently installed** app, not blindly the
historical path above. Normal packages reject fixture markers/probe sources.
Build/test outputs are private ignored artifacts, not Beta/Store deliverables.
