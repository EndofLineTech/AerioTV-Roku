# AerioTV Roku 0.3.101 — Beta candidate

## Upload change notes

- Added multiple Dispatcharr profiles with separate account credentials,
  permissions and personal viewing state.
- Added a profile picker, quick switching, avatars, reordering and an optional
  “Who is watching?” prompt at launch.
- Added per-profile favorites, appearance and supported player preferences.
- Added imported PIN protection, Child-profile restrictions and protected adult
  management.
- Added native PIN entry, including Directions words/letters and voice input
  where supported by the Roku and remote.
- Added opt-in Profiles-only Dispatcharr Sync with account-owned storage,
  pending-edit preservation and explicit Off behavior.
- Improved profile switching, cancellation, credential recovery and server-address
  change safety.
- Included the tested guide improvements: detail-first EPG mapping for small
  lineups and larger bounded logo/metadata caches.

## Beta limitations

- Android physical-phone integration is deferred to Beta users. Existing
  unmodified Apple/Android encoder-to-Roku native tests are not a physical
  Android UI pass.
- Direct phone-to-Roku setup receipt remains unavailable in this normal build;
  use manual account sign-in and Profiles Sync. The existing receiver protection
  is not bypassed.
- Roku verifies existing/imported PINs. Creating/changing/resetting PINs,
  Device Admin creation and kid-only setup remain unavailable.
- Only the Profiles Sync category is supported; other categories are preserved,
  not synchronized by Roku.
- Voice availability depends on the Roku/remote/platform. Owner-reported voice
  acceptance on the test Roku is not a guarantee for every device.
- Legacy affected-account guide/logo and Roku cloud certification findings
  remain open. This is not a Store certification claim.

## Candidate preparation

The owner confirmed building Beta 0.3.101. Accepted profile/Child/native PIN and
opt-in Sync capabilities are now enabled in normal source through the shared
release capability function. Internal `profileBaselineReady` naming is retained
for controller compatibility; no developer manifest flags are needed or allowed
in the release ZIP. Per-user consent, own identity/permissions, PIN, Child,
storage and request-safety admission checks remain mandatory.

`npm run release:prepare` passes in `out/beta101-release-prepare.log`, producing
the 380-file unsigned source ZIP:

`out/release/aeriotv-roku-v0.3.101.zip`

SHA-256: `4601a443328efd3d2bcefe8271fb53959412cdb46d0ff098eea065796c3b0711`.

This ZIP is **not** the Roku Dashboard upload package. The signed
`out/release/aeriotv-roku-v0.3.101.pkg` has not yet been created.
No public submission, signing-key generation or rekeying has occurred.

## Semantic release check

- No open P0 bugs found; 18 existing P1 records remain open, listed below.
- No open PRs targeting `dev`; no CI/security workflow/run found.
- Full local verification is complete, not in flight.
- Manifest/npm/lock versions agree at 0.3.101; shipping manifest and package
  tests pass. Developer flags and fixture files remain rejected.
- The candidate includes the existing guide/cache edits present in the accepted
  working tree; unrelated owner research and native probes are not packaged.
- Owner approval of the documented open-item Beta risk is pending after the
  owner requested the full P1 list. Do not interpret that request as a waiver.

| Existing P1 | Scope and remaining evidence |
| --- | --- |
| `fiz5` | Continuous own authority across auth/read/final lineup. Fix exists and final-authority native race passes; startup-race verification remains distinct. |
| `4skt` | Outgoing tombstone must stay covered through default retirement. Simultaneous/cold native retirement passes; record needs reconciliation with later recovery/acceptance evidence. |
| `3ynt` | Publish cleaned preference root before rollback to avoid resurrecting removed data. Fix exists; exact native cleanup-then-rollback replay remains unrecorded. |
| `suad` | Revalidate Child adult-purpose authority after imported roster protection changes. Fix exists; exact changed-authority native replay remains unrecorded. |
| `6oe4` | Recheck target's own key after PIN wait, before outgoing teardown. Fix exists; exact key-loss-during-PIN native replay remains unrecorded. |
| `j4fw` | Refuse unavailable-Child callbacks after no-session actor changes. Fix exists; exact successor-actor native replay remains unrecorded. |
| `178i` | Bind PIN callbacks and retirement to their owning switch. Host fixes and later normal/native switch evidence exist; exact stale-widget fault qualification needs reconciliation. |
| `ywtj` | Revalidate outgoing saved protection before rollback. Fix exists; targeted native changed-protection fault replay remains unrecorded. |
| `6c39` | Preserve submitted DVR operation settlement during switch/rollback. Fix exists; dedicated delayed-operation native matrix remains unrecorded. |
| `d43d` | Intermittent function-lookup failure in repeatedly installed native probe packages; cause unresolved. |
| `667m` | Intermittent native/ECP first-key or delayed-Back failures; later passing runs do not explain all preserved failures. |
| `o7b` | Missing follow-up logos on the affected 91-channel account; affected-user verification still needed. |
| `cs6` | Oversized EPG mapping path; bounded/native smaller-account tests pass, affected large-account acceptance remains. |
| `h99` | Roku-compatible reviewer live-feed sample for older cloud hardware remains unprovided. |
| `x1i` | Historical cloud-device reboot/screensaver reports remain unlocalized. |
| `grq` | Cloud launch-beacon finding has mixed historical results; signed-candidate cloud acceptance remains. |
| `e19` | Deep-link implementation/local playback tests exist; cloud reviewer/codec acceptance remains. |
| `1is` | Roku email-consent sign-in implementation/native checks exist; final signed-candidate/cloud flow audit remains. |

These are existing tracker records, not 18 new defects discovered during this
build. They must not be silently closed, described as all unresolved source bugs,
or waived without the owner's Beta release decision.
