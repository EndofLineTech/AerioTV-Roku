# Video dimensions and aspect research

Investigated 2026-09-18/19 for ihp.10 and ihp.11. All references below were
retrieved, not inferred from search snippets alone.

## Sources and findings

- [Roku Video reference](https://developer.roku.com/dev/docs/video): native codec,
  bitrate and decoder statistics are available. Video node width/height describe
  the play window, not necessarily the encoded video dimensions.
- [Roku developer discussion: source video resolution](https://forum.developer.roku.com/t/how-to-get-stream-video-resolution/7164)
  (2017): distinguishes the Video window from source dimensions and recommends
  supplying server-side ffmpeg/mediainfo metadata. Historical guidance, not proof
  of every current OS capability; our current-device probes independently found
  empty resolution/videoTrack and tracks=[] for both tested TS and local MP4.
- [Roku developer discussion: stretching 4:3](https://forum.developer.roku.com/t/how-to-stretch-a-4-3-video-to-full-screen-16-9/5037)
  (2016–2022): discusses automatic aspect preservation; does not establish a
  working SceneGraph stretch API. Poster.loadDisplayMode is not a Video API.
- [Roku Group reference](https://developer.roku.com/dev/docs/group): specifies
  scale, translation and clippingRect. These are the APIs exercised by the native
  geometry fixture, rather than invented videoDisplayMode/scaleMode fields.
- [Dispatcharr v0.31.0 channel status](https://github.com/Dispatcharr/Dispatcharr/blob/v0.31.0/apps/proxy/live_proxy/channel_status.py):
  get_detailed_channel_info exposes resolution, source_fps, pixel_format,
  video_codec, audio_codec and bitrate fields when metadata is populated.
  GET /proxy/ts/status/<uuid> is admin-only in the
  [view](https://github.com/Dispatcharr/Dispatcharr/blob/v0.31.0/apps/proxy/live_proxy/views.py).
- [Dispatcharr v0.31.0 stream serializer](https://github.com/Dispatcharr/Dispatcharr/blob/v0.31.0/apps/channels/serializers.py):
  stream_stats and stream_stats_updated_at also expose cached source metadata.

## Implementation

0.2.11 adds a read-only status Task to Stream Info. Server facts are explicitly
separated from native decoder facts. This reads existing server metadata rather
than opening another media connection. Missing/forbidden metadata remains
Unavailable; HTTP errors are displayed, and callbacks are cancelled on retune.

Source resolution alone is not sufficient to automatically choose display
aspect: display aspect = width / height × sample (pixel) aspect. In particular,
720×480 does not establish either 4:3 or 16:9. The inspected live status contract
does not expose SAR/DAR, so resolution is not silently used to crop the picture.
Upstream metadata may also differ from a transcoded output profile.

The scaling preview stores Fit/Fill/Stretch as a device preference and an explicit
source-aspect override per account/channel (4:3, 16:9, 21:9; bounded to 100).
Unconfigured channels fall back to native Fit. Overrides describe the entire
encoded frame including embedded black bars; they are not black-bar detection.
Fullscreen and mini-player share one geometry function and clipping viewport.

## Native fixture evidence

tests/native is a separate, developer-only package; fixtures do not ship with the
normal app. A local 640×480 H.264/AAC test pattern played from pkg:/ with error=0.
Scene bounds changed from 800×450 to 800×600 at y=125 for uniform Fill, then
800×450 for horizontal Stretch, then 464×261 at [1360,24] for mini-player. Native
playback stayed playing throughout. A screenshot confirmed the Fill drawing
region was clipped to the requested 800×450 viewport even while node bounds were
800×600. The screenshot omits actual video pixels; perceptual cropping/distortion
and a 16:9/letterboxed matrix still require final visual acceptance.

Reproduce with ffmpeg installed:

```sh
ffmpeg -hide_banner -loglevel error -y -f lavfi -i 'testsrc2=size=640x480:rate=30' -f lavfi -i 'sine=frequency=440:sample_rate=48000' -t 4 -c:v libx264 -pix_fmt yuv420p -preset veryfast -crf 28 -c:a aac -b:a 96k -movflags +faststart tests/native/fixtures/4by3.mp4
npx bsc --project tests/native/bsconfig.json
```

Sideload out/native-checks.zip, capture the [scale-probe] console lines and
screenshots during its eight-second phases, then reinstall out/aeriotv-roku.zip.
The fixture stops playback automatically; it never connects to a provider.
