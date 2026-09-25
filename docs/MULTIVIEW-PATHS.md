# Multiview beyond two SceneGraph Video nodes — research update

Current PO direction (2026-09-25): a **separate sidecar container on the
Dispatcharr host** will compose multiple authorized streams into one Roku
output. This supersedes the native-only choice discussed below; server-side
composition is now the chosen design direction, not a delivered feature.
See [MULTIVIEW-SIDECAR-SCOPE.md](MULTIVIEW-SIDECAR-SCOPE.md) and bead
`AerioTV-Roku-cba`. The comparisons that follow are historical evidence.

Engineering research for `AerioTV-Roku-7le`, requested after the measured
deferral in `AerioTV-Roku-wt1`. This historical comparison adds no server or
physical picture/sound acceptance; its former deferral decision is now
superseded by the PO's native-concurrency requirement below.
Target remains Streaming Stick 4K 3820RW2 / Roku OS 15.3.4, Dispatcharr 0.31.0.

**Scope and evidence correction:** The PO has now specified that the Roku must
open multiple concurrent streams itself. Server-composed and precomposed feeds
below are historical comparisons, **not implementation candidates**. Further
research found a [Roku Summit multidecode slide](https://miro.medium.com/v2/resize:fit:1600/1*9S4UeCGc76hf8_iQgFCJDg.png)
explicitly naming Logan hardware and a [Fubo device matrix](https://support.fubo.tv/hc/en-us/articles/30574847628045-How-does-Multiview-work-on-Roku)
listing 3820X2 for two simultaneous views. The native-focused evidence and
remaining SDK access gap are in [MULTIVIEW-NATIVE-RESEARCH.md](MULTIVIEW-NATIVE-RESEARCH.md).

## What the earlier failure proves

The [native trials](MULTIVIEW-FEASIBILITY-0.3.47-49.md) played one live MPEG-TS
Video, but the second returned `mediaplayer` internal code 16, **"only one playing
instance supported"**, even for the *same* working source; after cleanup it
played alone. That rules out simply shrinking two ordinary SceneGraph Video
nodes or lowering the second node's audio volume on this device/path. It does
not prove that every Roku architecture or precomposed feed is impossible.
Roku's published [Video node](https://developer.roku.com/dev/docs/video) describes
single-content playback and says only **one stream may prebuffer** in an app;
`prebuffer`, playlists, picture scaling and posters do not combine two *live*
moving pictures into one Video instance.

## How another TV service can display four views

YouTube TV's [engineering explanation](https://blog.youtube/news-and-events/multiview-on-youtube-tv/)
explicitly says processing/composition runs **on YouTube's servers** and the
viewer's device receives **one live feed**, rather than two or four. Its
[current viewer guide](https://support.google.com/youtubetv/answer/13418774?hl=en)
describes up to four views with audio/caption selection and fullscreen return.
The server-side explanation is primary-source evidence for **YouTube TV's**
architecture, not evidence that its private compositor is available to us or
that every competing Roku service uses the same technique. A one-feed mosaic
would pass Roku's single-player gate if the *composite encoding/transport* is
compatible; dynamic tile selection and per-tile audio/captions require a
separate authorized control or variant-stream mechanism. Cropping a one-feed
mosaic on the Roku can enlarge a tile, but cannot regain source resolution or
independently decode/audio-select a tile that the feed did not preserve.

## Native multi-decode: distinct from ordinary Video

A Roku Developer Summit slide announces **`roMultiDecode`** for hardware
decoding of concurrent streams on Brewster, Bailey, Logan and select TVs.
Fubo lists the Logan 3820X2 family for two views. A
[Roku developer forum discussion](https://forum.developer.roku.com/t/roku-multiview/11357)
mentions a *possible* beta/developer token and the failure of multiple plain
Video nodes even on an Ultra 4850X. Another
[forum reply](https://forum.developer.roku.com/t/getting-this-error-message-in-roku-video-only-one-playing-instance-supported/11362)
points to Roku's [2024 SceneGraph Summit session](https://developer.roku.com/videos/demos/summit-2024.md).
The token idea is **community speculation**, not a published entitlement rule.
The slide/device matrix establish a supported-model lead, not a public API
contract, sample app, or AerioTV hardware playback result. The public
[hardware table](https://developer.roku.com/dev/docs/hardware) lists the
3820X2 family at 1 GB RAM and 1080p UI/4K playback, but a maximum *single*
playback resolution and RAM size do not specify simultaneous decoder count.
The published [device feature list](https://developer.roku.com/dev/docs/ifdeviceinfo)
does not identify a documented multidecode feature flag. We have not found a
public `roMultiDecode` reference/API contract; do not hard-code guessed methods,
seek hidden entitlements, or repeat the failed two-Video test as if it tests
this separate path.

**Next gate:** obtain from Roku (through the legitimate developer program) a
supported API/sample, eligible models/firmware (explicitly including or
excluding 3820RW2), sideloading entitlement conditions, codec/transport/DRM
and audio/caption limits, and publication rules. Only if a supported path
includes our device should an isolated, bounded two-feed native probe be made.
Test 2×low-resolution same-source then distinct permitted feeds for 30–60 s,
single-audio ownership, moving picture/sound, focus, resource peaks, server
client counts, and cleanup; restore the normal package afterward. Neither a
`HasFeature` guess nor a successful `CreateObject` alone proves usefulness.

## Existing Dispatcharr versus a composite feed

Dispatcharr's [channel documentation](https://dispatcharr.github.io/Dispatcharr-Docs/channels/)
calls multiple *streams on one channel* an ordered **failover list**: it starts
the first and switches on failure, not a simultaneous video grid. Its
[output profiles](https://dispatcharr.github.io/Dispatcharr-Docs/) transcode
one selected stream (such as audio/format adaptation), and the
[FFmpeg profile examples](https://dispatcharr.github.io/Dispatcharr-Docs/hardware-acceleration/)
read one `{streamUrl}`. The public [v0.31.0 release](https://github.com/Dispatcharr/Dispatcharr/releases/tag/v0.31.0)
describes output-profile and proxy changes but does not document a multi-input
live-mosaic endpoint. These documents do not prove the absence of every
possible plugin/custom profile, nor have we verified the live server's Swagger
for a compositor. No available multi-input composite feed is established for
the current account. **Changing a stream profile to run FFmpeg with multiple
inputs would be server configuration/new compute work**, not a Roku-only UI
fix; custom commands would also have to preserve account permissions and avoid
forwarding credentials across providers. Do not mutate shared configuration to
manufacture a test. If a provider already offers an authorized precomposed
mosaic as a normal channel, Roku could play that *one* feed with the existing
player; its actual availability and audio/caption control are unverified.

## Historical alternatives (the native-only constraint was later superseded)

1. **No server changes:** check only authorized catalog metadata for a provider
   mosaic channel, if one exists; one-feed playback is feasible to probe on the
   current player. This is a fixed provider feed, not user-built Aerio multiview.
2. **Roku-native path:** obtain documented `roMultiDecode` access/eligible model
   details first; then probe on the Stick within permitted account and resource
   limits. A newer Ultra's product feature would not prove Stick compatibility.
3. **Server-side composition:** if the PO explicitly revises the no-new-runtime-
   service/server-change boundary, design a permission-scoped two-input pilot
   off the shared server, with bounded CPU/GPU/bitrate, clock alignment, audio
   ownership, session TTL, cleanup and per-account authorization. Evaluate a
   supported upstream mosaic capability first; otherwise this needs new
   composition compute. A 1080p canvas with two scaled inputs is a *candidate*
   profile, not a tested budget or deliverable. Check provider concurrency and
   rights before running. One composite MPEG-TS/HLS rendition would still need
   native picture/audio/remote testing on the target.

Do not substitute periodically refreshed thumbnails, sequential retuning, an
ordinary multi-item playlist, or a large set of buffered feeds for concurrent
live playback. Those approaches do not meet the multiview user story and can
exhaust memory, bandwidth or provider connections. The PO's later sidecar
decision supersedes the native-only direction; delivery requires a measured
host-side composition path and real Roku picture/audio acceptance.
