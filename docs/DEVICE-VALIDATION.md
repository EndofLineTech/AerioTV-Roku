# Device acceptance — EPG/live builds

## 0.3.11 — hold OK replaces fullscreen star

Normal installation, native compilation, launch and capability refresh succeeded
on 2026-09-20 around 00:33 UTC. All 24 active suites, compiler check and build
passed. The archive contains neither retired OptionsProbe code nor temporary
hold-validation/autoplay code. The old diagnostic sources are preserved under
tests/native/retired but excluded from both application and native-fixture builds.

A temporary on-device controller probe used real timers and real menu nodes on
ESPN 408. While playing, the hold opened options with consumeSelectRelease=true
and the menu parent owning focus. The real menu release handler cleared that
guard, focused the LabelList and left selection empty. Repeating while paused
opened options with state still paused and the same ContentNode. This verifies
timer/menu handoff behavior, not physical OK event delivery; final physical
checks are in RETEST-0.3.11.txt. A controller regression also covers releases
forwarded through the original Video rather than the new menu focus owner.

The PO chose to stop using fullscreen star after both hold-star cases failed.
Old star defects are superseded by that product decision, not declared repaired.
Guide/mini-guide star remains enabled; full-size playback binds app Options to
hold OK and retains the transport Options button. No inset is introduced.

## 0.3.10 — explicit hold-star diagnostic

Installed on 2026-09-19 around 23:13 UTC; native compilation, launch and
capability refresh succeeded. All 24 suites, compiler check and build pass.
Cases 9/10 keep genuine fullscreen video and test a three-second physical hold
under Video/sibling focus. Delivered down/repeat/release events are logged;
a one-second timer can open app options only after a delivered down event.
Release-only events cannot establish a hold. Repeats after the menu opens are
forwarded to the gesture handler rather than immediately closing the menu.

Tests cover single-fire threshold handling, short/release-only events, repeat
counting, cancellation and normal menu behavior outside the diagnostic. They
do not establish physical long-press delivery. Internal instructions are in
HOLD-STAR-0.3.10.txt. Public v0.3.8 artifacts remain unchanged.

## 0.3.9 — genuine-fullscreen native-UI diagnostic

Installed on 2026-09-19 around 22:53 UTC. Native compilation, launch, AAC profile
discovery and capability refresh succeeded. All 23 suites, compiler check and
build pass. New opt-in cases 7/8 retain 1920x1080, scale [1,1], translation [0,0]
while enabling native UI dispatch with controls requested hidden. They differ
only in sibling versus Video focus. Normal playback has no new inset or UI mode.

Controller tests cover full-size geometry, direct case access, selected focus
owner and restoration of enableUI/showUI/enableTrickPlay on exit without changing
content/control. These tests do not establish physical Options delivery. Native
case execution awaits the internal FULLSCREEN-STAR-0.3.9.txt results. Public
v0.3.8 assets/tag remain unchanged; this local diagnostic is not a new release.

Subsequent PO feedback: cases 7 and 8 both failed. The native-UI-enabled
configurations therefore do not resolve fullscreen Options interception.

## 0.3.8 — tester release package and branding

### Subsequent PO physical acceptance

`PHYSICAL-ACCEPTANCE-0.3.8.txt` records 21 PASS, 3 FAIL and 3 SKIP.
All held fullscreen channel-release checks (C01-C07) and startup recovery checks
(D01-D11) passed; ihp.18 and ihp.32 are closed. This includes recovery, bounded
terminal failure, audio-mode preservation, cancellation, mini-guide behavior,
pause and second-viewer continuity.

Star diagnostic: inset and half-size PASS; full-size post-start override and
half-size scaled back to fullscreen FAIL. Diagnostic restoration/session
continuity PASS. No working true-fullscreen case qualified for the follow-up
playing/paused confirmation. Star wake-only behavior also FAIL; subsequent star
after wake SKIP. See FULLSCREEN-OPTIONS-RESEARCH.md for the scoped interpretation.
The detailed count/menu/picture-size fields were not filled in.

### Release-time checks

The versioned release ZIP installed and launched on the target Roku on
2026-09-19 around 21:22 UTC. Native compilation, early AAC profile discovery and
capability refresh succeeded. All 23 suites, compiler validation and package
checks passed; `npm audit --omit=dev` reported zero production vulnerabilities.
No hosted security-scan workflow is configured.

Manifest/version/asset inspection confirms 0.3.8, FHD launcher 540x405, HD launcher
290x218, and splash sizes 1920x1080 / 1280x720 / 720x480. The pinned Apple TV
source image's Git blob matches upstream. Generated FHD artwork was visually
inspected. Roku ECP icon readback is restricted (HTTP 403), so no remote Home-screen
pixel comparison is claimed. License/attribution are in the ZIP, with original
artwork and regeneration script in the corresponding source.

PO approved publishing a testing prerelease with the documented P1 limitations:
fullscreen star (ihp.15/.22) and startup-recovery acceptance (ihp.32). No P0 bugs,
open release-branch PRs, or in-flight verification agents were identified.
This release does not close the remaining physical-media/remote checks.

## 0.3.7 — mandatory AAC discovery gate

Normal build installed on 2026-09-19 around 21:02 UTC. Native compilation,
main launch, early AAC-profile publication and final capability refresh succeeded.
No diagnostic autoplay occurred. All 23 suites, compiler check, build and
whitespace checks passed. Final archive scan found no temporary AAC/startup
validation entry points or known device credentials.

The underlying race had two parts: startPlayback could open direct media when
the requested AAC profile was still absent, and CapabilityTask delayed publishing
an already-discovered profile until optional channel-fact pagination completed.
The gate now waits at most 20 seconds before opening mandatory-AAC media, and
the Task publishes the profile immediately after account validation. Failure
offers explicit Automatic/Direct/Cancel choices; it never silently opens direct.

Native cold-start probe on name-verified ESPN 408:
- Explicit AAC request before discovery: queued=true, noMedia=true,
  noStartupWatch=true. No direct playback request was constructed.
- Profile discovery ready preceded tuning. Playback reached playing with the
  discovered output_profile in the URL and native audioFormat=aac_adts.
- Pending request cleared after starting playback.
- Injected expired profile wait produced the real three-choice error dialog.
- Invoking the real Cancel handler retained the same ContentNode and audio-mode
  setting, with no pending tune left to resurrect.

Temporary probe removed before final installation. Tests additionally cover the
actual Scene deferral/cancellation path, late-result/deadline priority, latest
channel wins, account changes, unavailable/denied catalogs, Auto/Direct bypass,
retry-budget retention, and the actual CapabilityTask body publishing its result
before optional metadata. The identity-change Task test publishes no profile.

ihp.34 is resolved by this code and native evidence. Future physical UI checks
are included in RETEST-0.3.7.txt along with all existing pending startup/star/
held-channel tests; no immediate PO testing is needed while remote.

## 0.3.6 — startup recovery and acceptance reconciliation

Normal installation, native compilation, launch and capability refresh succeeded
on 2026-09-19 around 20:36 UTC. All 21 suites, compiler check, build and whitespace
checks pass. Final archive scan found no temporary startup-injection/autoplay
entry points or known device credentials. The opt-in star diagnostic remains.

Controller coverage includes the actual Scene error handler routing native -5
buffering stalls into the startup retry; exact URL/header retention; one-retry
budget; 25-second boundaries; terminal timeout; stale content/cancellation guards;
menu/mini/sleep/profile preservation; no retry after playing or while paused;
and refusal to retry explicit unsupported-codec/authentication errors.

Native probes injected the known stall detail at the first real buffering event
on name-verified ESPN 408. First run recovered to playing, then independently
retuned to AAC after profile discovery; this identified the separate ihp.34 race.
Second run waited for AAC discovery and started with that profile. It recorded:
- Injected startup stall handled=true, local retry count=1.
- Exact playback URL equality immediately after replacement and at final sample.
- Native state transitioned buffering -> playing; startup watch cleared.
- Later buffering occurred before the final sample. No second startup retry was
  issued, consistent with the startup-only policy. Sustained playback and the
  original intermittent channel-2101 failure are not established by this probe.

Both probes were removed before the final normal build. Physical acceptance of
ihp.32 remains pending; RETEST-0.3.6.txt contains startup tests plus the existing
pending star and fullscreen held-channel-release tests, with complete paths.

Reconciliation closed ten older Live TV implementation records (ihp.2/.3/.4/.5,
ihp.10/.11/.12/.13/.20/.21) using completed worksheets and existing boundary/model
tests. Accepted prerequisite stories b17.1 and b17.5 were also closed. Obsolete
star-menu access blockers were removed from features accepted via transport
Options. Broader capability work ah5.4 remains open; source-switch permission
gating is accepted independently. Detailed acceptance citations are in Beads.

## 0.3.5 — diagnostic navigation correction

Normal installation, native compilation, launch and capability refresh succeeded
on 2026-09-19 around 20:13 UTC. All 20 suites, compiler check and build pass.
The actual Scene-handler regression verifies Fast Forward release is dispatched
before the general key-up early return; a separate regression verifies a missing
release cannot permanently latch navigation. The actual menu builder exposes six
direct case choices. Physical star results for cases 3–6 remain pending.

PO's 0.3.4 results: cases 1/2 showed zero star presses, and Fast Forward stuck at
case 2. The concrete routing defect was the Scene dropping releases before the
diagnostic handler, not established evidence that firmware lost those releases.
Use STAR-DIAGNOSTIC-0.3.5.txt to select the remaining cases without Fast Forward.

## 0.3.4 — opt-in physical Options diagnostic

Installed successfully on 2026-09-19 at approximately 19:41 UTC; native
compilation and main launch completed. Twenty off-device suites and the compiler
build pass. No diagnostic autoplay is present. The new menu entry is deliberate
instrumentation for physical-remote testing, not an accepted interception fix.

The first native install rejected an overlong PRINT argument list in the new
diagnostic despite off-device compiler success. Replaced it with a whitelisted
JSON snapshot; rebuilt and confirmed successful native installation. Physical
case execution remains pending in STAR-DIAGNOSTIC-0.3.4.txt. Controller tests
exercise mode navigation, held-key coalescing, separate press/release counts,
cross-frame re-arm callback guards and same-content/no-retune restoration.

## 0.3.2 — input-path and guide follow-up

Normal build installed on 2026-09-19 at approximately 16:38 UTC. Native launch
and admin capability refresh completed without an observed runtime error during
the 20-second startup check. All 19 automated suites, compiler check, build and
whitespace checks passed. Archive inspection found no temporary probe entry
points or known device credentials. Final launch has no diagnostic autoplay.

Pre-cleanup native evidence:
- A screenshot showed actual group pills after scripted setting selection. This
  does not supersede the PO's report that the normal menu path still fails.
- Menu selection followed by the initiating OK press/release retained hidden
  picture. Screenshot showed black picture and its listening explanation; audio
  position advanced 4.004 seconds during the subsequent observation.
- Bare playback's custom Video node reported hasFocus=true. Physical star remains
  unverified: ECP keypress returned HTTP 403; device policy was not changed.
- A fixed four-second scripted Down hold moved 82 rows and release stopped its
  timer. Held Left entered sidebar with unchanged timeline anchor. Group-options
  signal opened the guide options picker. GroupNavigator star handling also has
  an actual-handler controller test.
- Guide/browser screenshots showed distinct button keycaps. Browser alpha was
  reduced; hardware video is not represented in the screenshot, so perceived
  video transparency still requires physical acceptance.

An earlier variable-duration probe did not establish accelerated scrolling;
the fixed-duration guide-only probe supplies that evidence. Temporary probes
restored Modal layout and were removed before the final normal install.
Use [RETEST-0.3.2.txt](RETEST-0.3.2.txt). PO-completed worksheets remain intact.

Roku documents Options overlay/focus behavior, and its developer forum records
model-dependent interception despite focus and override flags. The new focused
custom Video route remains a candidate awaiting physical-remote acceptance:
- https://developer.roku.com/dev/docs/video.md
- https://forum.developer.roku.com/t/onkeyevent-different-on-roku-4k-stick-vs-roku-tv/11011
- https://forum.developer.roku.com/t/options-key-override-not-working-on-express-4k-model/10137

## 0.3.1 — acceptance-fix candidate

Normal-app installation succeeded on 2026-09-19 at approximately 15:09 UTC.
Native compilation, launch, and admin capability refresh completed; a 25-second
startup observation showed no diagnostic autoplay or runtime error. Temporary
acceptance probes and their exported component functions were removed before
packaging. All 17 automated suites, compiler validation, build, and diff whitespace
checks passed.

Pre-cleanup device probes exercised actual guide-setting picker handlers: pills
became visible, sidebar shifted grid origin from x=96 to x=400, and restoring modal
returned x=96. Group-list bounds ended at y=822, before footer y=866. Hidden-picture
mode reported video invisible and captions suppressed while audio advanced 1.53s;
pause worked and restoration retained ContentNode identity. Eight local logo files
occupied 2,741,309 bytes, with 7,020ms cold versus 231ms warm readiness.

Guarded local recovery replaced the decoder ContentNode and returned to playing.
Server status reported the same source URL and client counts 2 -> 2. This proves
the restart path on a healthy stream, not recovery from the reported actual frozen
source or continuity of another viewer. The temporary connection is bounded and
cancelled after recovery; client counts are not client-identity evidence.

Physical star interception, caption/picture perception, held wake behavior, actual
source-freeze recovery and second-viewer cleanup remain acceptance checks. Use
[RETEST-0.3.1.txt](RETEST-0.3.1.txt); all 12 acceptance issues remain in progress.

## 0.3.0 — combined Live TV and Guide implementation pass

Final normal-app installation succeeded at approximately 2026-09-19 05:31:58 UTC
(96,968-byte archive), with native compile/launch and capability
refresh observed. A screenshot of the preceding normal build showed the refreshed 1,353-channel lineup, correct
12-hour midnight labels, episode facts and progressive category colors. Temporary
probes are excluded from the final package. Fourteen automated suites, compiler
validation and package checks passed; the production archive contains no tests,
tooling, backlog data or hardcoded diagnostic output-profile override.

### Native audio diagnosis and repair

Direct MPEG-TS on channel404: video advanced but audioFormat=none, tracks=[], audio
position=0. Channel405 and Food Network239 reported aac_adts and advancing audio.
The existing server profile named Web Player (AAC Audio), id2 in this environment,
produced aac_adts on all three. Production discovers a compatible active profile;
it does not hardcode id2 or mutate/create server configuration.

Integrated Auto mode natively retuned channel404 once using the discovered profile and
reported state=playing with audio position 6.937 and video position 6.950 at the
sample. Channel405 and Food Network remained on direct output with advancing audio.
One earlier sample rebuffered; sustained audible playback remains a PO check.
Native audioChannelsCount stayed zero even on working audio, so fallback does not
use that field. Audio format, not a guessed provider codec, triggers the retry.

Correction: early notes incorrectly called channel404 ESPN without recording its
name. A subsequent name-logged probe identified it as Big Ten Network. Additional
native direct-versus-AAC checks explicitly verified:
- Big Ten Network404: none/audio position0 -> aac_adts/audio9.820/video9.829, playing.
- CBS Sports Network406: none/audio position0 -> aac_adts/audio10.759/video10.740, playing.
- ESPN408, selected by normalized name: none/audio position0 ->
  aac_adts/audio10.983/video10.992, playing.
Thus ESPN and two other affected channels have native decoder/timestamp evidence.
These measurements still require audible/perceptual confirmation in the final worksheet.

### Native guide integration probe

On 1,336 channels / 34 groups before the later server refresh:
- Guide settings: 11 entries; top pills visible; sidebar in focus chain.
- Rich details active and focused; detail cache populated; System clock resolved 12.
- Global ESPN query returned 148 authorized matches.
- Created a temporary collection: membership 1, then 0, then deleted it.
- Saved a future temporary reminder: count1, then cancelled to count0.
- Restored original settings/collections/reminders after the probe.

The final code additionally bounds details to32, failures to64, collections to20,
reminders to50 and resident guide windows to3. Model tests exercise decimal order,
visibility fallback, deleted-group reconciliation, global search, collection scope,
category precedence, unknown flags, enrichment identity and reminder dedup/expiry.

### Held navigation and logo reuse

The native held-key probe retained the exact ContentNode while a candidate was
pending, then changed channel after release. Console showed only the final tune
(239 to245) rather than every preview. The final state sample preceded buffering/
playing notifications; both followed. Reopening the browser retained the same
Poster node (isSameNode=true). Complete cold/warm download timings were not captured;
provider/server latency remains distinct from avoided node recreation.

A subsequent instrumentation install coincided with a device restart: uptime was
161 seconds and console clock history reset. No causal app exception was captured.
Cause is unknown; tracked as rgs.13 rather than attributed to the app. The final
normal package subsequently installed and launched successfully. Sustained resource
and audiovisual acceptance remains required.

### Final acceptance

Use FINAL-TEST-RESULTS-0.3.0.txt for both epics. Especially verify physical Options
interception/focus, audible AAC recovery, natural held-key/release behavior, scale
preview pixels/captions, real multi-viewer source switching, persistence/account
boundaries, and sustained stability. Optional TMDB positive-path acceptance needs
a user-supplied key; no real key was supplied during automated checks. Manual
favorite/collection editors use select-item then Move earlier/later; group sidebar
is an overlay adaptation, not a shifted/docked grid. These UX choices await PO review.

## 0.2.13 installed — 2026-09-19 03:19 UTC

Addresses acceptance defects ihp.15/.16/.17. Final installer reported success;
native compile/launch completed around 03:19:03 UTC and capability refresh passed.
No new runtime error appeared in the 18-second launch capture. Twelve suites and
compiler/package checks pass. Temporary autoplay/probe timers were removed.

An initial native scripted probe showed Scene.hasFocus=false even after prior
Scene focus requests; transport remained in the focus chain after Up. Added an
explicit focusable player-input Group and routed bare-player focus handoffs there.
The second probe reported inputFocus=true before entry and after each Up handoff,
and transportFocus=true after Down following Up, Left and Right. It also tested
the queued banner-timeout handler against explicitly opened information.

Video field readback confirmed allowOptionsKeyOverride=true and focusable=false.
The app menu opened with 15 entries, title AerioTV player options, and menu focus
true. This directly exercised application handlers, not a physical star press;
OS-level interception still requires retest. The Options-override investigation
also consulted https://forum.developer.roku.com/t/options-key-override-not-working-on-express-4k-model/10137;
historical device differences are why field readback alone is not acceptance.

Native caption bounds were {x:1424,y:245,width:400,height:22}; a screenshot showed
the channel caption clear of the y=270 timeline and guide rows. Video is now
400×225 at [1424,16]. The video plane is black in developer screenshots, so the
capture establishes UI layout, not audiovisual quality.

Focused physical checks are in RETEST-0.2.13.txt. Preserve the original completed
0.2.12 worksheet; after menu access passes, resume its blocked sections 8–12.

## 0.2.12 installed — 2026-09-19 02:08 UTC

Installer success; native compile/launch completed around 02:08:49 UTC followed
by successful capability refresh. No new runtime error appeared in the final
20-second capture. Twelve suites, compiler check and package build pass.

Before final installation, a temporary read-only probe tuned the saved channel
(408), reached playing (431 ms startup beacon), and ran the actual StreamSourceTask
list operation. It returned six member streams and one connected client. The
probe then stopped playback. No source-switch POST was exercised in that native
check. All temporary autoplay/timer/probe code was removed from the final package.

The new Task-flow suite executes the production Task body with scripted HTTP
responses: authorization/identity rejection, member validation, read-only list,
one POST plus URL confirmation, equal-count client replacement, already-active
no-op, failed mutation without retry, invalid operation/ID and exhausted deadline.
Model cases cover joined viewers, missing/duplicate/truncated lists, empty initial
clients and case-sensitive IDs. Scene-handler tests cover stale metadata Task
cancellation. These are HTTP-boundary tests, not native network emulation.

Client continuity now means all original IDs remain present in a complete
confirmation list; it does not promise uninterrupted audio/video. Final acceptance
must still include a real member-source change with another viewer, already-active
selection, permission revocation, and clear preserved/changed/unknown messaging.
Confirm old Stream Info does not return after a source change and menu close/reopen.

## 0.2.11 installed — 2026-09-19 01:29 UTC

Final app installation succeeded, native compile/launch completed around
01:29:45 UTC, and Dispatcharr capability refresh succeeded. No runtime error was
observed during the 22-second capture. Eleven automated suites and the build's
compiler checks passed. The standalone native test-pattern app was replaced by
the normal guide-launch app.

Internet research identified existing Dispatcharr status fields for source
resolution/FPS/codecs/pixel format. A read-only metadata Task now supplies clearly
labeled server facts in Stream Info; populated live-server responses and role/error
paths still need validation. The native decoder fields remain independent.

Scaling geometry, preferences and menus are implemented as preview controls.
Native fixture results and links are in VIDEO-ASPECT-RESEARCH.md. Extend the
deferred visual pass with 4:3, 16:9, 21:9 and baked-in-letterbox samples; compare
Fit/Fill/Stretch in fullscreen and mini-player, check caption placement/clipping,
same-session continuity, saved mode/aspect after relaunch, and account isolation.
For channels with no aspect override, verify native Fit fallback. Confirm source
metadata refresh preserves the currently focused Stream Info row.

## 0.2.10 installed — 2026-09-19 01:06 UTC

Installer success; native compile/launch completed at approximately 01:06:51 UTC,
followed by a successful Dispatcharr 0.31.0/admin permission refresh. No runtime
error appeared in the final 22-second capture. Normal guide launch was restored;
the temporary diagnostic autoplay and timers are absent from source/final package.
Ten automated suites, compiler validation and package build pass.

### Short native playback investigation

Temporary diagnostic builds selected the saved channel (404), waited 12 seconds,
inspected native fields, and stopped playback. The extended probe then exercised
the actual minimize, expand, Hide picture and sleep-expiry handlers, with three
seconds between observations. Native results at approximately 01:00:46–01:01:06 UTC:

- Initial stream reached `playing`; Roku startup beacon measured 1,951 ms.
- `decoderStats`: `renderCount=600`, `frameDropCount=0`, `repeatCount=0`,
  `streamErrorCount=0` at the first sample.
- `resolution=""`, `videoTrack=""`, `tracks=[]`; `videoFormat="mpeg4_10b"`,
  `audioFormat="none"`. These are native reports, not perceptual audio confirmation.
- Mini-player: `state=playing`, same ContentNode (`isSameNode=true`),
  `renderCount=780`.
- Expanded then covered picture: `state=playing`, same ContentNode,
  cover visible, `renderCount=960`.
- Sleep deadline set to one second ahead for the diagnostic only. One expiry
  message followed; final `state=stopped`, playing channel cleared, cover false.

The measured decoder counters are now included in Stream Info. Render counts are
not interpreted as source FPS. No decoded dimensions were returned for this
sample. Public Group transforms and the native field inventory do not establish
a working Fit/Fill/Stretch implementation, so ihp.10 is explicitly blocked on
a supported/measured mapping. This is not a claim that every possible Roku
rendering approach is impossible.

Physical audio/picture/caption confirmation, alternative codecs/aspects,
Dispatcharr connection identities and multi-viewer source switching remain
deferred. Add to the final pass: decoder values after retune/pause/Stop; readable
menu counters; mini-guide footer; missing/cached browser metadata; explanatory
out-of-filter channel-surfing behavior; and source-operation close semantics.

## 0.2.9 installed — 2026-09-19 00:51 UTC

Following the owner's instruction to install finished builds and defer physical
validation to the end, installed 0.2.9 (including all 0.2.8 additions). Installer
reported success. Native compile/launch completed at approximately 00:51:42 UTC;
the subsequent permission refresh reported admin level 10 / Dispatcharr 0.31.0.
No runtime error appeared in the 30-second capture. Ten off-device suites and
compiler/package checks pass. This supersedes the installed-version entries below.

The foreground Hide picture mode overlays black over the existing Video and
fades its explanatory hint after six seconds. Handler-level regression tests
exercise the actual Scene functions using field adapters: content/control,
visibility and mute are preserved when covering; pending preview tuning is
cancelled; sleep deadline survives; Play/Pause stays routed to Video; wake-key
press/repeat/release is consumed; the cover cannot open over the mini-guide.
These checks do not establish native audio continuity, video-plane occlusion or
caption behavior. No screensaver setting is changed. Physical validation must
include captions, paused/buffering/error states, sleep expiry, Home/exit and TV
power behavior; the feature is explicitly foreground-only.

Player submenu Back behavior now returns to the parent option with restored
focus; source confirmation returns to the source list; star dismisses to playback.
Native acceptance must include pending source requests while leaving/reopening
menus, rapid Back, and confirming that cancellation does not issue a source change.

## 0.2.8 local build — program search and persistence

The owner is remote; physical acceptance is deferred. This version was built
locally and subsequently included in the installed 0.2.9 package. Acceptance is tracked on
`AerioTV-Roku-5tg.11` and `AerioTV-Roku-b17.3`; the deferred-test record on ihp
also references these additions.

Program search uses the v0.31.0 `ProgramViewSet.search` route and
`ProgramSearchResultSerializer` source contract: separate title/description
filters, time bounds, field selection, pagination and channel associations.
The server filters user-level/adult access, and the Roku additionally intersects
returned IDs and EPG mappings with its connected summary lineup. Server search
uses base EPG assignments, so overridden/unindexed/dummy schedules may be absent.
No full ten-day EPG is downloaded to construct a local index.

Model coverage includes time boundaries, malformed rows, unauthorized/unmapped
channel exclusion, effective-name selection, chronological order, deduplication,
page/display bounds, and Past/Now/Upcoming classification. Registry-adapter tests
cover the legacy default, Off/key deletion/reload, malformed policy, On without
saving an unvalidated key, and flush failure. These are off-device checks, not
proof of HTTP Task execution, focus routing or actual registry persistence.

The deferred native procedure is to search both titles and descriptions, navigate
pages, cancel during loading, edit and replace a query, and select past/current/
future results under All/Favorites/group/channel-search filters. Verify correct
guide row/time, unchanged playback while searching in mini-player mode, useful
empty/error/permission states, and no stale results following account changes.
Repeat Remember Off/relaunch, On/successful-connect/relaunch, and Forget while Off;
confirm the chosen policy and saved-key behavior on the real device.

## 0.2.7 Live TV integration — 2026-09-18 local / 2026-09-19 UTC

Developer installer accepted the 50,050-byte archive (MD5
`87d2db908e2919017fdeb9b429f62216`). Native compilation and launch completed on
the 3820RW2 / OS 15.3.4 build 2402 at approximately 00:21:56 UTC. No new runtime
error appeared during the 35-second capture. The new capability Task completed
with `level=10`, `source-switch=allowed`, and `version=0.31.0`. Eight off-device
test suites and the compiler/package build passed; these do not prove the new
remote interactions or media continuity.

The build includes schema-versioned preferences/history, Channels and Recently
Watched overlays, previous-channel toggle, mini-player/Back routing, transport,
sleep timer, source picker, and the initial Stream Info snapshot. Device ECP
remains in Limited mode, so physical-remote verification is required. Existing
0.2.6 evidence below must not be treated as acceptance of the changed bindings.

Source-switch acceptance requires comparing Dispatcharr client identities/counts
before and after a confirmed change, including another viewer. Client counts
alone do not prove connection identity or uninterrupted playback. The app does
not issue player stop/play when switching the shared upstream, but that code
property is not a substitute for observing server and device behavior.

### Native scaling and stream-metric findings

The OS's actual Video field inventory includes `width`, `height`, `translation`,
`scale`, `clippingRect`, `resolution`, and `decoderStats`. It does **not** include
`videoDisplayMode` or `scaleMode`. The public Video/content-metadata references
checked in this session do not establish a SceneGraph Fit/Fill/Stretch mapping.
Generic Group transforms are not yet proven to crop/stretch the hardware video
plane correctly. No unverified rendering mode is exposed or written.

Stream Info currently reads documented `videoFormat`, `audioFormat`,
`streamInfo.measuredBitrate`, `streamInfo.streamBitrate`, and
`bufferingStatus.percentage`. Network selection bitrate is labeled separately
from stream bitrate; the latter's units are not assumed. URLs/headers are excluded
from the report. Retuning clears readiness before the new player reaches playing.
Resolution/frame rate remain `Unavailable`: the native `resolution` field exists,
but its semantics and decoder-stat schema still require playback measurements.
The build logs decoder-stat key names once per tune for that investigation.

### Audio-only feasibility findings

The [Video reference](https://developer.roku.com/dev/docs/video) documents
`enableScreenSaverWhilePlaying=false` by default. Enabling it permits a
screensaver only when playing video occupies less than 50% of the screen.
For genuinely audio-only streams that flag has no effect; `disableScreenSaver`
controls suppression instead. An opaque foreground screen over the existing
Video is a possible listening experience, but would still receive/decode the
video and would not establish bandwidth savings, power savings, TV power-off
behavior, or playback after leaving AerioTV.

The [Audio node reference](https://developer.roku.com/dev/docs/audio) describes
streaming audio playback, not extraction of audio from this already-verified
continuous MPEG-TS video connection. Changing player type would need separate
compatibility and session-lifecycle tests. Neither background playback nor an
audio-only control is claimed by this build. A foreground listening-mode scope
decision and physical-device demonstration remain required for ihp.13.

Hardware result for 0.2.0: installation succeeded, but setup showed six focusable
boxes with no app-drawn text; native URL/API-key dialogs remained usable. The
shared helper assigned a Font with no URI. Build 0.2.1 preserves the default
Label font; the user confirmed that fix on the device.

## Verified hardware session — 2026-09-18

- Device: Streaming Stick 4K **3820RW2**, Roku OS **15.3.4 build 2402**, 1080p UI.
- 0.2.1 debug console confirmed `onChannelsLoaded` failed at the expression
  `event.getRoSGNode() <> m.task`: operator `<>` cannot compare two roSGNodes.
  The task had already successfully returned **1,335 channels**.
- 0.2.2 uses `isSameNode()` in both connection and guide completion callbacks.
- Developer installer reported Install Success. Observed launch and loading on
  the debug console; captured a populated guide showing 1,335 channels, real
  logos, schedule times and program titles. No new runtime crash was observed
  during the capture interval.
- Preserved the already-selected Remember API key behavior before reinstalling;
  the new build reconnected using that saved key without re-entering credentials.
- ECP keypress returned HTTP 403 under the device's current remote-control policy.
  Navigation, redesigned setup buttons, cancellation and timeout remain unverified
  by remote automation. No device remote-control setting was changed.
- Console reported one oversized logo texture (3200×2400). Decode-size bounds
  remain a memory/performance follow-up; a populated screenshot is not a memory test.

### Live playback investigation

- 0.2.2 playback failed with Roku error -1, category `http`, internal code 2,
  source `buffer:reader`: **Full-content response on a range request:200**.
  Authentication had succeeded. The MP4 reader requested byte ranges while
  Dispatcharr's live fMP4 endpoint emitted an HTTP 200 continuous response.
- Tested existing `/proxy/ts/stream/<uuid>?output_format=mpegts` with Roku
  `streamFormat="mpegts"`. At 20:57:12 UTC the native player reported `playing`;
  its start-complete beacon recorded 1,633 ms. The user confirmed **Picture and audio**.
- No additional service or Dispatcharr configuration change was made.
- The developer screenshot captured a black video plane and is not visual
  playback proof. Picture/audio confirmation came from the user at the TV.
- A temporary compile-time autoplay smoke test selected the saved channel for
  this investigation; it was removed for the normal 0.2.3 package.
- Tested one channel/device combination. Codec inventory, sustained playback,
  repeated tune/stop and pause/seek behavior remain to be verified.

### Physical remote channel switching — 0.2.4

- User confirmed various channels already played from the 0.2.3 guide, and
  native Options and Back worked before this change.
- Installed 0.2.4 and asked the user to test Down, Up, `*` and Back during playback.
  User reported **All four work**.
- Native logs confirmed `[player-input] down`, tuning 404 → 405, then
  `[player-input] up`, tuning 405 → 404, each reaching `playing`.
- Additional rapid Up/Down presses tuned channels in the 401–409 range and
  recovered to `playing`. This does not establish server-side connection cleanup
  timing or long-duration playback reliability.
- Guide filter order, missing current IDs, singleton/empty lineups, non-wrapping
  endpoints and rapid candidate advancement have off-device model regression tests.
- Native Video keeps focus. No UI-disable/focus handoff was needed to receive
  otherwise-unhandled directional events while preserving Roku Options.

### Live information overlay and remote focus — 0.2.6

- 0.2.5 displayed the information panel, but the user reported OK did not toggle
  it. Console showed native paused/playing transitions and no app OK callback:
  Video consumed OK even with `enableUI=false`.
- 0.2.6 gives the Scene playback key focus. It handles OK and Play/Pause separately
  and provides an app-owned `*` audio/caption menu using native Video track fields.
  This intentionally replaces the native Roku Options panel.
- User reported **Everything works** for information correctness, OK recall,
  Up/Down, the new audio/caption menu, Back and Play/Pause.
- Console confirmed three `[player-input] OK info` events without corresponding
  pause, then a successful channel switch, followed by explicit Play/Pause pause.
- Captured the paused overlay on channel 240 / Freeform: current program
  “10 Things I Hate About You” (14:55–16:55), synopsis, schedule progress with
  eight minutes remaining, and “Freaky Friday” next (16:55–19:00). The clock and
  paused badge were visible. The channel number is duplicated in the header when
  the provider embeds it in its channel name; cosmetic cleanup remains.
- No oversized-logo warning appeared in this session after setting load sizes.
  Peak texture/application memory has not been measured.
- Rollover and metadata-failure recovery have deterministic model tests; an
  actual program-boundary transition and server outage during playback still
  need hardware acceptance. Track menus were user-verified at the control level;
  a multi-language/audio-codec matrix remains to be tested.

Off-device model tests include a synthetic
1,400-channel window; they do not simulate Roku rendering, network or video playback.

Record Roku model number and OS build, output resolution, remote type,
Dispatcharr 0.31.0 connection/proxy configuration, channel count, and stream codecs.

## First smoke test

- [x] In 0.2.1, confirm AerioTV title, setup field names/values and status text appear (user report).
- [x] Install 0.2.2 `out/aeriotv-roku.zip`; check console for runtime/XML errors during launch/loading.
- [ ] Connect with API key; repeat with dashboard username/password.
- [x] Confirm the guide opens at Now with real logos/programs (device screenshot).
- [ ] Confirm Connect and Forget Connection are distinct action buttons, with visible focus.
- [ ] Move down/up through channels and left/right through programs.
- [ ] Open `*`: groups, favorites, search, date/time, refresh and settings.
- [ ] Browse to three days back and seven days forward where data exists.
- [x] Tune the previously failing channel via MPEG-TS and confirm picture/audio (user report).
- [ ] Record actual codecs and expand the sample to representative H.264/AAC and other channels.
- [x] Back from playback returns to the guide (user confirmation).
- [ ] Verify exact row/time focus restoration across filtered-lineup switches.
- [x] Up/Down change live channels and `*`/Back continue working (0.2.4 physical remote test).

## Authentication, storage and account scope

- [ ] Keyboard Save/Cancel/Back restore focus and secret fields are masked.
- [ ] Wrong credentials, denied permissions, offline server and timeout recover.
- [ ] Back cancels connecting; a later response cannot apply stale data.
- [ ] Remember on reconnects after relaunch; off requires credentials again.
- [ ] No dashboard password is persisted; the API key is registry-local.
- [ ] Changing the server URL clears entered credentials.
- [ ] Favorites/group/channel survive relaunch on the same account.
- [ ] Account changes cannot restore the previous account's preferences/lineup.
- [ ] Forget removes saved connection/preferences and releases in-memory guide data.
- [ ] Restricted accounts match Dispatcharr's visible-channel output, including
  hidden/adult restrictions, profile unions, and effective overrides.

## Guide correctness and navigation

- [ ] Decimal channel numbers, effective names/logos and assigned EPG sources match.
- [ ] Shared TVG IDs and dummy UUID programs map correctly; missing mappings do
  not guess by name or expose another channel's schedule.
- [ ] No-guide channels remain tuneable; loading and failed guide states differ.
- [ ] Current OK tunes; past/future OK shows details with an explicit Watch live action.
- [ ] Group/search empty states recover through `*`; removing the last favorite works.
- [ ] Date/time choices represent local time correctly, including DST transitions.
- [ ] Left/right boundaries respect the requested history/future horizon.
- [ ] Held remote navigation stays responsive across a 1,400-channel lineup.
- [ ] Refresh replaces metadata while preserving channel/time focus.
- [ ] Window failures back off; Refresh permits an explicit retry.
- [ ] Navigating away from an in-flight window cancels/coalesces correctly.
- [ ] Opening/closing menus or program details restores focus reliably.

## Playback compatibility — architecture decision point

- [x] Test fMP4/MP4 compatibility: failed due to HTTP range semantics; route replaced.
- [x] `/proxy/ts/stream/<uuid>?output_format=mpegts` plays through the actual server on the target Stick.
- [ ] Authentication, TLS, redirects and any output profile behave correctly.
- [ ] Record video/audio codec and whether the Roku reports unsupported media.
- [ ] Repeated tuning/stopping leaves only one active Dispatcharr connection.
- [ ] Native controls/options and error dialogs preserve expected focus.
- [x] 0.2.6 OK toggles on-air information without pausing (user and console).
- [x] 0.2.6 app-owned audio/caption menu, channel switching and Back work (user).
- [x] Current/next data, logo, schedule progress and paused indicator render (screenshot).
- [ ] Confirm live rollover at a real program boundary and refresh-failure recovery.
- [ ] Home exits and Dispatcharr releases the stream.
- [ ] If playback fails, capture the numeric player error and redacted console
  output. Evaluate existing output configuration; do not assume or add an HLS route.

## Performance and visual acceptance

- [ ] Capture setup, populated guide, details, menus, and player banner at 1080p.
- [ ] Check safe areas, long titles, focus visibility and living-room readability.
- [ ] Measure connection time, initial guide time, cached navigation, tune latency.
- [ ] Measure peak memory during a guide response, mapping load, logo loads,
  cache replacement and simultaneous video/guide state.
- [ ] Prolonged navigation does not grow row/cell/cache counts without bound.
- [ ] Repeat after invalid/large responses and account changes.

## Later time-shift investigation (not implemented in this build)

- [ ] Establish the native retained/seekable live range, rather than assume 60 minutes.
- [ ] Test a completed catch-up program and an in-progress restart separately.
- [ ] Record provider archive lag, retention, permissions and supported seeking.
- [ ] Define expiry, channel-change and Go Live behavior before implementation.

Roku debug console: TCP port 8085. Redact credentials and any credential-bearing
URLs from platform logs before sharing. Screenshots should omit setup secrets.
# 0.3.13 incremental metadata cache checkpoint

Native results and limitations: `METADATA-CACHE-IMPLEMENTATION.md`.
Consolidated pending physical worksheet: `PHYSICAL-VALIDATION-0.3.13.txt`.
All temporary controller/autoplay/memory hooks were removed before restoring
the normal development package. Existing completed worksheets remain evidence.
