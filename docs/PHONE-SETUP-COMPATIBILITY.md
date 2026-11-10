# Phone-assisted setup: wire-v1 compatibility

Research and implementation slice, 2026-10-28. Bead: `AerioTV-Roku-e3e.2`.
This is not an enabled sign-in feature or a successful phone-to-Roku transfer.

## Fresh-device-key receiver experiment — 2026-11-09

`AerioTV-Roku-e3e.2.7` tests a device-key-conditioned entropy candidate on the
existing OS 15.3.4 device, rather than waiting for documentation or upgrading the
runtime. The isolated build replaces only the entropy provider: encrypt a
domain-separated constant using `roDeviceCrypto` with the `device` scope, verify
the local decrypt round trip, hash the ciphertext, and return the requested bytes.
The ciphertext is treated as secret; neither it, its digest, private keys, codes
nor QR links are logged or persisted. There is no UUID/timing/Rnd/server fallback,
application-registry access or provider contact. Production entropy remains
unchanged. This is a **functional experiment, not a demonstrated CSPRNG guarantee
or an approved shipping source**.

Native measurements establish the following behavior:

- Device, channel and model encryption scopes passed **96/96** synthetic
  encrypt/decrypt checks at input sizes 1, 16, 32 and 64 bytes. Each group of eight
  repeated identical inputs produced eight different outputs. All **48/48**
  one-byte-tampered ciphertexts were rejected. Output length was input length +32.
- Another **256/256** device-scope encryptions succeeded without a repeated result
  in **1132 ms**. These observations establish availability and nondeterminism,
  not a particular cipher, key strength or entropy estimate.
- The receiver used **nine distinct, newly generated public keys**, read from its
  actual on-screen QR with fingerprint matching. The host generated fresh phone
  X25519 keys/nonces and sealed all six handoff payload shapes for those sessions.
  All six transfers succeeded in **6847–7197 ms** and refused replay after success.
  Vector IDs referring to fixed codes are only payload-shape names here: the
  active TV keys and codes were generated, not taken from those fixtures.
- Origin, malformed-envelope and invalid-UTF8 requests were rejected without
  publishing a payload. Three wrong-code attempts rotated the key on the same
  port; the old key was rejected and the new key accepted. Back during X25519
  closed the listener without publishing a payload. A real **ten-minute** expiry
  run (not accelerated and without keepalives) also closed the listener while
  allowing the normal screensaver behavior.

The fresh-key test found a real bug (`AerioTV-Roku-e3e.2.8`): native
`roByteArray.ToHexString()` emits uppercase private-key hex, while the X25519
decoder assumed lowercase. The QR public key was correct, but deriving the shared
secret from the stored hex produced `403 wrong_code` for a valid transfer. Existing
fixture entropy bypassed `phoneSetupNewMaterial()` and hid this path. Normalizing
the decoder fixes it; host uppercase/mixed-case checks and native-vector
byte-array round trips cover the regression: **13/13 native vectors** pass through
that encoding path, max **7111 ms**, within the 8-second primitive budget. Full
verification passes on both the owner's working tree (0.3.100) and a clean
committed-source snapshot (0.3.97). No private-key value was logged to diagnose it.

Evidence is local in `out/entropy-capability-native-results.json` and
`out/devicecrypto-receiver-transfer-results.json`, with expiry evidence in
`out/devicecrypto-receiver-expiry-results.json`. The runnable experiment is kept
on branch `spike/device-key-pairing` under `tests/spikes/device-key-pairing/`, not
merged into shipping source. Diagnostic screenshots are
deleted immediately after decoding. Each completed device run restored the
verified normal app ZIP. Real iPhone/Android sender acceptance and approved
shipping randomness are not claimed by this experiment.

## Real provider/Guide HTTP execution — 2026-11-09

Only **enabling real cryptographic pairing** is blocked on secure randomness.
Building and testing the remaining code does not depend on that gate. Guide and
catch-up option work (`AerioTV-Roku-e3e.5.2`) is unfinished implementation, not an
entropy blocker.

`AerioTV-Roku-e3e.5.3` adds a second native probe mode using the **unchanged
production DispatcharrTask, XtreamTask, M3uTask and GuideTask**, including the real
HTTP transport, downloads, JSON parsing and XMLTV file parser. Their synthetic
dependency is a server bound to **127.0.0.1 only on the Roku itself**. The registry
remains in memory; cache access is redirected to a private `tmp:` fixture
namespace so the normal app's cache cannot be touched. There is no external
provider/account contact and no shipping entropy bypass.

The HTTP suite passes ten controller scenarios plus transport/guide checks:
request rejection/retry/cancel, cancellation during actual I/O, all duplicate and
capacity choices, query-bearing M3U, Xtream, API-key-only default-profile fallback,
and dashboard-password exchange for a saved API key. HTTP headers prove candidate
User-Agent/Referer/auth isolation; the server observes the exact M3U query. Real
Dispatcharr profile requests select the requested two-profile union, excluding the
third channel. Six real GuideTask windows load (four JSON, two XMLTV), retaining
the exact programme interval while excluding an unselected guide key.

This test found a pre-existing **native XMLTV timestamp bug** (`e3e.5.4`):
`1700000100` became `1700000128`, a 28-second shift. `Val()` returned Float for
timezone components, promoting the Unix epoch even for a zero offset. Integer
`ToInt()` parsing fixes it. Native UTC, +02:30 and -05:30 checks now retain exact
integer seconds, as do actual downloaded M3U/Xtream guide programmes. Host tests
alone did not expose the native Float rounding.

```sh
python3 scripts/build-setup-apply-probe.py --real-http
node scripts/test-setup-apply-native.mjs out/native-parity-normal.zip --real-http
```

The runner restores the normal app in `finally`. Evidence, request-family counts
and guide-window sources are in `out/setup-apply-http-native-results.json`; no
URLs, headers or credentials are logged. Builder tests verify byte-identical
production Task implementations, loopback binding, cache isolation and the
absence of application-registry access. The original fake-provider probe still
passes as a separate, faster controller regression mode.

This is genuine provider-Task/GuideTask integration against a synthetic HTTP
dependency, **not** acceptance against a deployed Dispatcharr service, a full
GuideView/video playback test, or a transfer from a real phone. Those distinctions
do not prevent further implementation or testing.

## Verified playlist apply controller — 2026-11-09

`AerioTV-Roku-e3e.5.1` now includes Welcome and Manage Connections entries,
provider verification, retry/cancellation, duplicate confirmation and transactional
saving. **Normal sessions remain disabled by the shipping entropy provider**:
opening the screen reports secure setup unavailable and does not open a listener.
Manual setup remains available. No weak randomness or probe bypass is enabled.

After receipt has written its entire 200 response, the controller verifies the
candidate with the existing Dispatcharr/Xtream/M3U Tasks. It does not change the
selected slot, runtime credential, request globals or saved connection during
verification. Explicit per-Task request identity prevents the old connection's
User-Agent/Referer from leaking into candidate requests. Failed/empty verification,
Back and stale Task results cannot commit a slot.

Only an explicit confirmation saves. Duplicates offer **Cancel / Add Anyway /
Replace**, initially focused on Replace. Replace retains the chosen matching
slot ID/order, including at four-slot capacity. Multiple matches require choosing
which slot Replace would retain. Add Anyway cannot overwrite an unrelated slot.

Saving keeps the existing schema/key layout (`connectionsV1` plus `connKey_<id>`).
Roku's [ifRegistrySection documentation](https://developer.roku.com/dev/docs/ifregistrysection)
explicitly guarantees that writes between `Flush()` calls are transactional and
atomic. The verified key and roster therefore use **one Flush**, not a new
credential-reference format or a separate key-first commit. Write/flush failures
restore both cached values and flush the old pair; an unsuccessful rollback is
reported as a recovery condition and setup retry is disabled until restart.
The normal completion path does not rewrite an already committed import key.

Query-bearing M3U URLs (including queries at the host root) are passed intact to
the downloader and kept only in session memory. Saved metadata contains an empty
URL, a session-only flag and a source digest; preference identity remains scoped
without storing the token. Confirmation explains that the URL must be sent again
after restart. Xtream credentials likewise remain session-only. Dispatcharr API
keys are saved separately, never in the roster; API-key-only credentials require
no username. A default/single-profile credential fallback is supported without
importing household roles, profiles or PINs.

VOD enablement and supported Guide Days (1, 3, 7, 14) are applied once after commit,
then persisted through normal account preferences. Later reconnects do not undo
the viewer's own setting changes. Other Guide Days, nonzero catch-up offsets,
local URL failover and provider-inapplicable options are explicitly disclosed
before Save, not silently claimed as applied. These runtime gaps are tracked as
`AerioTV-Roku-e3e.5.2`. Token-bearing/unsupported XMLTV URLs are rejected with an
explanation rather than persisted. Household profiles/PINs are not imported and
Sync is never enabled from the payload. Multi-Channel-Profile selection is also
retained during lineup refresh and no longer prunes history outside the selected
view.

### Isolated native controller acceptance

Nine native scenarios pass: verification rejection/retry/cancel, cancellation
during verification, duplicate Cancel, Replace at capacity with stable slot ID,
Add Anyway with space, Add Anyway refusal at capacity, query-M3U session metadata,
Xtream session credentials and API-key-only default-profile fallback with omission
disclosure. The production controller/dialog/storage code runs with **an in-memory
registry, fake provider Tasks and a stubbed normal-Scene handoff**. No real account
is contacted and the application registry is not opened. This proves controller
behavior, not a real provider/phone transfer or Guide playback acceptance.

```sh
python3 scripts/build-setup-apply-probe.py
node scripts/test-setup-apply-native.mjs out/native-parity-normal.zip
```

The runner uses the already required curl client for read-only console capture,
ECP and installation; this also works on hosts where direct Node/Python LAN sockets
are unavailable. It does not change Roku settings or host permissions. Each run
restores the supplied normal ZIP in `finally`; the verified 0.3.100 restore was
used here. Results are in ignored `out/setup-apply-native-results.json`.
Package guards reject apply-probe scripts/fixtures, and isolation tests verify
that the probe cannot create a URL transfer or application registry section.

The older sections below are historical slices. Their statements that no setup
entry or apply controller exists are superseded by this section; the CSPRNG,
remaining runtime settings and real-provider/phone acceptance gates still apply.

## Serialized receiver and QR screen — 2026-11-09

Bead `AerioTV-Roku-e3e.2.6` adds an entropy-gated receiver Task and reusable
screen, not a completed onboarding/apply flow. The normal app still has no
setup entry and **cannot open a setup listener**: `PhoneSetupEntropy.brs`
returns `invalid` until a shipping CSPRNG is approved. No weak fallback,
fixture flag, real credential transfer, release, or DNS-SD announcement is enabled.

The isolated receiver package contains conspicuous synthetic-key warnings,
public RFC fixture materials, and no provider Tasks or registry operations.
It replaces the entire entropy file at build time; production packaging includes
only the fail-closed file. Never send real account details to a fixture package.

Implemented boundaries:

- `PhoneSetupTask` serializes bounded HTTP/1.1 receipt, authenticated decryption,
  session transitions and complete JSON replies. Header allocation stops at
  32 KiB, body allocation at 262144 bytes, and incomplete/15-second-idle clients
  close without applying. Cancellation is cooperative during scalar multiplication.
- `PhoneSetupCrypto.brs` rejects all-zero shared secrets and validates strict
  UTF-8 only after GCM authentication. Plaintext is not published until the full
  200 has been sent. A failed success reply ends the session without applying.
- Three wrong-code replies rotate keys/code on the same port without extending
  expiry. A response-time watchdog fails closed at ten seconds.
- `PhoneSetupView` displays code, fingerprint and a fully offline QR; Back
  cancels, New Code starts a new Task/session, and expiry/error states allow retry.
  QR uses fixed version 20, ECC H, legal mask 0 and an intact four-module quiet
  zone. Friendly name truncation uses both code-point and UTF-8 byte limits.
- `PhoneSetupX25519.brs` is now in production source for shared use by the gated
  Task and probes. This is **not** constant-time/security-review approval, nor
  permission to enable sessions without a suitable entropy source.

Native synthetic LAN acceptance on the same Streaming Stick/OS passed the
on-screen QR screenshot scan, all six positive payload shapes, null optionals,
unpadded base64url, fragmented exact-262144-byte bodies, malformed heads/envelopes/
plaintext, all-zero secrets, tampering, replay refusal, and three-failure rotation
with stale-key rejection. Extended lifecycle checks also passed both 15-second
idle disconnects, a valid request afterward, and Back cancellation during
cryptography with no success reply/payload and a closed listener. The slowest
full measured reply across these runs was **7733 ms**.
These are synthetic HTTP tests, not iPhone/Android sender acceptance or successful
provider verification. Normal 0.3.100 was restored afterward.

`npm run verify` passed both on the owner's working tree and on an isolated
archive of committed source. The latter intentionally retains baseline 0.3.97;
the owner's uncommitted version/cache work remains untouched at 0.3.100. These
checks do not create or sign a release. The existing moderate development-only
dependency advisory remains tracked as `AerioTV-Roku-tcn`.

Reproduce with developer access in the environment, never in source:

```sh
npm test
python3 scripts/build-setup-receiver-probe.py
node scripts/test-setup-receiver-native.mjs out/native-parity-normal.zip
# Also wait for the real ten-minute deadline (no accelerated fixture clock):
node scripts/test-setup-receiver-native.mjs out/native-parity-normal.zip --expiry
# Or run only the deadline check:
node scripts/test-setup-receiver-native.mjs out/native-parity-normal.zip --expiry-only
# Shorter lifecycle suite plus the real deadline (used after cancellation changes):
node scripts/test-setup-receiver-native.mjs out/native-parity-normal.zip --lifecycle-only --expiry
# Separate probe with the shipping entropy file, expected to refuse setup:
python3 scripts/build-setup-receiver-probe.py --production-entropy
node scripts/test-setup-receiver-native.mjs out/native-parity-normal.zip --production-entropy
```

The runner restores the explicitly supplied normal ZIP in `finally`. It does
not sign a release, contact a provider or print QR links. Synthetic results and
the screenshot are under ignored `out/`. Do not run another installer while it
owns the device. Local tests compare QR matrices against checked-in output from
`qrcode@1.5.4`, verify probe-file isolation and exercise transport/name/code models.

Playlist application remains `AerioTV-Roku-e3e.5.1`: verification without changing
the saved/current connection, duplicate Cancel/Add Anyway/Replace, atomic slot
commit, query-bearing M3U session handling, incoming settings application and
explicit household-profile/sync omission messages. Preparatory metadata fields
and authorized multi-Channel-Profile union helpers are present; retaining an
option in metadata is **not** applying it. Guide Days and catch-up offset are
not yet wired to runtime behavior. Household profile import and sync remain
separate work, and sync must never be enabled just because a payload requests it.

`PhoneSetupApplyModel.brs` also prepares deterministic credential selection and
duplicate identity matching: playlist credential first, then an unambiguous
default/single profile; API-key-only credentials need no username; passwords are
not trimmed. Duplicate matching uses provider plus normalized server and verified
account ID (exact username only as a fallback), or a caller-supplied M3U source
digest. It never writes storage, trusts profile roles, automatically chooses a
replacement slot or applies a payload. A separate pure staging helper accepts
an explicit choice only after provider verification: Cancel changes nothing; Add Anyway respects
four-slot capacity; Replace must target a matched duplicate and retains its slot
ID/order. The UI choice and verification/atomic credential-commit controller are
still required.

Two initial idle deadline runs timed out waiting for the render-thread expiry
notification / Task terminal signal. Those are not passing expiry results.
Cancellation now uses observed message-port events instead of synchronously
reading `cancelRequested` from SceneGraph inside the socket/crypto loops; those
reads can depend on a render thread paused by a public screensaver. Isolated probe builds now
emit a non-secret terminal-state diagnostic directly from the Task **after**
socket/key cleanup, so the runner can distinguish listener expiry from a public
screensaver pausing SceneGraph callbacks. It then wakes the screensaver with a
single navigation key and checks the expired UI. No screensaver setting or
production diagnostic flag is changed.

After switching cancellation to message-port events, the native lifecycle rerun
**passed the real ten-minute deadline**, with Task-side cleanup, a closed listener,
and the expired UI after wake. Idle disconnects, successful receipt afterward and
cancellation during crypto passed again with that implementation. A separate
native build containing the **shipping entropy file** also refused setup without
advertising a session. Both runners restored the verified normal 0.3.100 ZIP.
This establishes the tested lifecycle boundaries, not CSPRNG availability or
real-phone/provider interoperability. Evidence is in
`out/setup-receiver-lifecycle-results.json` and
`out/setup-receiver-production-entropy-results.json`; the earlier full synthetic
matrix is retained as `out/setup-receiver-full-results.json`.

The sections below describe earlier implementation slices; statements that a
listener/QR/crypto adapter is still future work are superseded by this section.

## Native X25519 and offline handoff proof — 2026-11-09

Bead `AerioTV-Roku-e3e.2.4`. Owner-authorized temporary probe installs ran on
Streaming Stick 4K 3820RW2 (`GetModel()` 3820X2), OS 15.3.4, 1080p. Each run
restored the previously verified normal 0.3.100 ZIP (SHA256
`eb09f4b9705262d11efba05a7b27281ff6272f2b22ff0f003805d9e20224a610`).

| Native check | Result | Slowest measured case |
| --- | --- | --- |
| RFC 7748 / independent-host X25519 matrix | **13/13 pass** | **7123 ms** |
| Offline X25519 → HKDF-SHA256 → authenticated AES-256-GCM → payload validation | **6/6 pass** | **7115 ms** |
| Existing explicit-tag GCM matrix | **3/3 nonempty positives**; 15 native tag failures and 8 adapter tag-length rejections | Empty-plaintext edge still fails; expected runner exit 2 |

X25519 coverage includes both RFC Alice/Bob public keys, both shared-secret
directions, the RFC section 5.2 scalar/u vector, high-bit masking, noncanonical
`p+9`, three deterministic Node/OpenSSL-oracle inputs, and low-order 0/1/p
(which produce zero; a receiver must reject that shared secret).
The RFC Montgomery ladder (now `source/PhoneSetupX25519.brs`) uses
17 radix-2^15 limbs and exact Double accumulators. It was probe-only in this slice;
the gated receiver above now shares it. No constant-time or production-security approval
is claimed for the interpreted arithmetic, including carry correction branches.

The six handoff cases use the supplied plaintext shapes (full Dispatcharr,
user-only, API-key-only without username, Xtream, and both M3U forms), sealed by
`scripts/setup-handoff-vectors.mjs` with Node crypto and fixed synthetic inputs.
The minimal M3U envelope is asserted **byte-for-byte** against the supplied
envelope; the two HKDF PRKs/keys are also pinned to Appendix C. The other envelopes
are independently re-sealed from the supplied shapes, not a wholesale import or
execution of Appendix C. The native probe verifies PRK, key, exact authenticated
plaintext and retained option/profile/credential fields without printing them.

These timings include crypto and payload validation, **not an HTTP reply**.
They establish feasibility on this device, not the slowest supported model or
the 256 KiB transport case. Roughly 2.9 seconds remain in the ten-second budget;
serialized socket handling, contention, cancellation and actual sender acceptance
still require measurement. Key generation is another scalar multiplication and
belongs before showing/rotating the code, never before writing the third 403.

### Native-only defects found and corrected

The first arithmetic candidate passed the host interpreter but failed real RFC
inputs on Roku. Native `34359738367.0# \ 32768.0#` returns 65535 after narrowing
operands, and `Int(34359738367.0# / 32768.0#)` returns 1048576 after Float
rounding (the floor is 1048575). Carry division now uses a quotient below 2^24
and corrects a possible rounded-up result using exact Double comparison. The
test-only host adapter in `scripts/test-setup-x25519.mjs` models the measured
Float narrowing because brs 0.39 otherwise rejects Int(Double) entirely. It
does not modify dependencies or replace native proof.

The initial offline handoff run decrypted correctly but rejected every
Dispatcharr profile. Roku lowercases enumerated literal-AA schema keys, while
ParseJson preserves case-sensitive wire keys. Schema fields now use explicit
string pairs, retaining `apiKey`, `displayName`, `channelProfileIds`, etc. Host
regressions and the repeated six-case native matrix verify the fix.

The old capture lifecycle lost the installer auto-launch and timed out on its
immediate relaunch. The runner now connects/drains the console **before** installing
the probe, observes that fresh auto-launch, and restores in `finally`. Local fake
installer/console tests cover success, wrong results and incomplete results;
all three native modes were exercised afterward.

### Reproduce safely

Supply developer access through `ROKU_HOST` / `ROKU_DEV_PASSWORD` in the
environment; never put it in fixtures or evidence. Commands below replace the
single development slot and restore the explicitly supplied normal-app ZIP:

```sh
node scripts/test-setup-x25519.mjs
python3 -m unittest scripts/phone_setup_probe_test.py
node --test scripts/validate-phone-setup-native.test.mjs
python3 scripts/build-phone-setup-probe.py --x25519
node scripts/validate-phone-setup-native.mjs --x25519 out/native-parity-normal.zip
python3 scripts/build-phone-setup-probe.py --handoff
node scripts/validate-phone-setup-native.mjs --handoff out/native-parity-normal.zip
```

Synthetic native rows and typed completeness/timing verdicts are saved to
`out/setup-x25519-native-results.json` and `out/setup-handoff-native-results.json`.
No real account/provider is contacted; no registry data is read or changed.

### Randomness: a new official lead, not yet a BrightScript solution

#### Secure-random recheck — 2026-11-09

The live-pairing gate remains justified, with a now-explicit minimum-OS finding:

| Candidate | Evidence checked | Decision |
| --- | --- | --- |
| TypeScript `getRandomBytes()` | Official API promises OpenSSL `RAND_bytes`; [SDK source](https://gitlab.com/rokudev/rsg-sdk/-/blob/main/packages/runtime/src/crypto.ts) calls `roku.crypto.getRandomBytes()` and throws if the host is absent | Suitable primitive in that runtime, not a BrightScript implementation |
| Small TypeScript anchor-node bridge | [Getting started](https://developer.roku.com/dev/docs/rsg-sdk-standing-docs-getting-started-first-app) documents BrightScript field interoperability **and requires OS 16.0+**; overview still prohibits Store publication during beta | Possible future isolated sideload experiment, not an approved shipping solution |
| BrightScript `GetRandomUUID()` | [ifDeviceInfo](https://developer.roku.com/dev/docs/ifdeviceinfo#getrandomuuid-as-string) promises UUID v4/uniqueness, not CSPRNG unpredictability or failure handling | Do not use for pairing private keys or codes without vendor assurance |
| `roRSA` / newer OS APIs | [ifRSA](https://developer.roku.com/dev/docs/ifrsa) exposes loading keys, signing and verification, not key generation; [release notes through OS 16.0](https://developer.roku.com/dev/docs/release-notes) do not announce a BrightScript random-byte API | No supported source established by this review |

A fresh, read-only ECP device query returned model **3820RW2**, OS **15.3.4**,
build **2402**. The documented SDK prerequisite therefore excludes the available
test device. No firmware upgrade, SDK installation, runtime migration or live
pairing enablement was performed. This is a documentation/source audit and device
version check, not an on-device TypeScript CSPRNG test. Existing native
production-entropy fail-closed evidence remains the applicable runtime evidence.

**Security finding (CWE-338):** enabling an unproven PRNG for pairing would risk
credential confidentiality. Conditional severity **High (8/10, qualitative)**;
current residual risk **Low (1/10)** because the shipping provider returns
`invalid` before a session is advertised. A LAN attacker able to predict a
receiver private key could test six-digit code guesses offline against a captured
transfer's authentication tag; the code cannot replace private-key entropy. Hashing
UUIDs/timestamps does not establish missing unpredictability, and random-looking
samples/statistical tests cannot prove a CSPRNG. Upstream agreement alone also
cannot establish that an undocumented generator is cryptographically secure.

The concrete next unblock is **Roku confirmation of a Store-supported local
CSPRNG callable from BrightScript**, including minimum OS/device coverage and
failure semantics. Ask whether `GetRandomUUID()` is CSPRNG-backed on every
supported model/OS and suitable for secret-key generation, or request an explicit
random-byte API. If confirmed, implement exact-length/failure checks and fresh
independent key/code draws, then exercise native rotation, cancellation, code
rejection sampling and real-phone interoperability. Otherwise an OS-16-only
TypeScript bridge needs a separate approved experimental scope and still cannot
establish Store eligibility during the SDK beta. Manual setup remains available.

Roku's October 29 TypeScript SDK documentation now explicitly documents
[`getRandomBytes`](https://developer.roku.com/dev/docs/rsg-sdk-getrandombytes)
as backed by OpenSSL RAND_bytes / HW-backed `/dev/urandom`, via the runtime's
global crypto host. This is a documented CSPRNG **for that runtime**, not evidence
that the existing BrightScript channel can call it on OS 15.3.4. Establishing a
supported bridge/minimum OS is the next investigation; migrating runtimes is
not assumed. The current [RSG 2.0 overview](https://developer.roku.com/dev/docs/rsg-sdk-standing-docs-getting-started-overview)
documents incremental BrightScript/TypeScript field interoperability, but also
says SDK apps are **sideload-only during beta**, not publishable to the Streaming
Store, with general availability targeted for Fall 2027. Thus this is not yet
an established Beta/Store shipping solution even if a probe bridge works.
The [ifRSA](https://developer.roku.com/dev/docs/ifrsa) reference
provides signing/verification, not key generation. `GetRandomUUID` still has no
CSPRNG guarantee in its BrightScript reference. No UUID/timing fallback was
silently adopted. Secure receiver key/code generation remains a release gate.

No live listener, QR screen, HTTP negative/sequence suite, household-profile
import, sync, or real iPhone/Android transfer is delivered by these probes.

## November interoperability update — 2026-11-09

The owner supplied the **2026-11-08 Roku interoperability handoff**, based on
Apple main 1.8.45 and Android main 0.5.14, with Appendix A wire-v1, Appendix B
Dispatcharr Sync v3, and Appendix C synthetic vectors. This supersedes the old
sender-status assumptions below: **both Apple and Android senders ship**; neither
needs a Roku-specific wire change. Receipt is LAN-only, not a Dispatcharr API.

Bead `AerioTV-Roku-e3e.2.3` aligns the pure foundation with that handoff:

- Envelope ciphertext must be **longer than 16 bytes**. The future decryptor
  splits off exactly the last 16 bytes and attempts authentication; a missing or
  truncated tag on a longer field is `wrong_code`, not a guessed format error.
- `validatePhoneSetupRequestHead` validates a complete head, strips the query
  only for route comparison, refuses any case-insensitive Origin (even empty),
  checks session unavailability before size, rejects missing/duplicate/invalid
  Content-Length and any Transfer-Encoding, and checks oversized decimal lengths
  without integer overflow. Unknown normal client headers are tolerated.
- `validatePhoneSetupPayload` validates an already decrypted, UTF-8-decoded JSON
  object. All three source families, required playlist strings, strict known-field
  types, defaults/null-as-absent, Guide Days 0–14, multiple Channel Profile IDs,
  API-key credentials **without username**, profiles, PIN metadata and sync requests
  are represented. Unknown keys are ignored. It does not enable sync, trust a
  supplied admin role as server authorization, write credentials, or add profiles.
- `rotatePhoneSetupSession` resets attempts under a new generation but retains
  the original ten-minute deadline. Cancellation during rotation cannot revive it.
  The owner must write the third 403 before generating/replacing keys; New Code
  uses a fresh session rather than this rotation helper.

Tests exercise these pure boundaries, **not the complete supplied sealed-vector
suite**. The historical 27-case GCM matrix below is a separate primitive test,
not Appendix C's six positives, 43 negatives, and five sequences.

### Remaining delivery boundaries

`AerioTV-Roku-e3e.2` still owns production X25519 integration/security review and full reply timing (reply within
10 seconds of the last body byte; escalate scalar multiplication above roughly
8 seconds), protocol HKDF/GCM adapter, all-zero-secret rejection and strict
UTF-8 validation **before** ParseJson. Never use unauthenticated Update output.
Secure random generation remains unresolved: do not use `Rnd()` or silently
approve UUID/timing mixing. The proposed interim source requires agreement with
upstream. Code draws must reject values >= 4294000000, preserve leading zeros,
and use fresh keys/code on rotation. Session secrets stay in memory.

The HTTP helper is **not a listener**. A serialized `roStreamSocket` Task must
cap incoming header/body bytes while reading, receive exactly Content-Length
across fragmented reads, close incomplete/15-second-idle requests without reply,
write the entire JSON reply with Content-Length and Connection: close, then close.
Only authenticated, UTF-8-valid, validated payloads may consume a code. Write 200
before applying. No transport or setup screen is enabled by this foundation.

`AerioTV-Roku-e3e.5` owns QR/apply integration: QR-only can interoperate before
DNS-SD, but is not yet delivered. Use error correction H, unpadded base64url pk,
ASCII-unreserved percent encoding and one friendly name cut to 60 code points /
63 UTF-8 bytes. Add the exact screen copy, Back cancellation and expiry UX from
the supplied handoff. Duplicate handling must compare normalized server/account,
offer Cancel / Add Anyway / Replace (focused), verify before replacing the matched
slot in place, and handle all four slots occupied without overwriting another.
Incoming multi-profile selection must not be silently narrowed to today's single
Channel Profile slot field. Playlist-only delivery must disclose omitted profiles
on the TV; full profile import remains `AerioTV-Roku-e3e.4`.

DNS-SD remains part of `e3e.2`: stable probed instance name, `kind=tv`, SRV/TXT/A
additional records, in-place key updates, TTL/cache-flush rules and goodbyes. Never
use the separate companion `_aeriotv._tcp` service for setup.

Dispatcharr Sync remains `AerioTV-Roku-e3e.3` / its delivery successors, not a
prerequisite to playlist receipt. Appendix B identifies the API as
`/api/accounts/users/me/app-data/<username-derived-key>/`, with
`<user>.aeriotv` and the one-time legacy migration. A future implementation must
round-trip unknown categories, refuse writes of higher schemas, and obtain opt-in;
`sync.enabled` alone **never** turns it on. The older cross-device scope note's
unknown-API statement is historical, not current contract evidence.

No device installation, minimum-OS change, entropy exception, release package,
or joint iPhone/Android acceptance is claimed by this update.

**Correction after release-note research and native retesting:** Roku OS 15.2
added `setTag`/`getTag`. With those APIs, AES-256-GCM passes our nonempty-payload
authentication tests on OS 15.3.4. The earlier no-tag-interface tests below
were incomplete API usage, not evidence that Roku lacks GCM support.

## Contract and platform evidence

The [pinned upstream contract][contract] requires X25519, HKDF-SHA256 and
AES-256-GCM (12-byte nonce, 16-byte tag, no AAD), plus secure random code/key
generation. The receiver advertises `_aeriotv-setup._tcp`, displays an offline
QR and fingerprint, and accepts one encrypted payload during a ten-minute
session. Three failed decryptions rotate the code **and** key. The companion
remote service is separate. Apple sender/receiver were marked planned in this
old pinned revision; the November handoff above supersedes that status.

| Primitive | Official Roku evidence | Remaining proof |
| --- | --- | --- |
| HTTP listener | [roStreamSocket][tcp] documents bind/listen/accept | Real LAN HTTP lifecycle, bounded input and cancellation |
| DNS-SD | [roDataGramSocket][udp] provides UDP; this alone is not an mDNS responder | Multicast discovery/advertisement and mobile interop |
| HKDF-SHA256 | [roHMAC][hmac] supplies the underlying HMAC | Native RFC-vector execution, then protocol-specific derivation |
| AES-256-GCM | Native `aes-256-gcm` with explicit tag handling passes three nonempty host vectors | Empty payload fails; production adapter and phone interop remain |
| Authentication tag | [OS 15.2 release notes][release-notes] announce `setTag`/`getTag`, omitted from the interface reference | Native tag generation and modified-input rejection verified below |
| X25519 | No suitable documented primitive established by this investigation | Supported implementation and RFC 7748/interoperability vectors |
| Random key/code | [GetRandomUUID][device] documents UUID v4, not a cryptographic random-byte contract | Establish an appropriate entropy source; do not substitute `Rnd()` |
| QR | No implementation added | Offline encoding and real phone scan |

A successful `Setup` return for a cipher name is **not** proof of correct GCM
decryption or authentication. CBC/128-bit GCM cannot replace upstream's cipher
without a coordinated protocol change. A software X25519/GCM implementation
would need independent vectors, tamper tests and native performance evidence.

## Implemented foundation

`source/PhoneSetupModel.brs` validates version, envelope size/shape, strict
standard or URL-safe base64, raw field lengths, and Origin refusal. It returns
canonical encoded fields for a future crypto adapter. It does not decrypt or
apply credentials. The future HTTP reader must cap **bytes while receiving**;
this model's string-length guard does not replace that transport budget.

The pure session model records no secrets. It rejects expired, used, cancelled
and stale-generation attempts, rechecks expiry after asynchronous processing,
and closes the old generation on the third failed decrypt. A serialized
receiver must own transitions; `accepted` may only be supplied after both AEAD
authentication and plaintext payload validation. `expired` is an internal
session result for shutting down the waiting UI, not a new upstream wire error.

Unit tests cover these boundaries, including cancellation, replay, late results,
code rotation and malformed payloads that must not spend a code attempt.

## Synthetic native probe

```sh
python3 -m unittest scripts/phone_setup_probe_test.py
python3 scripts/build-phone-setup-probe.py
```

The standalone `out/phone-setup-probe.zip` contains only the synthetic Main,
model and simple results scene. It does not read the normal app's registry,
contact a provider, advertise a setup session or accept credentials. It checks
RFC 4231 HMAC, RFC 5869 HKDF and NIST AES-256 block vectors; records cipher
setup return codes; and binds/closes an ephemeral **loopback-only** TCP socket.
ECB here is only a primitive known-answer test, not a proposed transfer mode.

With developer credentials configured, use the existing controlled installer:

```sh
python3 scripts/run-native-probe.py out/phone-setup-probe.zip \
  --marker '[setup-probe] complete' --prefix '[setup-probe]'
```

This replaces Roku's single development slot. Restore the owner's exact normal
app ZIP afterward. The probe prints only synthetic result labels and model/OS,
not keys, LAN addresses or user data. It neither proves full TCP request handling
nor phone interoperability.

### Native results — 2026-10-28

Ran on Streaming Stick 4K (ECP model 3820RW2; `GetModel()` 3820X2), OS 15.3.4.
HMAC RFC 4231, HKDF RFC 5869, AES-256 block, loopback bind/listen and envelope
shape checks passed. `aes-256-gcm` Setup returned 0; `aes-gcm-128` and
`aes-gcm-256` returned -1 on this device.

The zero-key/nonce AES-256-GCM fixture was independently checked with Node
crypto. Native encryption returned 16 bytes rather than ciphertext plus the
16-byte tag. Native Process decryption returned invalid for ciphertext alone,
ciphertext plus the correct tag, and ciphertext plus a modified tag. Thus this
tested API path does **not** establish usable authenticated GCM decryption;
rejection of a modified tag alone is insufficient when the valid case fails.
X25519, secure entropy, DNS-SD/QR and Android interoperability remain unproven.

Python networking failed locally while Node console capture and curl digest
installation worked. Drain buffered console output and restart through Home
before capturing a run: the console can replay a prior probe's completion.
The normal 0.3.100 candidate was restored and ECP confirmed AerioTV active.
Restored ZIP SHA256:
`eb09f4b9705262d11efba05a7b27281ff6272f2b22ff0f003805d9e20224a610`.

### Reproducible authenticated-decryption matrix

`scripts/phone-setup-vectors.mjs` generates 27 fixtures with Node crypto and
checks their expected acceptance using authenticated host decryption. Four
positive fixtures use nonzero keys/nonces and plaintext lengths 0, 1, 16 and 37.
The 23 negative fixtures change keys, nonces, ciphertext or tags, or omit/truncate
tags. The host explicitly requires 16-byte tags, as the upstream contract does.

`tests/native/PhoneSetupMatrix.brs` runs each fixture through two candidate paths:
`Process(ciphertext || tag)` and `Update(ciphertext)`, `Update(tag)`, `Final()`.
Only a successful final result with exact plaintext counts as positive acceptance.
Early Update output never counts as authenticated. These tests cover the two
specified input arrangements, not hypothetical undocumented tag-control methods.

```sh
python3 -m unittest scripts/phone_setup_probe_test.py
python3 scripts/build-phone-setup-probe.py
# Supply device credentials in the environment. Pass the normal app to restore.
node scripts/validate-phone-setup-native.mjs out/native-parity-normal.zip
```

The runner discards buffered console data before launching a fresh probe, checks
fixture completeness and verdict types, writes synthetic per-case evidence to
`out/phone-setup-native-results.json`, and restores the normal ZIP in `finally`.
Exit 0 means at least one tested path passed the whole contract; exit 2 means
the complete matrix ran but neither path passed; errors indicate a failed run.

Actual target results (2026-10-28, same OS/device as above):

| Check | Process | Update/Final |
| --- | --- | --- |
| Valid authenticated plaintext accepted | **0/4** | **0/4** |
| Invalid fixtures rejected at finalization | 23/23 | 23/23 |
| Whole contract | **FAIL** | **FAIL** |

Encryption controls matched host ciphertext for all three nonempty plaintexts,
but none returned the appended tag; empty plaintext returned invalid. Streaming
decryption produced the correct pre-final plaintext for the three nonempty valid
fixtures **and their changed-tag counterparts**, then Final returned invalid.
Thus the raw cipher operation works for these vectors, but these tested paths
cannot complete authenticated decryption. Rejecting all inputs is not an AEAD
success. The runner deliberately exits 2 for this result. AerioTV 0.3.100 was
restored after the run. Resolving the tag interface (or implementing and validating
a compatible adapter) remains the next crypto work under `AerioTV-Roku-e3e.2`.

### Explicit tag API: supported for nonempty payloads

The [Roku OS 15.2 release notes][release-notes] explicitly announce `setTag` and
`getTag` for AES-GCM. The component/interface reference pages omit their
signatures. GitHub code search returned no examples combining `roEVPCipher`
with `setTag`; the authoritative lead was the release note, not search absence.

Native calls verified on this Roku:

```brightscript
cipher.setup(false, "aes-256-gcm", keyHex, nonceHex, 0)
cipher.setTag(tagBytes) ' roByteArray, separate from ciphertext
plain = cipher.update(ciphertextBytes)
tail = cipher.final() ' Must succeed before accepting any plaintext
```

For encryption, `cipher.getTag()` returns an `roByteArray` separately after
processing. Its 16 bytes matched the host oracle for all three nonempty vectors.

The new `settag-stream` path accepted **3/3 nonempty valid payloads** (1, 16,
37 bytes). It rejected all 15 full-length-tag negative fixtures at finalization;
the test adapter rejected the eight absent/truncated-tag fixtures before calling
crypto, enforcing the wire contract. The empty valid payload still returned an
invalid final result, so the full matrix retains exit 2 and reports the narrower
`nonemptyCompatible` result separately. An empty plaintext is not a valid setup
JSON payload, but this API edge case remains recorded rather than hidden.

**Conclusion:** the earlier failure resulted from not supplying the tag via
`setTag`; it was not proof of a Roku GCM limitation. AES-256-GCM support is now
demonstrated for the tested nonempty payloads. Production adapter integration,
X25519, cryptographic entropy and end-to-end phone interoperability remain work.

[release-notes]: https://developer.roku.com/dev/docs/release-notes#roku-os-152
[contract]: https://github.com/jonzey231/AerioTV/blob/fe7ad4c1968a193efb7a55d68b2b3bd32d03b17a/docs/DeviceSetupHandoff.md
[tcp]: https://developer.roku.com/dev/docs/rostreamsocket
[udp]: https://developer.roku.com/dev/docs/rodatagramsocket
[hmac]: https://developer.roku.com/dev/docs/rohmac
[cipher]: https://developer.roku.com/dev/docs/roevpcipher
[cipher-interface]: https://developer.roku.com/dev/docs/ifevpcipher
[device]: https://developer.roku.com/dev/docs/ifdeviceinfo
