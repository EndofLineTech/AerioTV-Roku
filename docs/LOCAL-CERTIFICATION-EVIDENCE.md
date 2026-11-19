# Roku certification prep — local evidence only

Source baseline: pushed `origin/dev` **`4ee2ec8`**, manifest **0.3.103**.
“Native” below means an observation on the named historical artifact or
fixture, not on this local change. A signed Beta, an unsigned ZIP, local Roku
Static Channel Analysis (SCA), Dashboard Static Analysis and App Behavior
Analysis are different kinds of evidence. None authorizes a Store release.
Issue history below comes from the checked-in Beads snapshot; it is not a
live Dashboard or Beads status check.

| Finding | Implemented at the baseline / local delta | Native or portal evidence already recorded | What is still needed |
| --- | --- | --- | --- |
| `z2l` — cold deep-link launch timing | `signalStartupComplete` emits at Welcome or the guide, **before** dispatching a playable cold link. The local patch fences live dispatch until guide readiness and prevents a saved mini tune replacing a matched live link; it does **not** move the beacon. | Historical live playback and launch beacons are separate observations, not proof of beacon order on direct-to-play. | On an already authorized cold link, correlate playback start, remote operation and beacon time. The baseline has a source-level ordering gap against the documented playback stop point. A separate change needs to track the actual linked player/attempt through retries, replacement, denial and exit, without delaying an unlinked Welcome or weakening PIN/Child gates. |
| `grq` — `AppLaunchComplete` | `StartupBeaconModel` makes completion once per app session. Unattended Welcome completes; authorized guide completes if not already sent. A saved sign-in or protected startup can withhold completion until its real UI boundary. | 0.3.85 Welcome (1,641 ms); 0.3.89 saved-key guide, dialog pair then launch; 0.3.90 fresh Welcome and saved-key launches. The snapshot records a 0.3.89 launch-only cloud failure, 0.3.90 cloud **reboots** (not proof of a missing app call), and both a reported 0.3.92 cloud pass and a later reported missing-beacon error. | Exact candidate: unattended fresh Welcome, saved authorized launch, valid recovery/re-login and protected cancel/exit traces. For a cloud discrepancy collect run ID, exact script, starting sign-in/registry state, model/OS, logs and reboot reason if applicable. Do not move the beacon ahead of a usable screen to make the launch-only test green. |
| `e19` — input launch | Manifest enables input launch. `Main(args)` and `roInputEvent.isInput()` feed `launchRequest`; the parser accepts case-insensitive `live`, `livefeed`/`liveFeed` and bounded private movie/episode/series IDs. Live uses the current lineup. VOD uses the authenticated Dispatcharr holder, rechecks ownership/protection and does not accept link-supplied URLs or credentials. `bfb0f9b` and private VOD commits `8d9214d`/`c06df16`/`49917e3` are in the baseline. | 0.3.85 malformed checks; 0.3.89 authorized liveFeed cold/warm native `play`; 0.3.94 exact cloud-shaped `contentID` + `mediatype=live` reached native `play` cold/warm and in a fresh setup replay. Later [picker evidence](PROFILE-PICKER.md) includes unavailable/guarded link cases, not successful protected VOD playback. 0.3.92 Cloud Deep Linking Basic reported no player events; the old alias rejection is known, but later cloud sample, authentication and codec questions are not resolved by that fix. | Exact-build cold/warm playback and remote checks with authorized samples, plus malformed/unavailable, no-credential and stale/PIN/Child cases. No verified new Dashboard pass, complete VOD/media-type acceptance or BYO exemption. |
| `mw1` — EPG timing | `c236658` is in the baseline. Real remote return requests the first EPG interval; the guide signals completion after draw and focus. A guide on initial startup does not fake a keypress. | [0.3.91](EPG-BEACON-0.3.91.md) on 3820RW2 / OS 15.3.4 observed Launch → EPG Initiate → EPG Complete, with live video retained in mini; not a qualifying timing run. | Record eligible return-to-guide timing on the same candidate. The checked-in Roku performance reference limits eligibility to intervals initiated within five seconds of launch completion. If EPG-as-home applicability is unclear, record that separately; don't synthesize an interval. Signed/cloud outcome missing. |
| `67c` — `GetChannelMemoryLimit` | `Main.brs` queries the monitor and logs the foreground limit when present. | 3820RW2 / OS 15.3 native limit observation ([0.3.86 notes](CERTIFICATION-0.3.86.md), preceding 0.3.85 code); it doesn't establish low-memory delivery. | Capture exact candidate with model/OS and numeric limit, then check the actual signed-package scan finding. |
| `54n` — `EnableMemoryWarningEvent` | Registers with `roAppMemoryMonitor`; a notification at ≥80% forwards a low-pressure signal. Scene trims transient detail/guide windows and inactive browser logos, retaining current and selected guide windows. | Registration and cache-retention host evidence, not a native warning delivery. | Observe the actual notification and bounded mitigation, including no lost active window or playback; signed-package scan finding still needs evidence. |
| `lmy` — `EnableLowGeneralMemoryEvent` | Registers the `roDeviceInfo` fallback when the app-level subscription is unavailable/unsuccessful. The device event handler forwards `low`/`critical` to the same mitigation. | No native fallback delivery established. | Capture unsupported/unsuccessful monitor registration **and** native low/critical delivery on the fallback path, then check the signed-package scan finding. A simulated event doesn't qualify. |

The [cross-device research](CROSS-DEVICE-SCOPE.md#i05--roku-launchdeep-link-research)
and [parity row I05](PARITY-CROSSWALK.md) describe earlier source pins. Their
disabled-input/live-only statements do not describe `4ee2ec8`. Private routes
still do not establish a Roku Search feed, public content IDs, sample approval,
or series smart-bookmark compliance. The checked-in sources reference Roku’s
[deep-link guide](https://developer.roku.com/dev/docs/implementing-deep-linking),
[publishing guide](https://developer.roku.com/dev/docs/channel-publishing-guide#deep-linking),
and [performance guide](https://developer.roku.com/dev/docs/measuring-channel-performance).
No external requirements were re-fetched for this pass.

## Evidence to collect

1. **Host/package (local).** From the exact source revision, run `npm run verify`
   and `git diff --check`. Save the terminal status, compiler/test output, and
   `shasum -a 256 out/aeriotv-roku.zip`. The normal ZIP must exclude test/probe
   sources. `PlayerLifecycle` verifies the live guide-ready fence, protected
   intent, AAC-deferred link priority, and unavailable-link fallback.
   `StartupBeaconModel`, `LaunchModel`, `VodDeepLinkNavigation` and the
   picker/PIN/Child suites cover adjacent behavior. Host tests do not exercise
   a Roku input event or video decoder. When permitted, archive local SCA JSON
   with its tool/ruleset version and the scanned ZIP hash; do not reuse an
   earlier 0.3.103 report based on version alone.
2. **Native (after device allocation and approval).** Record UTC time, commit,
   source ZIP hash, installed app/slot, device model, firmware/build, initial
   state and test mechanism (normal app vs isolated fixture). Use an
   authorized disposable account/state and verify exact restoration. Save
   ordered, timestamped redacted console markers, focus/actual remote action,
   player state and observed picture/audio separately. Run each distinct case:
   - Fresh unattended Welcome (`launch → pause:30`, no sign-in); saved-key
     normal launch; expired-key own re-login; and PIN/Child cancel/exit (no
     protected content or indication that exit was a successful launch).
   - Authorized cold live and warm input, including a saved **different**
     mini channel and a delayed tune (AAC or HLS). Verify the requested player
     remains foreground, Back returns to guide, and warm input doesn't emit
     another startup beacon. Repeat with `live`, `livefeed`, and `liveFeed`.
   - With live playback already active, leave a different live tune waiting for
     AAC. Send an authorized warm VOD input, then let AAC discovery finish before
     the VOD resolver. The current player must continue during resolution and
     the old tune must not take over. A playable result replaces it once; a
     missing/denied title may return the still-owned, unexpired tune to normal
     processing. An unadmitted link must not hold it. Repeat with a second
     input, a later explicit tune, Back/Stop, navigation, profile/session
     change, an account request hold, and an AAC deadline crossed before the
     resolver result. Confirm stale results don't change the active player.
   - Authorized Dispatcharr movie, episode and series separately, cold and
     warm; assert the expected title/episode/resume, Back and remote operability.
     Separately run malformed/URL-shaped/unsupported, unavailable, locked,
     Child-disabled, signed-out, and replaced-session cases. Check safe fallback
     or pending authenticated continuation, never cross-account playback or
     borrowing a saved credential. Keep ordinary configured live startup
     distinct from a successful link; a recognized VOD intent must not start
     unrelated live autoplay. Distinguish HTTP 200 from actual playback.
   - Fresh-session real remote EPG entry; record all three beacon timestamps,
     eligible initiation and focused/navigable grid. Record app-monitor and
     general-memory fallback evidence separately; label fixtures as fixtures.
3. **Signed/Dashboard/cloud (separate authorization; not run).** Tie a signed
   package to the exact source ZIP, record checksums and the verified existing
   signing identity per [native workflow](NATIVE-DEVICE-WORKFLOW.md), and attach
   separate Dashboard Static Analysis and App Behavior Analysis results for
   that exact upload. Capture the reviewer's approved account/media samples,
   media type, RASP result/trace, starting UI, device model and firmware per run
   (never credentials, actual content IDs, URLs, secrets or private screenshots
   in Git). A skipped test, device reboot, old signed artifact, local SCA
   detection or transport-level success is not a pass on this candidate.

## `z2l`: why the beacon is still unchanged

The checked-in requirement distinguishes a regular launch (fully rendered,
operable initial UI) from an explicit, valid cold media link (the requested
video starts and responds to the remote). `signalStartupComplete` currently
signals before `handlePendingLaunch`; authorizing a request, setting
`control="play"`, creating a ContentNode, minting an HLS session, or receiving
HTTP 200 cannot stand in for playback. A first-run Welcome must remain an
operable fallback with one beacon; neither a locked PIN/Child screen nor a
cancelled launch should be marked as successful playback.

The relevant checked-in seams are:

| Path | What the code actually observes | What is missing for a cold-link beacon |
| --- | --- | --- |
| Live | `AerioScene.onVideoState` reads native `Video.state` and `startPlayback` gives the Video focus. `HlsSessionLifecycle` associates the mint with an exact Task and ContentNode. `StartupRecovery` tracks the current ContentNode and has bounded buffering recovery. | `playing` isn't published to launch accounting with an attempt identity, current holder, and confirmed input ownership. AAC can defer before a ContentNode exists; retunes/retries replace the content. A guard for the exact linked attempt must not be satisfied by an older or unrelated player. |
| VOD | `VodDeepLinkNavigation` checks the account and current scope at both ends. `OnDemandPlayer` reports session-tagged progress and an error diagnostic; it handles the resume seek before normal progress. | The periodic progress report is not a dedicated ready event. The Scene filters it for bookmarking, which has different requirements. `openMedia` can refuse the renderer before creating a session; this branch returns without a session-tagged terminal outcome. There is no corresponding bounded VOD opener that reports a usable fallback if media never starts. |
| Fallback | An unknown live ID leaves Guide; a VOD miss can show an unavailable notice. Live AAC/HLS/video failure has several separate exit paths; VOD native errors expose Retry/Back, and close returns to Guide. | Publish a terminal result from the *matching* attempt only after an actual navigable fallback is present. A deadline can terminate a stuck attempt if the player establishes that behavior, but elapsed time alone must never complete launch. |

Before changing accounting, require a host red/green test for a single exact
attempt through resolution, buffering, first playing with foreground input
ownership, duplicate events, replacement/retry, and terminal fallback. Include
no-session request denial; initial/resume VOD; live AAC/HLS failure; unrelated
stream events; Back/Home; ordinary Guide and Welcome; and locked/refused Child
and PIN recovery. Then validate the resulting event order and an actual remote
action on the exact native candidate. No new beacon, timeout-based completion,
or recovery/player lifecycle change is made by the local prep patch.
