# Growing DVR HLS completion handoff — AerioTV-Roku-4vb

## Evidence and competing explanations

The 2026-09-26 disposable-recording observation in
`docs/DVR-CONTROLS-0.3.81.md` was a five-minute recording. Rewind returned to
Roku `playing`; a subsequent Forward near the scheduled end coincided with
native `-3`, `reader pick stream error:bad:mpr playlist file is too large`.
No capture of the playlist or final request was retained. Neither the Forward
seek nor the completion transition is proven to be the immediate trigger.

Pinned Dispatcharr **v0.31.0** source explains a likely completion failure:

- [`apps/channels/tasks.py` lines 1629–1634](https://github.com/Dispatcharr/Dispatcharr/blob/v0.31.0/apps/channels/tasks.py#L1629-L1634)
  produces four-second HLS segments, keeps the entire list and omits ENDLIST.
- [`tasks.py` lines 2748–2808](https://github.com/Dispatcharr/Dispatcharr/blob/v0.31.0/apps/channels/tasks.py#L2748-L2808)
  switches *new* viewers to `/file/`, waits for the active HLS segment-viewer
  heartbeat to expire, then removes the HLS directory. Final `status` is saved
  afterward ([lines 2820–2847](https://github.com/Dispatcharr/Dispatcharr/blob/v0.31.0/apps/channels/tasks.py#L2820-L2847)).
- [`apps/channels/api_views.py` lines 3578–3588](https://github.com/Dispatcharr/Dispatcharr/blob/v0.31.0/apps/channels/api_views.py#L3578-L3588)
  redirects an old `index.m3u8` request to `/file/` when the HLS directory is
  gone and an MKV exists. The file route serves `video/x-matroska` bytes
  ([lines 3497–3554](https://github.com/Dispatcharr/Dispatcharr/blob/v0.31.0/apps/channels/api_views.py#L3497-L3554)).
  The upstream [playback authorization test](https://github.com/Dispatcharr/Dispatcharr/blob/v0.31.0/apps/channels/tests/test_recording_playback_auth.py#L195-L214)
  explicitly asserts this 302 and preserves its authentication token.
- [`api_views.py` lines 3599–3627](https://github.com/Dispatcharr/Dispatcharr/blob/v0.31.0/apps/channels/api_views.py#L3599-L3627)
  otherwise returns a rewritten M3U8 with HLS content type and refreshes the
  20-second viewer heartbeat only when serving `.ts` segments.

A credential-free calculation using 75 four-second segments (five minutes),
`seg_%05d.ts`, and an example absolute API URL produced **6,373 bytes** of
rewritten playlist text; 1,800 segments (two hours) produced **151,273 bytes**.
These are estimates, not measurements from the failed recording, but a short
playlist alone is a weak explanation for “playlist file is too large.” A Roku
HLS reader receiving the redirected MKV as its next playlist would have a
format mismatch and could report that parser error. Only a native request/
response comparison can establish whether that actually occurred.

## Candidate client recovery

After a growing recording's Video error, `OnDemandPlayer` emits the same
account/recording identity and its last **committed playing/paused** position.
The Scene performs a read-only `DvrRecordingTask` status request; it accepts a
result only for the current authorized account, playback identity and numeric
recording ID. If the fresh server status says `completed` or `stopped` and a
file is advertised, it opens the server-owned `/file/` route with the finite
MKV/MP4 reader and attempts resume at that last position. It does not follow
the old `.m3u8` redirect as HLS, infer file readiness from an error string,
seek the stopped/buffering playhead, or mutate the server recording. In-flight
checks are cancelled on viewer exit or account change. If the file is not yet
ready, the existing playback error remains visible; there is no unbounded
automatic reconnect or speculative switch to a placeholder file.

`tests/OnDemandPlayer.test.brs` covers error signal position/identity and
completed-file exclusion; `tests/DvrHandoff.test.brs` covers active/mismatched
server rows, completed-file route and resume, and stale-task cancellation.
`npm run verify` passes. This is **unit/build evidence**, not a claim that the
3820RW2 successfully completed a live-to-file transition.

The opt-in `scripts/dvr-hls-handoff-fixture.py` generates H.264/AAC four-second
HLS segments and a finite MKV locally, serves a playlist without ENDLIST,
then switches the original playlist URL to a 302 after a fixed interval from
its first request. It does not use a Dispatcharr account. Its HTTP contract
test verifies the unchanged playlist, segment, redirect and byte-range MKV
responses; a real 16-second FFmpeg generation smoke check produced four
segments and a 3.7 MB playable final file. The fixture is bound to the chosen
LAN address only during a native probe and cleans its temporary media on exit.

## Native synthetic comparison — 3820RW2 / OS 15.3.4

Using a 40-second, ten-segment fixture, the Roku repeatedly fetched a **701
byte** HLS playlist. After the fixture began redirecting that same URL to its
MKV at 24 seconds, playback reached **39.533/40 seconds** and remained in
`buffering`. This occurred both with the Aerio recording controls and in a
separate raw Video-node baseline with **native controls enabled**, neither
with a Forward press. The server logged repeated playlist-to-file redirects;
the client aborted MKV response bodies on the HLS URL. This comparison makes
the UI/Forward action unnecessary for this class of stall and disproves that
the synthetic 701-byte playlist was itself too large. It does **not** reproduce
the exact `-3` message from the earlier real recording or identify that
recording's last HTTP response.

In the Aerio fixture run, a sustained near-edge `buffering` state triggered a
single completion-check signal using the last playing/paused sample. The
test-only probe switched to its known finished `/file/` endpoint (there is no
Dispatcharr status endpoint in the fixture). Roku then reported finite MKV
`playing` at **36.021, 37.521 and 39.521/40 seconds** with `nativeUI=true`,
before reaching the end and closing. Production uses the authorized status
check above instead of the probe's hard-coded fixture handoff. Developer
screenshots do not establish physical picture/sound, and the real backend's
completion timing is still unverified for the recovery branch.

## One approved real-server comparison

The owner approved **one additional disposable recording**. Before scheduling,
the real DVR displayed Now 0 / Scheduled 0 / Recent 1. A one-shot hook checked
manage permission, created a three-minute recording, then verified its new
numeric ID and program/channel identity. The hook package was immediately
replaced by the normal app so it could not create another recording on relaunch.
The recording appeared as the only new active item. With Aerio's growing-HLS
controls, a Rewind requested second **23**, went through `buffering` and
returned to `playing`; Forward requested second **107**, likewise returned
through `buffering` to `playing`. After the scheduled end, native Video reported
`finished`, not `-3`, and returned to DVR. There was **no completion error or
near-edge buffering stall** in this run, so the production status-confirmed
handoff branch was not invoked. Its behavior on a real Dispatcharr transition
remains unproven; neither successful seek confirms physical A/V continuity.
The identity-matched newly created item alone was deleted through the app's
confirmation dialog; server confirmation and a refreshed DVR returned to
Now 0 / Scheduled 0 / Recent 1. Private screenshots remain in ignored `out/`.
The verified published v0.3.82 ZIP (SHA-256
`e49d771a1b4c83729cfee9be490dd85574b8da12ae7f4c26c626168975e764cd`)
was reinstalled afterward; ECP reported the developer slot at `0.3.82`.

## Remaining native comparison

An actual server failure/near-end stall is needed to exercise the production
status-confirmed recovery branch; the single newly authorized real recording
was consumed and cleaned up. Request separate approval before any further
server fixture. Confirm physical picture **and sound** after Rewind, Forward
and any completion handoff before accepting `0i3`. The synthetic native
comparison supports the redirect/reader-mismatch mechanism, but it does not
prove the exact `-3` in the earlier real run came from the redirect.
