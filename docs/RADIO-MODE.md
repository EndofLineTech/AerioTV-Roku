# Radio Mode on Roku

Radio Mode is a foreground live player screen showing the station, guide
program and channel logo when available. Ordinary video still opens normally
with **Settings > Player > Radio Mode by Default** off; declared radio stations
open Radio Mode regardless. Enabling the setting affects subsequent live
tunes on this Roku only. It is not synced. To open Radio Mode for a single
ordinary channel, hold OK in the video player and choose **Radio Mode
(foreground listening)**.

Use Left/Right to choose a control and OK to activate it. **Watch Video**
reveals the current stream without reopening it, and preserves pause and the
sleep deadline. Guide options also offers **Watch Video** for a selected
channel that would otherwise open in Radio Mode. This overrides presentation
for that tune, not provider radio detection. On a genuinely audio-only
station the full-screen player still has no picture to show.
**Stop and return to guide** or Back ends playback and restores the guide at
the selected row and time (live-following guide selection advances with time
as usual). **Player options** includes the existing sleep timer. Play/Pause
controls the current stream where supported by the native reader.

The card distinguishes startup, buffering, playing and paused. The same Roku
live startup retry budget and single midstream reconnect apply. A terminal
failure stops the renderer and presents **Channel unavailable**, with an
explicit **Retry channel** or **Return to guide**. There is no new repeating
radio retry timer that can start audio after cancellation.

### Playback path and limits

The e3e.11 device pass reported advancing AAC and no video on one
provider-declared Dispatcharr station using Roku's Video node. That is evidence
for this existing audio playback path, not for the Radio Mode screen or other
providers/codecs. Roku's Audio node is not a way to extract the audio
track from the existing continuous MPEG-TS request; see the
[audio-only feasibility findings](DEVICE-VALIDATION.md#audio-only-feasibility-findings).
Radio Mode does not open a second media session or switch transport just to hide
video. On mixed audio/video feeds it still receives video. It does not provide
the upstream audio extraction/remux and adaptive hold-back, does not alter
provider radio flags, and does not support background, across-app or TV-off
listening. No battery, power or bandwidth savings are claimed.

### Native acceptance plan — not run on this candidate

Follow [native device workflow](NATIVE-DEVICE-WORKFLOW.md) with an authorized
read-only lineup and lease. Record Roku model, OS, exact ZIP hash, provider,
sanitized fixture/codec, and visual/audible observations separately from logs.
Never mark a provider channel as radio to create a fixture.

1. With the default off, tune a known-good video channel with OK. Confirm
   ordinary picture/audio, existing player Back-to-mini and picture recovery
   controls, and the separate Hide Picture behavior. Open Radio Mode manually
   and verify that video disappears but audio continues.
2. On the same Roku, enable the default, restart AerioTV and tune the same
   channel. Verify radio presentation, correct channel/logo/current program,
   and no second playback request when choosing **Watch Video**. Pause first
   and verify that revealing the picture preserves pause. Retune with ordinary
   OK to confirm the setting still applies, then bypass it from Guide options.
   On a second Roku, verify that the setting remains off.
3. Tune an existing provider-declared audio-only station with the default
   off. Confirm sustained audible audio, correct station/program, no picture
   recovery or player restart just for absent video, and no promise of a
   picture after **Watch Video**. Repeat with existing M3U/Xtream fixtures if
   authorized; otherwise record those providers as not tested.
4. Enter from a scrolled/filtered guide. Test Back and **Stop and return to
   guide** with the physical remote. Hold OK on a known Radio Mode tune and
   release; confirm that the gesture tunes but does not also choose **Watch
   Video**. Open **Channels** and **Recently Watched** from Player options,
   then close each without tuning; confirm that station information and the
   radio controls return. Confirm Stop and Back stop audio and restore the
   original guide row/time, and a configured sleep timer stops playback from
   Radio Mode. From Radio Mode, select another station that waits for
   mandatory AAC; Back must stop the current station and cancel the pending
   tune, with no delayed audio restart.
5. Use an approved bursty/unavailable fixture. Check Buffering → Playing,
   the bounded retries when recovery fails, and eventual **Channel
   unavailable**. Verify that the failure dialog's Back/Return releases the
   tune with no auto-replay, while **Retry channel** explicitly starts a new
   attempt. Verify Home/exit does not provide a supported continuation path
   and record any screensaver/TV-power observations as device-specific.
