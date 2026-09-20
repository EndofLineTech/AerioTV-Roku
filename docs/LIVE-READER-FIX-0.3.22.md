# Live reader correction — 0.3.22

Bug: `AerioTV-Roku-nyh`. The PO reported channel 426 failing from the live guide
while another TV was playing it. Console captured two `-5` failures with
`buffer:search:demux.mp4:MP4: no playable tracks`.

The live descriptor incorrectly used Dispatcharr's output name `mpegts` as Roku's
ContentNode streamFormat enum. Native assignment verification on the Streaming
Stick 4K showed `mpegts` stored as `NONE`, whereas `ts` stored as `ts`. The old
unit assertion incorrectly endorsed the invalid value.

The fix uses `streamFormat: "ts"`. The Dispatcharr request remains
`/proxy/ts/stream/<uuid>?output_format=mpegts`; existing audio/profile selection
and local cleanup remain in effect. No shared-channel stop was issued.

## Verification

- Regression assertion failed with the old hint, then passed with `ts`.
- Temporary native fixture used the production `startPlayback` controller for
  channel 426. Actual saved audio preference was `auto`, with no explicit output
  profile selected. Native format was `ts`.
- After ten playing samples, position advanced to 8.658 seconds; native formats
  were `mpeg4_10b` (H.264) and `aac_adts`.
- PO confirmed immediately afterward: "Whatever you ddi fixed it."
- The fixture stopped only this Roku's playback. Other-TV continuity was not
  independently measured; the user's original report supplied its playing state.
- Fixture retained in `tests/native/LiveReaderProbe.brs`; its production hooks
  are removed before installing the normal 0.3.22 build.

Continue the catch-up/Go Live worksheet in `RETEST-0.3.21.txt` using 0.3.22 and
record that actual build in its header. Channel 426 live playback is the additional
regression to check, including audible sound and ongoing playback on the other TV.
