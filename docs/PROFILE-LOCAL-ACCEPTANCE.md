# Local profiles acceptance (`mrr.10`)

## Scope and verdict — November 17, 2026

This is the acceptance record for the approved **unsigned developer,
import-and-verify phase**, not public enablement, certification or a signed
release. `.6`, `.7`, `.8`, `.14`, `.15`, `.17` and `.18` implementation evidence
is available. `.9` still retains physical-remote acceptance; `.19` owns native
voice-keyboard access qualification. Its subsequent
[shared-controller implementation](PROFILE-NATIVE-PIN-KEYBOARD.md) now has
developer-only native evidence, not spoken-entry acceptance.

The owner requested work on `.10`, **not final acceptance of it**. Keep `.10`
open until its remaining acceptance conditions are actually met. Automated
qualification does not substitute for the explicit owner acceptance required
by this ticket.

The controlling source is the November 12 specification, SHA-256
`9f7c94873ec9b0f958f7aaf3f7cec7f0dafa129974264308dbb799e42b19ca1a`,
especially §17, with the later owner dispositions recorded in
[delivery status](MRR-DELIVERY-STATUS.md). Entropy assurance is explicitly
**non-blocking**. New-salt creation remains outside the approved feature phase;
that is not a failed imported-PIN verification test.

## Evidence levels

- **Shared native policy/storage:** production helpers and shared tests execute
  on the Roku; fault cases use fake registry adapters, supplemented by explicitly
  cleaned disposable real-registry sections. Not full application E2E.
- **Synthetic native integration:** actual application controllers/Tasks and
  controlled HTTP or injected admin responses. Not a real Dispatcharr server
  admin mutation or an actual phone sender.
- **Actual-account integration:** the approved test accounts, their own
  credentials/permissions and real server responses, with isolated app state or
  the separately authorized persistent test setup.
- **Physical/owner acceptance:** a person operates the physical remote/phone or
  explicitly accepts delivery. ECP acknowledgements, callback injection, source
  review and screenshots do not establish this level.

All report stems below are private artifacts under `out/`, normally with
`.json` and `.log`. Failed predecessors remain preserved; later passing reports
do not diagnose unrelated intermittent launch/input failures.

## Fresh local qualification

Both runs completed on the authorized Roku with no application source changes:

| Gate | Fresh result |
| --- | --- |
| `mrr10-local-policy-native.log` / `.json` | **1,626 native assertions pass**. Production HTTP/typed JSON/PIN helpers, role/credential/scoping/address/merge/Child policies, faulted storage, disposable actual-registry transactions and representative capacity candidates. Five capacity sections report `removed=true empty=true`; the actual store probe separately asserts cleanup. |
| `mrr10-request-safety-native.log` / `.json` | **All 14 groups pass**, in order: generic refusal, rejection, concurrent reports/holds, own Sync reads, session retirement, park/concurrent park, transport, direct bypasses, bypasses, renderers, real slow recheck and native video. Host request ledger validates allowed paths, exact scenario sequence and no mixed Bearer/API-key authentication. |
| `mrr10-local-acceptance-evidence.json` | **49 report verdicts/digests audited**, including the complete prior `.6`/`.8` evidence indexes. Their recorded report digests still match. The audit deliberately records `local_acceptance_complete=false` and `public_acceptance_complete=false`. |

Both fresh runs preflighted and checksum-restored the exact current unsigned ZIP:
`out/profiles-mrr6/aeriotv-roku-v0.3.100-profiles-baseline.zip`, SHA-256
`0f03d501786cc107d6e52075876bb36416e18c783722d4a379ffb3c77846ab33`.
The re-inspected fresh `out/mrr10-local-acceptance-ready.jpg` confirms the
restored picker retains Sync Test 1, Sync Test 2 and Add.

At the `.10` checkpoint, all **210 packaged BrightScript files** byte-matched
the working sources.
The baseline's compiled contents, excluding its developer-only manifest, also
match the 380-file normal ZIP from the passing
`out/mrr6-completion-full-verify.log`. XML is compiler-normalized, so raw XML
source equality is not claimed. Older normal-app reports remain evidence for
their recorded versions; digest checks do not retroactively rerun them.
No new full host regression was claimed for that documentation-only acceptance
pass. The preceding full gate was the applicable unchanged-code gate. Later
`.19` source changes and their distinct qualification are recorded in the
native keyboard document; this earlier audit is not a new-code regression pass.

Reproduction (supply device credentials through the environment):

```sh
python3 scripts/test-profile-primitives-native.py --model-store --registry \
  --restore out/profiles-mrr6/aeriotv-roku-v0.3.100-profiles-baseline.zip \
  --report out/mrr10-local-policy-native.json
python3 scripts/test-request-gate-native.py \
  --restore out/profiles-mrr6/aeriotv-roku-v0.3.100-profiles-baseline.zip
```

The request runner writes `out/request-gate-native.json`; its fresh result was
copied to the immutable `.10` report stem above. The preceding canonical report
was preserved as `out/mrr10-prior-request-gate-native.json` before the run.
Native commands require the local-network-capable Python described in
[the device workflow](NATIVE-DEVICE-WORKFLOW.md).

## Local criteria

| `.10` requirement | Evidence and limits |
| --- | --- |
| A/B/A, default/non-default and two slots | `mrr6-completion-switch-memory-final-native` qualifies own A/B/A, reconnect, rejection/Back rollback, stale callbacks and no autoplay. `profile-settings-native` qualifies two-slot settings isolation; `profile-scope-native` and current shared-native tests cover slot/holder credential/data boundaries. Actual-account main UI is `mrr-core-avatar-native` / `mrr-controls-canonical-native`. |
| Full/limited/server-admin permissions | Native model/credential/management/Child rules use verified authority, not imported Admin labels. `profile-assignment-refresh-native` covers active permission/lineup changes. `mrr-admin-final-actions-native` and `mrr-admin-ui-own-reload-native` cover dual-admin gates, bounded payloads, confirmation and own reload. Admin mutation transport is synthetic; neither actual test account is claimed to provide real server-admin E2E coverage. |
| Wrong identity, typed rejection, generic 401 and all 403 | Current native request suite, `profile-switch-active-reject-native`, `profile-active-own-recheck-native` and same-key recovery/cancel/timeout reports. Generic/proxy refusal preserves valid keys; wrong `/me` cannot adopt another identity. Default credentials are not a fallback for a non-default refusal. |
| Retry-After and bypass paths | Complete request-gate suite covers concurrent clients, HTTP transport, cache admission, HLS/session/bridge/logo/mapping bypasses and native Poster/Video. The first slow recheck is wall-clock tested; later 5/15/30-minute scheduling is deterministic policy coverage, not a claimed half-hour device soak. |
| Address holds, keyless holders, relaunch | `mrr6-completion-address-replacement-baseline-native`, `profile-address-handler-native`, `profile-address-legacy-native`, held/keyless/remembered cold reports, and current address/store/own-sign-in rules. Changed-origin traffic uses explicit new-origin synthetic credentials, never real keys sent to a stand-in. Repeated snapshot/hold invariants are policy evidence; not all §17.18 phone/server steps were performed literally. |
| Corrupt/full registry, cap and migration | Current shared-native suite covers absent versus corrupt roots, cap refusal, write/Flush/rollback faults and preservation of unrelated data. Disposable real-registry probes qualify representative supported candidates, not physical registry exhaustion or a universal worst-case capacity guarantee. `profile-recovery-native` proves no provider request under corrupt recovery; `profile-migration-final-native` and legacy address flow qualify migration. |
| Remember/Forget and scoped state | Memory-only switch/reconnect, remembered/keyless cold reports, current credential/scope/cleanup tests and real disposable-registry Forget. Whole-slot Forget is local-only, preserves other slots and creates no tombstones. Host/native injected failure is distinguished from actual storage failure on a full device. |
| Imported peer PIN/role protection | `mrr8-completion-directions-import-native`, native numeric import and actual protected onboarding. Existing PINs remain required before own transport; changed imported PIN invalidates the prior proof. Peer-generated encoder-to-Roku import evidence is separately recorded in delivery status, not a physical-phone claim. |
| Child access, deep links and no unsafe fallback | `profile-child-launch-native`, `profile-child-escape-native`, `profile-child-settings-native`, actual core Child/adult flows and private startup Child selection/rejection/link reports. Warm-link fixtures use deliberately unavailable content IDs and prove safe routing/non-play, not successful protected deep-link playback. |
| Directions/all-Directions and phase boundaries | Developer-only D-pad import/adult gates pass; every valid adult/Device Admin Directions PIN counts as protection. Lack of voice does not turn it into “no PIN.” Ordinary baseline does not opt into Directions. `.19` now adds opt-in native controller integration; physical voice and public qualification remain unfinished. New PIN/Device Admin creation and kid-only setup are intentionally unavailable. |
| Launch timing/certification | Native dialog/void-cancellation and beacon primitives plus actual startup/link controllers establish local ordering and paired dialog/launch events. They do not establish public certification, every-device 15-second latency, or authenticated Dashboard firmware-floor settings. OS 14.6 direct-launch protection is implemented; portal verification remains `.11`. |
| Screenshots, focus and limitations | Reinspected `mrr-picker-light-large-qualified-native.switcher.jpg`: readable Light/large labels, bounded long-name ellipsis, focused/current tile, avatar and footer. `profile-child-settings.jpg`: only the five approved categories, with visible focus and no other identities. `mrr6-completion-baseline-ready.jpg`: both retained test profiles and Add. These are visual evidence, not physical-remote acceptance. |

## Specification §17 reconciliation

No row below claims the complete prescribed phone/server scenario passed merely
because a component test passes. The specification's artificial `alice/kim/sam`
admin scenario is not interchangeable with the two approved real test accounts.
Unapproved key revocation, server-user changes, network disconnection and
deliberate real-server throttling were not performed.

| §17 test | Available Roku evidence | Boundary still not established by that evidence |
| --- | --- | --- |
| 1 Interim notice | `setup-apply-http-native-results`, inspected notice; later full protected import controller evidence | Literal physical-phone Copy entire setup flow; interim notice is historical phase behavior, not the current full-import promise |
| 2 Import this user only | Receiver validation/default proof and named unmodified peer encoder import evidence | Physical-phone UI/discovery → this-user-only session |
| 3 Own canonical key name | `mrr-real-profiles-sync-cache-fixed-native`, `mrr-final-baseline-main-sync-native`: both own PUT/ack/readback | None added to bounded own-key qualification; this does not prove phone display |
| 4 Numeric PIN import/lockout | Native imported PIN, five failures/real lock and correct unlock; shared persistence/backoff | Physical-phone PIN edit/pull and manual physical-remote entry |
| 5 Directions PIN | `mrr8-completion-directions-import-native` and adult-Directions native flow | `.19` native voice route and public qualification, not a D-pad exemption |
| 6 Roster avatar edit | Actual core rocket-avatar management; own Sync PUT/ack and metadata stamp policies | Phone picker-open pull displaying that edit |
| 7 Older data loses | Shared native merge/stamp/clock-refusal tests | Two physically operated clients offline/online over the specified minute |
| 8 Tombstone/re-add | Native roster pull/retirement/cleanup and Add/Undo policies; actual-baseline retirement reports | Physical-phone remove/re-add/round-trip sequence |
| 9 Wire strictness | Native independent typed JSON round-trip plus actual-account unsupported-category preservation/readback | Phone's subsequent parser log and display |
| 10 Child rules | Actual core Child/PIN/adult escape; restricted Settings and unavailable/retry policy/controller evidence | Literal three-user phone/network-off/reconnect exercise; new-salt walk intentionally excluded |
| 11 Per-user Channel Profiles | Synthetic native admin actions/UI and active own reload; own-filter reconnect/assignment-refresh | Real server-admin assignment change and phone lineup refresh; no mutation authorized |
| 12 Enable API access | Synthetic native explicit-user enable/minted-only revoke and dual-admin gates | Real account mutation; not required to invent it for closed `.18` implementation |
| 13 Rejected key | Native typed rejection/own recovery, retained default key, Child-safe refusal and first slow recheck | Real server key revocation/regeneration and physical-phone continuity |
| 14 429 | Complete native broker/transport/bypass/media park suite and deterministic Retry-After policy | Deliberately rate-limiting the actual server/NAT; not authorized or needed for safe controlled qualification |
| 15 Full setup apply | `mrr-delivery-onboarding-qualified-native`: protected own-account import, picker, consent, Add/Undo and recovery | Physical-phone setup/discovery → Roku E2E (`.11`) |
| 16 Remember off | Native memory-only A/B/A/reconnect, keyless cold restore and own startup form | Literal physical-remote relaunch/form acceptance; no stored key is inferred from session success |
| 17 XC negative | Native setup/provider/picker policies exclude profile UI for XC/M3U | Physical-phone XC transmission UI flow |
| 18 Server-address change | Real-handler synthetic two-origin same/replaced-default flows, failed-Flush rollback, cold holds, paused merge/Undo tests | Complete prescribed repeated three-user physical-phone/real-server sequence; no real keys or mutations used at a stand-in |

## Outstanding acceptance ownership

Beads, not this document, tracks remaining work:

- `.9`: physical-remote UI acceptance.
- `.19`: finish native voice-keyboard access qualification across protected entry
  points; developer-only shared controller integration is now implemented, but
  the discriminating physical-remote check was deferred by the owner. Do not
  report it as only paperwork or vendor approval.
- `.10`: retain the explicit local acceptance decision and the above limitations;
  do not force-close through its open dependencies.
- `.11`: physical-phone integration, human media picture/audio, authenticated
  Dashboard floor and integrated owner acceptance.

Existing intermittent probe failures remain in their original Beads, including
`667m`, `36eu`, `5fif` and `d43d`; no fresh pass establishes their root cause.
The owner-directed entropy and provider-side VOD dispositions are not reopened.
No public flags, security bypass, server administration, network settings,
signing or release is authorized by this acceptance record.
