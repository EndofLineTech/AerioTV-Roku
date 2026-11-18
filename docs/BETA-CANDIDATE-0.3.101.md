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

Updated `npm run release:prepare` passes in
`out/p1-updated-beta101-release-prepare.log`, producing
the 380-file unsigned source ZIP:

`out/release/aeriotv-roku-v0.3.101.zip`

SHA-256: `42a143daf3f37815c40e7fef6c01f3653a1704d3babdc8b5d5378d730f5d8641`.

This replaces the original unsigned `4601a443…` ZIP and includes the P1
own-profile email-consent fix. The release ZIP's controller bytes match the
verified source; `shasum -a 256 -c SHA256SUMS` passes inside `out/release`.
The signed-package versioned checksum file is not created until signing.

This ZIP is **not** the Roku Dashboard upload package. The signed
`out/release/aeriotv-roku-v0.3.101.pkg` has not yet been created.
No public submission, signing-key generation or rekeying has occurred.

## Semantic release check

- No open P0 bugs found; of the original 18 P1 records below, `6c39`,
  `6oe4`, `3ynt`, `suad`, `j4fw`, `178i`, `ywtj`, `4skt`, and `fiz5`
  now have their missing native or reconciled later
  qualification and are closed.
- No open PRs targeting `dev`; no CI/security workflow/run found.
- Updated full release-prepare verification passed after the consent fix;
  51 private fixture tests and the targeted native P1 cases also pass.
- Manifest/npm/lock versions agree at 0.3.101; shipping manifest and package
  tests pass. Developer flags and fixture files remain rejected.
- The candidate includes the existing guide/cache edits present in the accepted
  working tree; unrelated owner research and native probes are not packaged.
- Owner approval of the documented open-item Beta risk is pending after the
  owner requested the full P1 list. Do not interpret that request as a waiver.

| Existing P1 | Scope and remaining evidence |
| --- | --- |
| `fiz5` | **Closed:** separate actual startup/reconnect read/final authority races pass before new-wave channels; existing staged-final native race also passes. |
| `4skt` | **Closed:** later simultaneous, separate-process cold, imported default PIN/Child and consented baseline retirement evidence reconciled against this stale-outgoing defect. |
| `3ynt` | **Closed:** actual own-read cleanup, imported PIN cancellation, and real outgoing preference persistence do not resurrect the removed blob; foreign data survives. |
| `suad` | **Closed:** authenticated Child's actual adult-purpose PIN is changed by own roster import; stale grant retires before another target PIN/lineup, with fresh Child rollback. |
| `6oe4` | **Closed:** real-Scene full-access and unavailable-Child key-loss-during-PIN cases pass with zero target requests and unchanged settings. |
| `j4fw` | **Closed:** real SG Task failure notification and separate result-less terminal STOP retain changed no-session actor/key, context, grant, roots and captured flags. |
| `178i` | **Closed:** native initial/staged-roster stale submit/close preserve successor admission; owned-widget retirement wipes and detaches its native dialog. |
| `ywtj` | **Closed:** native unchanged rollback succeeds under a fresh session; saved PIN/role/key/root changes stay covered, including advanced working-roster snapshots. |
| `6c39` | **Closed:** delayed synthetic recording commit/return, delayed-auth Back, and target-PIN Back matrix passes, one POST and owner-only outcome. |
| `d43d` | Intermittent function-lookup failure in repeatedly installed native probe packages; cause unresolved. |
| `667m` | Intermittent native/ECP first-key or delayed-Back failures; later passing runs do not explain all preserved failures. |
| `o7b` | Missing follow-up logos on the affected 91-channel account; affected-user verification still needed. |
| `cs6` | Oversized EPG mapping path; bounded/native smaller-account tests pass, affected large-account acceptance remains. |
| `h99` | Roku-compatible reviewer live-feed sample for older cloud hardware remains unprovided. |
| `x1i` | Historical cloud-device reboot/screensaver reports remain unlocalized. |
| `grq` | Cloud launch-beacon finding has mixed historical results; signed-candidate cloud acceptance remains. |
| `e19` | Deep-link implementation/local playback tests exist; cloud reviewer/codec acceptance remains. |
| `1is` | Own-profile shared form now requests nonce-bound consent too; host refusal/timeout/stale/root-change tests, native chosen/Add/Child command/continuation, full startup flow and updated full gate pass. Signed/cloud audit remains. |

These are existing tracker records, not 18 new defects discovered during this
build. They must not be silently closed, described as all unresolved source bugs,
or waived without the owner's Beta release decision.

## Overnight P1 qualification

The recording reports are `out/p1-6c39-recording-commit-native.json`,
`out/p1-6c39-recording-cancel-qualified-native.json`, and
`out/p1-6c39-recording-pin-cancel-qualified-native.json`. Initial failures
remain preserved: the private cancellation fixture released authentication
before Back, and its PIN fixture assumed Task state `done` rather than native
`stop`. The qualified fixture requires successful receipt/ownership as well
as terminal state; production settlement code was not changed.

The initial target-key-loss reports are `out/p1-switch-fault-key-loss.json`
and `out/p1-switch-fault-child-key-loss.json`. They drive the actual Scene,
PIN and switch controllers against disposable storage and synthetic HTTP.
The Child fixture initially omitted clearing its runtime key after selecting
the connection; its preserved failure is not a production admission defect.
Every passing run reports cleanup and checksum-verified restoration of the
accepted v0.3.100 voice baseline. No real account mutations occurred.

`out/p1-switch-fault-roster-stale-pin.json` qualifies the imported-roster
continuation separately from initial-switch stale submit/close and retirement.
`out/p1-switch-fault-rollback-{unchanged,pin,role,key,root}.json` qualifies
rollback at an explicitly held target authentication boundary, with the reply
released only after the native verdict. Changed outgoing protection stays
covered even when the working roster has advanced; the unchanged control
gets a fresh session. The initial unchanged fixture incorrectly measured
settings before the intentional outgoing save; the preserved failure and
qualified held-boundary check are distinct.

`out/p1-switch-fault-cleanup-rollback.json` qualifies real own-read third-holder
cleanup followed by imported-PIN cancellation and an actual outgoing
preference write, retaining foreign data without resurrecting removed data.
All these passing runs clean disposable storage and restore the exact baseline.

`out/p1-switch-fault-adult-purpose-change.json` adds authenticated-Child
qualification with real adult-purpose and target native PINs. The target's
own read changes the authorizing adult's PIN; the old grant retires before
another target PIN/lineup, returning only to the revalidated outgoing Child.

`out/p1-switch-fault-unavailable-actor-{change,state}.json` separately
qualifies actual SG failure and result-less terminal state callbacks after a
synthetic runtime actor change. The network PIN gate remains at its captured
value (false during incoming authentication); the visible content cover stays
true. These are distinct flags, not an inferred access bypass.

`out/p1-switch-fault-startup-{read,lineup}-authority.json` exercises the real
startup/reconnect controller, separately from switching. Each same-identity
authority race fences the actor before any new-wave channels. Previously
queued admitted-Guide EPG requests are recorded separately before new `/me`.

The `4skt` reconciliation uses existing simultaneous/cold/imported-default
native reports and `out/mrr-final-seven-baseline-retirement-qualified-native.json`;
it does not invent another owner acceptance or a new run.

The own-profile consent source fix uses a separate ChannelStore bound to its
credential admission nonce. Refusal or a 15-second unavailable-data timeout
continues only the still-current form; retirement detaches the callback.
Roku email is neither logged, retained nor substituted for a provider username.
`out/p1-own-email-consent-native.log` proves actual native `getUserData`
invocation and form continuation with source identity/preferences retained,
zero target authentication and exact cleanup/restore. This is not proof that
a sideload can satisfy signed/cloud consent certification.
Additional native Add and Child cases are
`out/p1-switch-fault-own-email-{add,child}.json`; Add retains a blank provider
username and Child retains absent actor/key and its cover.
`out/p1-own-consent-startup-native.json` separately passes actual native
startup selection, own credential POST, read and Guide admission after consent
continuation. No pre-selection/form requests or real account mutations occur.
The updated full release-prepare run passed at
`out/p1-updated-beta101-release-prepare.log`; its unsigned artifact checksum
is recorded above.

Bounded reliability follow-up did not reproduce the intermittent failures.
`out/p1-d43d-current-model-store-native.json` passes with 1,623 explicit native
PASS checks and exact baseline restoration. Whitelisted before/after snapshots
show 3820RW2 OS 16.0.4 build 853 and increasing uptime, not a reboot.
`out/p1-667m-isolated-picker-native.json` passes six actual intent callbacks and
eight HTTP-200 key commands in 13–49 ms, with exact baseline restoration and no
application startup/provider/registry. Neither passing repeat explains the
preserved historical failures or qualifies different cloud hardware/firmware;
both reliability P1s remain open.

Additional P1 qualification continues. These are targeted P1 checks, not signed/cloud certification or
physical Android acceptance. Signing remains on hold.
