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
| `z2l` — cold deep-link launch timing | A valid cold media link that starts a cold attempt withholds `AppLaunchComplete` (not `AppDialogComplete`) until that attempt's first outcome: focused, advancing playback of the requested reader (`ready`), otherwise the attempt's fallback, replacement, protection gate or cancellation. Welcome, ordinary saved launch, unavailable links and warm input keep one completion at the existing UI boundary. | Before the change, a 3820RW2 / OS 16.0.4 cold `liveFeed` run with a real authorized channel signalled the beacon about 2 s before the linked reader played and advanced. | Exact-build native order for cold live (and supported VOD), Pause/Resume, Back, ordinary launch and Welcome; Dashboard/cloud evidence is separate. |
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

### Offline beacon trace check (`mw1`, `grq`)

For one approved, uninterrupted run of the exact candidate, keep a local
sanitized TSV under ignored `out/`: one observed marker per row, with elapsed
integer milliseconds from the same clock, then a tab, then the exact beacon
name. Keep all occurrences of `AppLaunchComplete`, `EPGLaunchInitiate` and
`EPGLaunchComplete` in capture order; omit unrelated lines (including dialog
beacons), not duplicates. No headers, account values or raw console text.
Roku OS 16 prints one completion signal as two `[beacon.signal]` lines (a
`Pending Render Pass` line, then a `Duration(...)` line) and may later print a
`[beacon.report]` line; record one row per signal from the `[beacon.signal]`
line (not both lines, and no `report` rows).
Use capture timestamps, not the duration printed by a beacon or guessed
timestamps from an order-only log. If only host receipt times are available,
label them as estimates; buffering near the boundary can make eligibility
inconclusive.

```bash
node scripts/check-roku-beacon-trace.mjs launch out/saved-launch.tsv
node scripts/check-roku-beacon-trace.mjs epg out/return-to-guide.tsv
```

`launch` expects exactly one `AppLaunchComplete` and no EPG markers in a
successful launch-only run. Check fresh Welcome, saved authorized launch and
successful recovery separately. Review protected cancel/exit separately
against the observed UI; it is not a successful-launch input to this tool.
`epg` expects exactly one Launch → Initiate → Complete sequence and reports
both intervals. A valid pair with initiation >5,000 ms still reports both
intervals but exits 1; malformed/missing/duplicate/out-of-order markers also
exit 1. This checks the record only: confirm the real remote return,
focused/navigable grid and retained playback separately. It does not infer
EPG-as-home applicability, a certification duration limit or a Dashboard pass.
The historical `rasp/AerioTVEpgLaunch.rasp` includes a 10-second pause between
Select and Back; use it for path/order regression, not as a plan for a
qualifying interval.

### Native memory evidence (`67c`, `54n`, `lmy`)

The deterministic `MemoryCleanup` host suite calls the production Scene handler
and guide cleanup directly with a fixed clock and stand-ins for SceneGraph
nodes. It checks that current and selected guide data survive, detail state
is released, and logo invalidation is requested only for an inactive browser.
It does not dispatch an OS notification or measure Roku memory or playback.

Keep the foreground-limit query, app-warning delivery and fallback delivery
as three separate observations. For `67c`, record the `[memory] foreground
limit KB=` value from `Main.brs`, not a substituted ECP counter. For `54n`,
observe a native notification and its numeric `MemoryUsagePercent` (the app
acts at `>=80`); for `lmy`, establish that app-monitor registration was
unavailable or unsuccessful and observe a native `low` or `critical` device
event. On either warning path, verify that cleanup retains the current and
selected guide windows, preserves navigation and does not interrupt active
playback. The normal console logs the foreground limit but has no dedicated
registration or event-receipt marker. A missing marker or an ECP counter
change therefore cannot establish delivery; if it cannot be observed safely,
record it as unverified. Do not induce memory pressure or substitute a
simulated event. Signed-package scan evidence is separate for all three.

## `z2l`: why the beacon is still unchanged

The checked-in requirement distinguishes a regular launch (fully rendered,
operable initial UI) from an explicit, valid cold media link (the requested
video starts and responds to the remote). `signalStartupComplete` currently
signals before `handlePendingLaunch`; authorizing a request, setting
`control="play"`, creating a ContentNode, minting an HLS session, or receiving
HTTP 200 cannot stand in for playback. A first-run Welcome must remain an
operable fallback with one beacon; neither a locked PIN/Child screen nor a
cancelled launch should be marked as successful playback.

The app treats only normalized media arguments from `Main` on an existing
connection as eligible for cold tracking. An `roInput` request, even with
identical IDs during startup, supersedes rather than inherits that identity.
The deadline starts at authorized Guide dispatch, not while waiting for setup,
PIN, protected Child access, or user onboarding.

| Path | Local evidence and fallback |
| --- | --- |
| Live | The attempt is bound to the current holder and passed through mandatory AAC discovery to the exact ContentNode. HLS mint blocks readiness until the existing Task/content fence releases it. Local startup/midstream retries replace the tracked ContentNode and reset position evidence. The 390-second outer ceiling preserves the existing AAC, mint and startup retry budgets and falls back through the existing Guide/Retry dialog only while the linked tune still owns playback. |
| Dispatcharr VOD | The authorized resolver Task hands off to a tagged media request and playback identity; the player checks the current ContentNode and waits for an advancing position at or beyond a requested resume seek. The 60-second ceiling includes resolution and can cancel the exact resolver or close the linked renderer to Guide. Renderer denial before a media session still reports a tagged close, and existing focused Retry/Back counts as terminal failure, not playback. |

While picture recovery is pending, progress from the exact outgoing live
reader cannot settle readiness. The original deadline still applies, and
readiness requires fresh samples after replacement or abandonment. A warm input
queued behind cold VOD does not reset or cancel the old renderer's deadline:
readiness leaves the queued input waiting, while an eligible close restores
Guide and dispatches the queued input for its current holder.

`ColdLivePlayback`, `VodDeepLinkNavigation` and `OnDemandPlayer` exercise
production handlers with host adapters: focus and progress, replacement,
missing media, pre-session renderer denial, and bounded fallback. This does not
establish that Roku's untagged native Video state/playhead fields always describe
the replacement reader immediately after a retune. Focus is not proof that a
physical remote action works. On the exact native candidate, verify the live
and supported VOD event order across retry/retune and resume, actual remote
operation, Back/Home, and gated/no-media fallback; also check ordinary launch
and warm input. The first outcome of an admitted cold attempt completes the
deferred `AppLaunchComplete` once; a launch with no cold attempt completes it at
the existing Welcome/Guide boundary.
