# Profiles delivery status — November 17, 2026

This records the approved developer/import-and-verify phase, not a signed
release, public feature enablement or owner acceptance.

| Main experience | Current evidence |
| --- | --- |
| Create, switch, manage, reorder and remove real-account profiles; isolated own credentials/data | `mrr-core-avatar-native`, `mrr-controls-canonical-native`, `mrr-picker-light-large-qualified-native` in `out/`; documented in [developer baseline](PROFILES-BASELINE.md). Do not repeat these completed flows as new prerequisites. |
| Protected phone-import controller, explicit Sync consent, Who watches, Add/Undo and Continue/recovery | `out/mrr-delivery-onboarding-qualified-native.log`/`.json`: all result flags, cleanup and exact baseline restoration pass. Real approved account authentication and local transactions; decoded private payload and suggestion hint, not a phone sender. |
| Profiles-only Sync | **Actual supplied accounts:** `out/mrr-real-profiles-sync-cache-fixed-native.log`/`.json` passes explicit On, both own canonical PUTs and atomic acknowledgements, server readback, A/B/A and explicit Off. Unsupported categories are preserved. Existing private policy evidence remains in [writer status](DISPATCHARR-SYNC-WRITER.md). |
| Named peer setup wire import | Actual unmodified Apple and Android encoders → Roku production decryption → protected import/own verification/onboarding pass; see named evidence below. Not physical-phone UI/discovery acceptance. |
| VOD/DVR layout | Existing inspected populated visual fixes remain complete in [UI audit fixes](UI-AUDIT-FIXES.md). They are not proof of account-backed playback. |

## Actual remaining boundaries

The final source-row version also passes
`out/mrr-delivery-source-roster-onboarding-native.log`/`.json`: name/stamp/origin
are retained and roster Undo creates no tombstone. Full automated verification
passes in `out/mrr-delivery-final-verify.log` (380-file normal ZIP).
API-key-only Add also passes the same real native flow in
`out/mrr-delivery-api-key-onboarding-native.log`/`.json`; its username comes only
from fresh own authentication, and the secure editor/Task context is scrubbed.

The supplied accounts have empty movie/series catalogs; existing read-only
inventory is `out/mrr-integrated-media-readiness.json`. Populated real-account
VOD acceptance cannot be claimed from an empty library.

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

The production listener entropy disposition, public Directions access/certification disposition,
Dashboard OS-floor verification and explicit owner acceptance remain unverified.
The read-only Dashboard attempt redirected to Roku sign-in; no authenticated
portal access or setting change occurred. Runtime enforcement remains 14.6.
The approved import-only PIN phase does not require inventing new salt creation
or Device Admin onboarding. Normal shipping readiness gates remain off.

The owner explicitly directed use of both supplied test accounts. Bounded actual
profiles App Data writes have now been performed and read back for both accounts;
private before-backups are referenced by the Sync report. No server-admin,
networking, unrelated-account or unrelated-category mutation was performed.
Real admin mutations are not an acceptance prerequisite.

## Actual-account Sync and peer qualification

The real Sync journey exposed a production defect: the controls saved consent
but left `m.devicePreferences` stale, so an outgoing profile preference save could
revert that consent. The controls now update both cached canonical Sync choices
while preserving other device preferences. Focused red/green regression evidence
is `out/mrr-real-sync-device-cache-{red,green}.log`; the complete real-device rerun
above passes including final Off. Only the existing **non-shipping baseline flag**
enables the qualified controls, scheduler and writer; shipping defaults stay off.

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
receiver material does **not** qualify production Roku entropy. Physical phone
sender UI, discovery and production listener acceptance remain separate.
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

## Verified developer handoff

Current full verification passes in
`out/mrr-real-sync-qualified-full-verify.log` (380-file normal ZIP). Latest
focused tooling also passes in `out/mrr-baseline-settled-tools.log`.
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
