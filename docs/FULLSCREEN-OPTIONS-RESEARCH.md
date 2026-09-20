# Fullscreen Options interception investigation

Date: 2026-09-19. Beads: `AerioTV-Roku-ihp.22`, original `ihp.15`.
Target: Streaming Stick 4K 3820RW2, Roku OS 15.3.4, app 0.3.3.

## Outcome / product pivot

The PO reported both 0.3.10 hold-star cases failed and explicitly chose a
different input direction. Development 0.3.11 retires fullscreen-star attempts
in favor of hold OK. No inset is used. Guide star is retained. This supersedes
the product requirement; it does not establish that Roku interception was fixed.
The diagnostic implementation is archived under `tests/native/retired/` and
excluded from the runtime package. Historical evidence below is preserved.

## Fullscreen-only requirement and further research

The PO explicitly rejects any inset. The passing inset is diagnostic evidence
only, not an acceptable product solution. Preserve genuinely full-size video.

Additional checks on 2026-09-19:

- Current [ifSGScreen](https://developer.roku.com/dev/docs/ifsgscreen.md),
  [ifSGNodeFocus](https://developer.roku.com/dev/docs/ifsgnodefocus.md) and
  [ifAppManager](https://developer.roku.com/dev/docs/ifappmanager.md) references
  do not document a pre-firmware fullscreen Options interception API.
- The manifest's `disable_audio_guide_shortcut` concerns the four-press screen
  reader shortcut; it is not a documented single-press media-menu override.
- Published [OS 15.3 and 16.0 developer release notes](https://developer.roku.com/dev/docs/release-notes.md)
  do not list a fullscreen Options override or a fix for this behavior. This
  does not rule out undocumented firmware changes.
- [A 2017 developer reply](https://forum.developer.roku.com/t/asterisk-key-while-video-playback/7874)
  suggests overlaying another interface to receive the key before the player.
  No implementation or applicable current device/firmware is supplied. Ordinary
  sibling focus has already failed here; an overlay/modal input-stack mechanism
  remains an unverified, distinct hypothesis—not a confirmed workaround.
- [A parental-dialog report](https://forum.developer.roku.com/t/options-key-behavior-changes-in-video-player-during-playback/9131)
  describes the system menu ceasing to appear after a PIN dialog. It does NOT
  establish that the app receives the key, and must not be cited as a solution.
- The [Stack Overflow answer](https://stackoverflow.com/questions/39346432/how-to-disable-options-button-functionality-when-video-playing-in-bright-script)
  proposes a one-pixel reduction; excluded by the PO's fullscreen requirement.
- Inspected Jellyfin's `VideoPlayerView.bs`, `.xml`, `OSD.bs` and manifest at
  [`885304d3f64cad0d843e2d58925a303003499d8a`](https://github.com/jellyfin/jellyfin-roku/tree/885304d3f64cad0d843e2d58925a303003499d8a).
  The inspected player/OSD handlers use OK/arrows for custom controls; no working
  fullscreen star interception mechanism was found in those files. This is not
  a claim about every file/platform combination in that project.

All of our earlier diagnostic cases set `enableUI=false`. Its documented
fullscreen Options exception makes a separate native-UI-enabled routing trial
worth isolating, although the documentation does NOT promise it will work.
0.3.9 adds opt-in cases 7/8 with `enableUI=true`, `showUI=false`, and genuine
1920x1080 geometry under sibling/Video focus. Original UI flags are restored on
exit. No inset is introduced into normal playback; no fullscreen fix is claimed.
Procedure: `FULLSCREEN-STAR-0.3.9.txt`. A release-only callback, both menus, or a
smaller picture cannot count as success.

**PO result:** cases 7 and 8 both FAIL. Native UI activation with controls hidden
did not fix interception under either focus configuration. Exact menu/count
readings were not supplied. The diagnostic task ihp.35 is complete; the defect
remains open. Further work should obtain a supported full-screen routing mechanism
or explicit platform clarification rather than treating these flags as a fix.
A source-linked inquiry is prepared in `ROKU-FULLSCREEN-OPTIONS-REPORT.md`; it has
not been submitted externally.

## Update: physical comparison on 0.3.8

PO completed `PHYSICAL-ACCEPTANCE-0.3.8.txt`:

| Configuration | Reported result |
| --- | --- |
| Full size, Video focus (earlier case 1) | Zero star presses reported |
| Full size, sibling focus (earlier case 2) | Zero star presses reported |
| Full size, override re-armed after playback | FAIL |
| Inset 1888x1062, sibling focus | PASS |
| Half size 960x540, sibling focus | PASS |
| Half size scaled 2x back to fullscreen | FAIL |
| Exit restores normal geometry/session | PASS |

The new worksheet's numeric counters, observed-menu fields and visible-size
notes were left blank. PASS means the worksheet's stated condition—Aerio options
without the Roku menu—was met; do not invent measured counts or pixel bounds.

This pattern supports fullscreen/final-geometry classification as the relevant
factor: focus/override changes alone did not work, and scaling a smaller node
back to fullscreen did not bypass interception. It does not establish the minimum
working inset or a working zero-border fullscreen route. The PO subsequently
rejected the inset as a product solution; it remains diagnostic evidence only.

The same worksheet reports star wake-only behavior FAIL (B01), with the subsequent
post-wake star test SKIP (B02). The precise failed wake subcondition is not stated.
The diagnostic comparison task ihp.33 is complete; ihp.15/.22/.28 stay open.

## Observed acceptance evidence

- Ordinary fullscreen star fails (A01), including after mini/fullscreen (A06).
- Guide star and the OK -> Up/Down -> Options routes pass.
- PO subsequently corrected C05: star after Hide picture/wake also fails.
  The earlier PASS marking does not establish a working post-wake Options path.
  The correction does not independently establish whether held star still wakes
  correctly; the failed post-wake menu action is the confirmed observation.
- Focus-only, sibling-input-owner, and focused custom Video approaches have not
  established reliable fullscreen interception. `hasFocus=true` and a passing
  direct handler test are insufficient evidence of OS key delivery.

Source: PO-completed `RETEST-0.3.3-REMAINING.txt`, superseded for C05 by the PO's
verbal correction. There is no confirmed successful fullscreen star path.
Do not infer a universal platform prohibition from older reports.

## Documentation and external reports

1. [Official onKeyEvent documentation](https://developer.roku.com/dev/docs/onkeyevent.md)
   says handlers receive *unhandled* events bubbling up the focus chain. Some
   built-in nodes consume keys first. It also says the Options overlay appears
   when Video has focus and the app handler has not fired, and that an unfocused
   Video should allow the handler to fire.
2. [Official Video documentation](https://developer.roku.com/dev/docs/video.md),
   `enableUI`, explicitly makes the fullscreen closed-caption dialog an exception
   to `enableUI=false`: it appears on Options when video is full height or width.
   The broad focus description and this fullscreen exception must both be taken
   into account; disabling native transport UI is not an Options suppression API.
3. [2023 fullscreen RowList report](https://forum.developer.roku.com/t/how-to-disable-star-options-button-default-behavior/10609)
   describes focus remaining on a RowList: star works during buffering, then opens
   the system menu once playback begins. `enableUI=false` did not solve it.
   A community reply suggests reducing Video size, without demonstrating a fix.
4. [2024 Stick-versus-TV report](https://forum.developer.roku.com/t/onkeyevent-different-on-roku-4k-stick-vs-roku-tv/11011)
   describes missing callbacks on the Stick despite Video not having focus.
   Roku staff states interception depends on fullscreen classification and that
   low-level device implementations can classify a non-100%-sized video as full
   screen. The reporter says their Video was only 360x202; no resolution is given.
5. [Express 4K override report](https://forum.developer.roku.com/t/options-key-override-not-working-on-express-4k-model/10137)
   says `allowOptionsKeyOverride=true` had no effect on that model. This is another
   model/older firmware, not proof of the exact behavior of our 3820RW2.
6. [Audio/Video lifecycle discussion](https://forum.developer.roku.com/t/onkeyevent-stops-receiving-events-when-audio-starts/10088)
   includes reports that active playback intercepts star outside the ordinary
   focus chain; stopping restores delivery. Some models regain star with a mini
   player, others do not. The override field is described as undocumented.
7. [2021 interception discussion](https://forum.developer.roku.com/t/bug-in-10-0-1-options-key-is-not-being-consumed-by-onkeyevent-when-video-node-is-in-focus/9951)
   reports press interception while release may still arrive. Its accepted answer
   is a community post, not an official guarantee that overriding is impossible.
8. [Older roVideoPlayer reports](https://forum.developer.roku.com/t/star-button-on-roku-ultra/5257)
   also describe interception with custom controls. Replacing SceneGraph Video
   with the legacy player is not an evidence-backed remedy.

Searches included the developer forum's full-text search for
`allowOptionsKeyOverride`, fullscreen override, and Options/width, plus GitHub
code search for the override field (no results returned). These searches did not
establish a supported universal fullscreen override or a confirmed current-firmware
workaround. Historical reports support hypotheses, not certainty about OS 15.3.4.

## Why previous attempts were inadequate

- They assumed the key was available to application focus routing. If firmware
  consumes the press first, another Scene/Video handler cannot intercept it.
- They treated a present/settable override field as a reliable platform contract.
  Its presence on this device does not demonstrate effective behavior.
- They tested handler invocation and field state rather than physical delivery.
- They did not isolate playback initialization and fullscreen classification
  before proposing another focus change. The purported successful hide/wake
  comparison was subsequently withdrawn by the PO.

## Code-specific differences (not evidence of a working workaround)

`components/AerioScene.brs`:

- `startPlayback`: makes Video visible, focuses it, then sets control to play.
- `hidePicture`: suppresses captions, assigns `alwaysShowVideoPlanes=false`, makes
  Video invisible, and focuses the separate player-input Group.
- `restorePicture`: restores caption suppression and Video visibility, then
  focuses Video while the stream is already running. It does not restore the
  previous `alwaysShowVideoPlanes` value.

The corrected C05 failure removes the evidence for treating these differences
as a successful workaround or the strongest causal lead. The assignment does
not prove that `alwaysShowVideoPlanes` actually changed: its
initial runtime value has not been recorded. Visibility toggling or post-start
focus timing could also affect native state. No causal conclusion is established.

## Next discriminating device experiment

Use one channel and physical remote presses. Log entry to both Scene and custom
Video key handlers (press AND release), then snapshot playback state, focus owner,
Video visibility, dimensions/transform, enableUI, override flag and video-plane
flag. Exclude URLs, credentials and arbitrary native diagnostic objects.

Compare a fresh launch/tune, paused playback, mini/fullscreen, and hide/wake.
Reset between trials so a persistent video-plane flag cannot contaminate results.
Then vary only one factor at a time: post-playing focus, video-plane flag, or
visibility cycle. The geometry trials have now been completed and insets rejected
by the PO. Further candidates must preserve genuine fullscreen rendering.

Physical success means the Aerio menu opens with no Roku overlay and no retune,
audio interruption, caption regression or broken Back behavior. A release-only
callback is not success if the native menu already appeared on press. ECP is
currently restricted (403); direct handler calls cannot substitute for this test.

The initial research pass made no runtime changes. The subsequent 0.3.4 build
adds an explicitly entered diagnostic under player options, tracked by `ihp.33`.
It compares Video/sibling focus, cross-frame post-start override re-arming,
slightly inset geometry, half-size geometry, and half-size scaled to fullscreen.
Counters distinguish delivered physical presses from releases. It retains the
existing stream and restores normal geometry on exit, tune, stop, minimize or
Hide picture. It does not establish a working fullscreen override by itself.

Physical procedure: [STAR-DIAGNOSTIC-0.3.4.txt](STAR-DIAGNOSTIC-0.3.4.txt).
The test is sequential: native state may carry between cases despite field
restoration. A working case must be repeated after fresh launch/tune before
drawing a causal conclusion. True observed picture size matters for the scaled
case; field values alone do not prove the renderer applied that size.
