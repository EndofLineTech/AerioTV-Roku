# Profiles delivery status — November 19, 2026

`AerioTV-Roku-mrr.11` is the **Profiles-only Beta acceptance** decision. The
owner selected that scope; explicit acceptance of the integrated evidence is
still pending. It is separate from full phone-setup and Dispatcharr Sync parity
(`e3e.7` / `e3e.8`), Store readiness and release execution. The bounded
profile-import implementation (`e3e.4`) is closed; the parity tracks are not
prerequisites for this Beta decision.

**Beta 0.3.101:** the owner requested a Roku upload candidate and
change notes, deferring Android physical testing to users. Qualified profile,
native PIN and opt-in Profiles Sync capabilities are now enabled in normal
source without developer manifest flags. The owner approved the documented
remaining P1 risk; the versioned package was signed with the existing identity.
See [candidate notes and readiness](BETA-CANDIDATE-0.3.101.md).
**Beta 0.3.102:** normal direct phone setup is enabled. Actual unmodified peer
encoders use the real receiver and live Dispatcharr test accounts, not substituted
production crypto/controllers or a laptop-hosted provider. See
[phone setup Beta evidence](BETA-CANDIDATE-0.3.102.md) for native results and package
status. The published Developer Mode ZIP is verified; that is not authenticated
Roku Dashboard evidence. Neither Beta packaging nor native encoder tests claim
Store certification.

| Main experience | Current evidence |
| --- | --- |
| Create, switch, manage, reorder and remove real-account profiles; isolated own credentials/data | `mrr-core-avatar-native`, `mrr-controls-canonical-native`, `mrr-picker-light-large-qualified-native` in `out/`; documented in [developer baseline](PROFILES-BASELINE.md). Do not repeat these completed flows as new prerequisites. |
| Protected phone-import controller, explicit Sync consent, Who watches, Add/Undo and Continue/recovery | `out/mrr-delivery-onboarding-qualified-native.log`/`.json`: all result flags, cleanup and exact baseline restoration pass. Real approved account authentication and local transactions; decoded private payload and suggestion hint, not a phone sender. |
| Profiles-only Sync | **Actual supplied accounts:** `out/mrr-real-profiles-sync-cache-fixed-native.log`/`.json` passes explicit On, both own canonical PUTs and atomic acknowledgements, server readback, A/B/A and explicit Off. Unsupported categories are preserved. Existing private policy evidence remains in [writer status](DISPATCHARR-SYNC-WRITER.md). |
| Phone setup and saved-profile recovery | Unmodified Apple and Android encoders → normal v0.3.102 receiver → protected import with live own credentials. A separate `ajp9` candidate passed same-origin reimport and cold admission. See [import evidence](PHONE-PROFILE-IMPORT.md#normal-beta-and-saved-import-evidence). Neither is a physical-phone UI or same-LAN Bonjour result. |
| VOD/DVR integration | Actual Movies/Series grids and four movie titles across both supplied accounts pass the native main flow below. DVR progression across the same own-account switch also passes. The initial intermittent VOD incidents were closed as provider-side; picture/audio acceptance is not inferred from player state. |

## Integrated owner acceptance checklist (`mrr.11`)

Review the existing evidence; completed local flows do not need to be repeated.

1. **Profiles and protection.** Use the closed `.9`/`.10`/`.19` evidence for
   picker, own-account switching, local recovery and imported PIN/Child
   protection; standard Roku/iOS and later fixture-free voice passes were
   owner-reported. Bounded `.18` admin authorization, wrong-user refusal, and
   active-own reload use controlled native evidence, not live admin mutations.
2. **Phone and onboarding.** Review the named live encoder results for fresh
   protected imports, the controlled Add/Undo and explicit consent paths, and
   `ajp9` for the tested saved same-origin edit and cold relaunch. Do not infer
   a live changed-origin/recovery matrix, physical sender versions, or Bonjour.
3. **Profiles-only Sync.** Review explicit On → both own writes and readbacks →
   A/B/A → Off, with unsupported categories preserved. The phone payload never
   enables Sync. This is not full settings/roster parity.
4. **Media and overlays.** Review native populated VOD/DVR progression before
   and after switching and the separate owner-reported media pass. `dgt`
   provides live Dispatcharr native evidence for Player Info, channel browser
   and mini-player during playback, light appearance and empty Favorites
   recovery, plus read-only Movies/DVR views (`out/dgt-os16-release.log`,
   `out/dgt-os16-candidate-retry.log`). It is not a physical-remote or
   picture/audio capture, a VOD/DVR item-action matrix, or owner Xtream proof.
5. **Record the decision explicitly.** Confirm acceptance of this bounded
   Profiles-only Beta, or name any in-scope gap that still needs evidence.
   Physical Android is deferred by the owner to Beta users, not passed. The
   owner reported iOS use, but the exact physical sender build and current
   same-LAN Bonjour result were not recorded; multicast does not cross the
   test VPN. These, wider provider/phone/Sync parity, new PIN/Device Admin
   creation, authenticated Dashboard firmware verification, and public
   Directions/Store certification are not accepted by this checklist.
   Runtime Roku OS 14.6 enforcement is not Dashboard verification. This
   decision does not authorize provider work, signing, submission or release.

The earlier integrated plan also included a broader live import and roster
matrix (address changes, partial failures, Remember/no-key cases, duplicate
handling, discovery and Guide handoff across providers), wider Sync schema
and late-write behavior, and public-access/platform verification. The current
scope does not convert controlled or missing results from that plan into
live passes, nor does it close the separate parity tracks.

## Actual remaining boundaries

### Final seven-item audit

These are acceptance dispositions, not duplicate implementation tasks or an
epic-complete claim. Beads remains the status register.

| Item | Implemented/verified scope | Remaining boundary |
| --- | --- | --- |
| `mrr.6` switching | **Completed approved implementation.** Explicit default-only slot persistence; fresh memory-only switch/cancel, actual-baseline address replacement and outgoing-flush native qualification; full regression passes and matching unsigned baseline is installed (see [scoped state](PROFILE-SCOPED-STATE.md)). | Local/voice access acceptance is now recorded separately; integrated acceptance and release remain separate, not reasons to reopen this implementation. |
| `mrr.8` PIN/Child | **Completed approved import-only/developer implementation.** Fresh 1,626-assertion native policy/storage run plus imported Directions D-pad lock/unlock and Directions adult-management smoke pass; see [PIN completion evidence](PROFILE-PIN-POLICY.md). | `.19` now has owner-reported native voice/access acceptance, not formal certification. New salt creation stays disabled. |
| `mrr.9` picker/management | **Closed** on existing implementation/native evidence plus owner-reported standard physical-remote UI acceptance. | Owner clarified phone testing used iOS and the initial pass excluded voice. Later owner-reported voice acceptance is recorded in `.19`. |
| `mrr.10` local acceptance | **Closed.** Owner-reported standard Roku/iOS and subsequent voice passes complete bounded local acceptance. [All 18 specification scenarios](PROFILE-LOCAL-ACCEPTANCE.md), 1,626 native assertions, 14 request groups, 49 report audit and later `.19` full gate retain their precise evidence limits. | Not physical Android handoff, formal certification, shipping enablement or release approval. |
| `mrr.11` integrated acceptance | Both actual accounts' Sync/media progression, named peer imports, saved same-origin cold admission, live overlay evidence and owner-reported Roku/iOS/media passes. Owner confirmed initial VOD incidents were provider-side; `unxg` is closed. | Explicit Profiles-only Beta acceptance remains pending. Deferred and unverified evidence is listed above; entropy assurance is non-blocking. |
| `mrr.18` bounded admin | **Closed.** Native synthetic gates/transport/actions/UI and active-own reload: `mrr-admin-final-actions-native`, `mrr-admin-ui-own-reload-native`; admin and current full regression gates pass. | Last dependency `.6` is closed. No real server mutation, public release or owner acceptance is inferred or required for this bounded implementation closure. |
| `mrr.19` native PIN keyboard | **Closed.** Shared controller/native/full-regression evidence plus owner-reported **“Passed”** after installation of the actual fixture-free voice variant and voice test instructions. Existing PIN/hash/lockout and purpose/session gates remain. | Owner physical acceptance is distinct from independent telemetry or formal Roku certification. Prior false voice observations remain historical evidence; no cause, OS setting change or public release is inferred. |

Native Directions details and preserved failed verdicts are in
[PIN policy](PROFILE-PIN-POLICY.md). Earlier statements that baseline Sync is
always off or that later-qualified main flows are unimplemented are historical.

### Owner disposition: entropy assurance is non-blocking

On November 17, after clarification that phone setup works in testing and no
randomness failure or credential leak has been demonstrated, the owner explicitly
directed: **“This isn't a blocker, move on.”** The undocumented cryptographic
assurance of the device-key construction is a recorded non-blocking risk, not
a prerequisite to further functional phone-setup or epic acceptance work.
Additional entropy investigation was stopped (`AerioTV-Roku-z1zz`, closed
without code changes). Earlier claims that this assurance alone blocks progress
are superseded. This does not fabricate a vendor guarantee, change the installed
entropy provider, or authorize signing/release execution.

The final source-row version also passes
`out/mrr-delivery-source-roster-onboarding-native.log`/`.json`: name/stamp/origin
are retained and roster Undo creates no tombstone. Full automated verification
passes in `out/mrr-delivery-final-verify.log` (380-file normal ZIP).
API-key-only Add also passes the same real native flow in
`out/mrr-delivery-api-key-onboarding-native.log`/`.json`; its username comes only
from fresh own authentication, and the secure editor/Task context is scrubbed.

**VOD is now available on both supplied accounts:** fresh own-key title requests
return **126,433 movies and 32,935 series** each
(`out/mrr-vod-available-recheck.json`). The earlier zero-title/disabled-category
reports are historical observations, **not current blockers**. No provider,
category or server configuration was changed by this agent. Actual populated
Movies/Series browse and representative movie playback across profile switching
were qualified on the Roku using a disposable registry and exact installed
baseline restoration; API counts alone are not on-TV acceptance.

Actual populated VOD/profile main-flow evidence now passes for four movies,
each on both own accounts:

- Sintel: `out/mrr-vod-terminal-diagnostic-native.log`/`.json`.
- The Matrix: `out/mrr-vod-client-matrix-native.log`/`.json`.
- Big Buck Bunny: `out/mrr-vod-client-bunny-native.log`/`.json`.
- Toy Story (not host-stream-sampled before native playback):
  `out/mrr-vod-client-unsampled-title-native.log`/`.json`.

Each run browses the real populated Movies and TV Shows grids, opens a real
title through the existing details/play controllers, confirms `playing` and
position progression before/after the own-account profile switch, preserves
source preferences, cleans its disposable registry and restores the exact
installed baseline. Catalog captures were inspected. Native player captures
are black; they do **not** establish human picture/audio acceptance.
Toy Story's observed app memory usage was 5–21%; no native error was reported.

**Intermittent VOD incident closed (`AerioTV-Roku-unxg`).** On November 17,
the owner confirmed these failures were provider-side and explicitly directed
closure. No Roku client fix or further investigation is required for these
incidents. The historical evidence below is preserved, not an ongoing blocker.
Earlier Matrix
and Sintel attempts reached buffering, then `finished` with error code `-3`,
without confirmed progression. Initial evidence is preserved in
`out/mrr-populated-vod-{main,player-state,sintel}-native.log`/`.json`.
Successful repeats used unchanged production playback code; the provider
disposition comes from the owner's confirmation, not an inference from retries.
Following the owner's earlier direction to
investigate multiple-title failures, the private probe now records selected
title/identity digest/container, sanitized native error string and error-info
fields, current session/admission and app memory. It treats nonzero error
codes as failure even if the transient `error` state has already become
`finished`. Detailed native failure text was not captured by the earlier
probe; no speculative production player change was made.

Real DVR/profile integration now passes
`out/mrr-media-main-qualified-native.log`/`.json`: populated library, actual
`playing` state and position progression on **both** own accounts before/after
switching, preserved source preferences, disposable cleanup and exact baseline
restoration. Both report a 1290-second duration, current/allowed session and
error code zero. The earlier timeout was not a proven codec failure: the corrected
probe reads player state through its internal component interface instead of
cross-component node lookup. A separate host verdict bug incorrectly required
an unrelated switcher screenshot; focused red/green and the complete rerun pass.
This is player progression evidence, not human picture/audio acceptance or VOD
acceptance. No recording, transcoding or account setting was changed.

The public Directions access/certification disposition and authenticated
Dashboard OS-floor verification remain unverified, separate from Beta acceptance.
The read-only Dashboard attempt redirected to Roku sign-in; no authenticated
portal access or setting change occurred. Runtime enforcement remains 14.6.
The approved import-only PIN phase does not require inventing new salt creation
or Device Admin onboarding.

The owner explicitly directed use of both supplied test accounts. Bounded actual
profiles App Data writes have now been performed and read back for both accounts;
private before-backups are referenced by the Sync report. No server-admin,
networking, unrelated-account or unrelated-category mutation was performed.
Real admin mutations are not an acceptance prerequisite.

## Historical actual-account Sync and peer qualification

The real Sync journey exposed a production defect: the controls saved consent
but left `m.devicePreferences` stale, so an outgoing profile preference save could
revert that consent. The controls now update both cached canonical Sync choices
while preserving other device preferences. Focused red/green regression evidence
is `out/mrr-real-sync-device-cache-{red,green}.log`; the complete real-device rerun
above passes including final Off. Those developer runs used the then-required
baseline flag. The normal Beta enables those capabilities without that flag;
account admission and explicit Sync opt-in still apply.

Final-baseline probes no longer force Scene/Task writer readiness. Two preserved
reruns (`mrr-final-baseline-sync-native` and
`mrr-final-baseline-settled-sync-native` in `out/`) reached legitimate
`unchanged` receipts but timed out waiting for a PUT: their two-name edit
alternated a display name with the bare username, which the shared stripped-row
repair deliberately replaces with richer remote metadata. Both safely turned
Sync Off and restored the exact baseline. The corrected fixture alternates two
non-stripped display names after initial settlement, not production merge rules.
The corrected final-baseline run **passes**
`out/mrr-final-baseline-main-sync-native.log`/`.json`: both actual own PUTs,
atomic acknowledgements, both server readbacks, preserved unsupported categories,
credential-free documents, A/B/A, explicit Off and exact fixture-free restoration.
No Scene or Task readiness override was used for this final run.

Named encoder evidence:

- Apple `8df372291da4a858b0081e291a7fa5cbe398f9f8`:
  `out/mrr-actual-apple-peer-import-native.log`/`.json`.
- Android `63d70f00ac6b7e1148093786942468514c618b62`:
  `out/mrr-actual-android-peer-qualified-native.log`/`.json`.
- Pinned source/asset digests: `out/mrr-peer-wire-source-hashes.json`.

The actual pure protocol sources were compiled unmodified using Swift/CryptoKit
and checksum-verified portable JVM/Kotlin tools. Each generated an encrypted
two-account protected-default payload; the actual Roku executed production
`phoneSetupOpen`, import, own verification and onboarding. Each disposable
registry was cleaned and the exact normal baseline restored. Private host-CSPRNG
receiver material does **not** qualify production Roku entropy. That assurance
gap is non-blocking under the owner disposition above. These older probes did
not qualify the normal listener; see the v0.3.102 runs for that evidence.
Physical phone sender UI and current discovery are separate from encoder results.
Phone-import probes disable Scene scheduling/writing and internal Task PUT
readiness, preventing fixture PINs from being uploaded to actual accounts.

Android's initial run stopped before installation on a token endpoint HTTP 429;
the cooldown was respected and no automatic retry sent. Subsequent verification
uses the existing own API keys with fresh `/me/` reads instead of repeated
password exchanges.

## Native runner access

Use `PATH=/opt/homebrew/bin:$PATH` for native Python runners on this Mac.
The owner granted that Python Local Network permission; a direct read of Roku
control returned HTTP 200. Xcode's separate `/usr/bin/python3` still returned
errno 65 during diagnosis. Do not diagnose the Roku as offline merely from that
runtime, reset security databases, disable VPN controls or repeat reachability
matrices. No network configuration was changed.

Both supplied accounts were provisioned on the actual Roku through normal
controllers and A/B/A switching passed:
`out/mrr-device-two-accounts-provision.log`/`.json`. The normal cold-launch picker
shows `test1`, `test2` and Add Profile in the inspected
`out/mrr-device-two-accounts-ready.jpg`. The fixture-free qualified baseline was
subsequently installed with exact old-ZIP preflight and new installed checksum
verification (`out/mrr-qualified-baseline-installed.json`). Its normal picker
was inspected in `out/mrr-qualified-baseline-ready.jpg`, showing Test 1, Test 2
and Add Profile.
After the final real Sync run, the inspected normal picker is
`out/mrr-qualified-final-ready.jpg`; the supplied accounts' test display names
are now **Sync Test 1** and **Sync Test 2**. Sync remains Off.

## Historical developer handoff

### Latest final-seven baseline

**Historical owner-authorized native keyboard test variant (v0.3.100).**

`out/profiles-mrr19/aeriotv-roku-v0.3.100-profiles-voice-baseline.zip`

SHA-256: `df85ea1fd0bdbf70270c684f1f615365590bf9d03360ce46a536461442c36203`.
The owner requested testing the voice work in the actual app. Installation
report `out/mrr19-owner-voice-baseline-installed.json` confirms exact old-app
preflight, sidecar checksum, equal compiled contents, no fixture/probe files,
launch and the new installed checksum. The inspected ready image retains both
test profiles and Add. This was the restore ZIP for that checkpoint; it does
not identify the currently installed app. The owner's later voice report is
recorded above; signing and release do not follow from this install.

The earlier ordinary **`.19` implementation baseline** is preserved:

`out/profiles-mrr19/aeriotv-roku-v0.3.100-profiles-baseline.zip`

SHA-256: `690479161796c3b98aeed5515bdcede413aa303a8f11e0353f71d3fa52522668`.
Full regression passes in `out/mrr19-native-keyboard-full-verify.log` (380 files).
`out/mrr19-native-keyboard-baseline-installed.json` verifies sidecar checksums,
full-gate compiled contents, all 210 current BrightScript files, exact old-app
preflight and the new installed checksum. The inspected ready screenshot retains
Sync Test 1, Sync Test 2 and Add.

This ordinary baseline includes the new PIN code but keeps both Directions
opt-ins off. The separately verified, **initially not installed** developer native-keyboard
variant is
`out/profiles-mrr19/aeriotv-roku-v0.3.100-profiles-voice-baseline.zip`, SHA-256
`df85ea1fd0bdbf70270c684f1f615365590bf9d03360ce46a536461442c36203`.
The owner-authorized installation above supersedes that initial handoff.
Neither was signed or released; public acceptance is not inferred.

The earlier **`.6` completion baseline** is preserved:

`out/profiles-mrr6/aeriotv-roku-v0.3.100-profiles-baseline.zip`

SHA-256: `0f03d501786cc107d6e52075876bb36416e18c783722d4a379ffb3c77846ab33`.
Full regression passes in `out/mrr6-completion-full-verify.log` (380 files).
`out/mrr6-completion-baseline-installed.json` confirms checksum, full-gate compiled
contents, exact old-app preflight and new installed checksum. The inspected
`out/mrr6-completion-baseline-ready.jpg` retains both supplied profiles and Add.
It adds the default-only slot persistence boundary, not public feature flags,
voice settings, signing or release. The older final-seven checkpoint below is
preserved for provenance, not the current installed artifact.

Full `npm run verify` passes in `out/mrr-final-seven-full-verify.log`
(380-file normal ZIP); the focused probe suite passes in
`out/mrr-final-seven-tools-final.log`.
The unsigned, fixture-free developer baseline installed at that checkpoint was:

`out/profiles-final-seven/aeriotv-roku-v0.3.100-profiles-baseline.zip`

SHA-256: `b68bde82735ed3bcd172dfff62284a1b6c30015d232c94700b76d761efb65b62`.
Its sidecar checksum and every compiled file against the full-gate normal ZIP
were verified before installation; only its developer manifest differs.
`out/mrr-final-seven-baseline-installed.json` records the exact old-app preflight,
successful launch and new installed checksum. The inspected
`out/mrr-final-seven-baseline-ready.jpg` still shows **Sync Test 1**,
**Sync Test 2** and Add Profile. No profiles or real-account Sync settings were
changed by installation.

This baseline adds qualified automatic default retirement to the previous
checkpoint. Both outgoing-own-read and incoming-target-own-read synthetic native
paths pass with actual readiness, cleanup and exact restoration of the then-current
older baseline. It does not enable Directions, change shipping defaults, qualify
public acceptance, or constitute a signed package/release.

### Previous qualified checkpoint (preserved)

Previous full verification passes in
`out/mrr-real-sync-qualified-full-verify.log` (380-file normal ZIP). Latest
focused tooling also passes in `out/mrr-vod-client-native-diagnostics-green.log`.
`out/mrr-qualified-baseline-full-gate-match.json` verifies that all compiled
files in the installed baseline match that full-gate normal ZIP; only its
developer manifest differs.

Prior API-key implementation regression passes:
`out/mrr-delivery-api-key-final-verify.log` (380-file normal ZIP).
Unsigned developer artifact:
`out/profiles-qualified/aeriotv-roku-v0.3.100-profiles-baseline.zip`.
Its `.zip.sha256` verification passed; SHA-256:
`485387c129cb48068e378705251c64ba0b0d56d4ad6c835f9b94dfc0a52de601`.

This build includes the preserved owner working-tree version/cache changes;
those unrelated files were not committed by this delivery work. It was not
signed or released. The installed checkpoint includes the qualified cache fix
and developer-only Sync gates, but no private qualification fixtures or supplied
secrets. It does not bypass public security gates. Sync was Off after the
passing main journey; further qualification must explicitly turn it Off again.
