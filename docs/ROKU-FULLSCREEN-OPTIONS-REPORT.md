# Draft Roku developer-support inquiry: fullscreen Options delivery

Status: prepared locally, **not submitted**. No credentials, server URLs or
device network addresses are included.

## Question

Is there a supported way for a SceneGraph application to receive and consume
the physical Options (`*`) press during genuinely fullscreen native Video
playback, without the Roku system Options overlay also opening?

We need to present an application options panel that includes audio/subtitle
controls. Reducing the video rectangle, leaving a border, or scaling a smaller
Video node back to fullscreen does not meet the requirement.

## Environment

- Roku Streaming Stick 4K, model 3820RW2.
- Roku OS 15.3.4, build 2402; application UI and display baseline 1920x1080.
- BrightScript/SceneGraph; native Video playing continuous MPEG-TS live media.
- Custom Video subclass and Scene both have Options handlers. The subclass
  returns true for delivered Options events and forwards them to the Scene.
- Other physical keys work; the application menu works through OK/Up/Options.
- ECP key injection is restricted, so the results below are physical-remote tests.

## Physical results

| Case | Geometry / input configuration | Result |
| --- | --- | --- |
| 1 | 1920x1080; custom Video focus; enableUI=false; override=true | No star presses recorded by app |
| 2 | 1920x1080; sibling Group focus; enableUI=false; override=true | No star presses recorded by app |
| 3 | 1920x1080; sibling focus; override toggled off/on across frames after playback starts | Application-menu interception failed |
| 4 | 1888x1062 inset; sibling focus | Application menu without system menu: PASS |
| 5 | 960x540; sibling focus | Application menu without system menu: PASS |
| 6 | 960x540 scaled [2,2] back to fullscreen; sibling focus | Application-menu interception failed |
| 7 | 1920x1080, scale [1,1], origin [0,0]; enableUI=true, showUI=false; sibling focus | Failed |
| 8 | Same as 7, with custom Video focus | Failed |

`allowOptionsKeyOverride=true` was used in the diagnostic configurations.
The tests retained the existing stream rather than stopping it to regain keys.
The tester reports ordinary fullscreen star opens Roku's system menu. Detailed
menu/counter values were not recorded separately for cases 3 and 6–8; their FAIL
means the required app-menu-without-system-menu result was not achieved.
Hide-picture/wake also did not provide a working fullscreen path.

## Why the published references leave this unclear

- [onKeyEvent](https://developer.roku.com/dev/docs/onkeyevent.md) says the Options
  overlay appears when Video has focus and the app handler has not fired, and
  says an unfocused Video should allow the application handler to fire.
- [Video.enableUI](https://developer.roku.com/dev/docs/video.md) identifies the
  fullscreen closed-caption dialog as an exception to enableUI=false.
- A [Roku staff reply](https://forum.developer.roku.com/t/onkeyevent-different-on-roku-4k-stick-vs-roku-tv/11011)
  describes device-dependent fullscreen classification.
- [Other developers](https://forum.developer.roku.com/t/options-key-override-not-working-on-express-4k-model/10137)
  report that the override field has no effect on some 4K devices.

We have not found a documented interception method in ifSGScreen,
ifSGNodeFocus or ifAppManager. The audio-guide shortcut manifest flag controls
the four-press shortcut and is not a documented override for this media menu.

## Clarification requested

1. Is fullscreen Options intentionally reserved by firmware on this device/OS,
   regardless of SceneGraph focus and the application's return value?
2. Is `allowOptionsKeyOverride` supported for applications? If so, what are its
   prerequisites, scope and required initialization sequence? Does it need an
   approved capability that is not present in a sideloaded development app?
3. Is there a supported app-owned overlay/dialog input mechanism that retains
   true fullscreen video and receives the key before the system media overlay?
4. Does behavior differ for continuous MPEG-TS/live content versus HLS or VOD?
5. Is there a firmware fix, documented restriction, or current sample showing
   the supported implementation on Streaming Stick 4K?

These are questions, not assertions that an entitlement or hidden API exists.
A confirmed supported sample or an explicit platform restriction would help us
avoid further unsupported workarounds.

## Reproduction in this project

The public source is https://github.com/EndofLineTech/AerioTV-Roku.
The published v0.3.8 diagnostic covers cases 1–6. Cases 7–8 were added to the
local 0.3.9 investigation build and are not in that published release.

1. Tune a working live channel and wait until it is playing.
2. OK -> Up -> Options -> Fullscreen * diagnostic (temporary test).
3. Select the numbered case directly. Use a fresh launch/tune for independent
   trials. Wait one second after selection and press/release physical star.
4. Record the displayed menu and app press/release counters.

A separate credential-free minimal reproduction would still be needed for
vendor execution without a Dispatcharr account. No result from such a reduced
reproduction is claimed here.
