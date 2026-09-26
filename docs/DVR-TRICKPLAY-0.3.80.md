# Recording FF/REW — local 0.3.80 development build

Target: Roku Streaming Stick 4K `3820RW2`, Roku OS `15.3.4`, existing
Dispatcharr `0.31.0`. These changes are in a local development package, not
the published `0.3.80` release. Private device captures stay in ignored `out/`.

Dispatcharr's pinned recording pipeline uses FFmpeg HLS with a four-second
target segment time, `-hls_list_size 0` and `append_list+omit_endlist` flags.
This retains the playlist's segments as it grows rather than exposing only a
short sliding set. Its authenticated HLS endpoint serves that playlist and
segments; after completion the server serves the finalized file. Roku's Video
node documents `enableLiveAvailabilityWindow` for scrubbing an available live
window. The player now enables that field, native UI and native trick play for
growing Dispatcharr recordings and focuses the Video node, leaving catch-up's
separate archive controller unchanged. The previous implementation consumed
FF/REW on its Group without a seek action.

The full `npm run verify` suite passed. With explicit owner-approved disposable
scope, one isolated short recording was created and GET-identified by its new
server identity; the normal modified package was restored before it started.
The Roku showed its HLS reader reaching `playing`. FF and REW displayed the
native live-availability seek bar. At roughly three minutes into recording,
rewind reached the start of the available window (Roku displayed a rewind
limit around 3:27 behind live). Committing that position via Play produced
fresh `buffering` then `playing` states; forwarding moved the bar back toward
the live edge (about 2:07 and then 0:16 behind live). These are native UI and
decoder observations, not measured frame/audio fidelity. Back returned to the
DVR row. The test capture finished before a Stop request; the server correctly
refused Stop on the now-completed item. Only this new completed item was then
deleted with confirmation, and the DVR list returned to Now 0, Scheduled 0,
Recent 1 (the pre-existing item), Rules 0. A separate read-only completed-file
run still reached the MKV reader's native `playing` state and showed the native
FF timeline. The normal modified build remains installed.

Limits: The native overlay calls this window “Rewind live TV,” because the
recording HLS playlist is still growing. The available range depends on the
server playlist and reader; no universal retention, perfect frame alignment,
or seamless handoff at recording completion is claimed here. Roku Developer
Mode captures omit the Video pixels, so physical picture and audio after seeks
still need a viewer at the TV. Do not count native `playing` as that sign-off.
