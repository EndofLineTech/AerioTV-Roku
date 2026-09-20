# Rewind architecture — measured decision

Decision34y.10, approved by the PO on2026-09-20: **Provider-backed rewind** on
catch-up channels, up to60minutes since tuning, with explicit unavailable errors
and Go Live. This replaces a universal/device-retained-hour promise. No extra
runtime service/container is introduced.

## Native hour experiment

Streaming Stick4K3820RW2 / OS15.3.4, Dispatcharr0.31.0, channel3.3. Isolated Video
used the production live TS descriptor, without forcing an alternate audio profile.
The guard was60% app-memory usage or3800seconds; neither stopped the run early.

| Point | Wall seconds | Native position | App memory | Available KB |
| --- | --- | --- | --- | --- |
| First playing | 9 | 0.350 | 3% | 289348 |
| 30 minutes | 1800 | 1790.640 | 18% | 275928 |
| 60 minutes | 3600 | 3589.450 | 19% | 272192 |
| Before rewind | 3619 | 3608.470 | 19% | 271308 |
| 15 seconds after seek | 3634 | 3629.410 | 18% | 279720 |

Requested native seek target **8.471seconds** (3600seconds back). Playback instead
continued near3600seconds. **The one-hour rewind did not happen.** Duration stayed
-1, pause-buffer bounds0/0 and overflowfalse. Zero bounds/false overflow alone are
not proof; the failed seek after the full run is the decisive result. Pause/resume
is separately measured in `RESTART-POSITION-0.3.26.md`.

Read-only proxy status: confirmed0 clients before; after local Stop and10seconds,
confirmed0 clients and0 missing baseline clients. No other viewer was established
in this fixture. No shared-channel stop or server configuration change was made.
Fixture: `tests/native/RewindSoakProbe.brs`; full redacted local log was captured
in ignored `out/rewind-soak.log`.

## Existing deployment / storage comparison

- Dispatcharrv0.31.0 `apps/proxy/live_proxy/views.py::stream_ts` selects MPEG-TS or
  fMP4 output and a profile; it exposes no per-client historical timestamp/byte-range
  seek into its live buffer. Its generator is opened without a request seek offset.
- Internal Redis buffer positioning exists in `input/buffer.py`, but is not a
  native-client rewind API. Changing global new-client delay would affect others
  and is not a per-viewer timeline.
- Roku documents `cachefs:` as RAM-backed on devices without extended storage and
  evictable at any time; `tmp:` increases app memory. One hour at even1Mbps is450MB
  before overhead, compared with roughly271-289MB available in this run. This is
  not a basis for a guaranteed arbitrary-channel local spool.
- `GetVolumeInfo` is only meaningful for external volumes; internal values cannot
  be presented as measured writable capacity. USB access is read-only in the
  documented app filesystem. No guessed flash capacity is used as a guarantee.

Sources:
- https://github.com/Dispatcharr/Dispatcharr/blob/v0.31.0/apps/proxy/live_proxy/views.py
- https://github.com/Dispatcharr/Dispatcharr/blob/v0.31.0/apps/proxy/live_proxy/input/buffer.py
- https://developer.roku.com/dev/docs/file-system
- https://developer.roku.com/dev/docs/iffilesystem
- https://developer.roku.com/dev/docs/video

## Approved implementation boundary

Use the existing catch-up session API and one local media reader. New seek requests
are bounded to the later of tune time and now minus60minutes, and never beyond
already-broadcast time. Whole-minute provider timestamps are used. Advertised
retention/account permission gates entry; archive lag, provider gaps or capacity
can still make a request unavailable. There is no silent live substitution.

No local media spool or extra concurrent channel ingest is introduced. Go Live
closes the owned archive reader/session and restores the same authorized channel.
Rewind resource usage follows the already measured sequential archive-session
path, rather than growing with the duration of viewing. Retained recent-channel
ingests require a separate scope decision and are not implied by this approval.
