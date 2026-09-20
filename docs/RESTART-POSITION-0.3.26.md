# Conditional Restart Program and archive clocks — 0.3.26

Continues `34y.6/.7/.8/.9/.12/.13`; the epic is not complete.

## Provider/device measurements, 2026-09-20

Streaming Stick 4K / OS15.3.4, Dispatcharr0.31.0. Each session was sequential,
with owner DELETE204 before the next session; no shared channel stop or provider
configuration change was used. Raw credentials/provider URLs were not exported.
Provider IDs below came from matching the owned session in the read-only catch-up
stats API; they are not inferred from channel names.

| Channel | Program age at selection | Remaining | Provider | Original-start native position after observation | Separate T-minus120s position |
| --- | --- | --- | --- | --- | --- |
| 3.3 | 556s | 1244s | 6 | 9.459s | 10.009s |
| 15.4 | 2491s | 1109s | 6 | 11.611s | 11.077s |
| 57.5 | 743s | 1057s | 22 | 10.196s | 9.793s |

All six sessions returned201 and reached native playing. Original-start responses
echoed the requested guide UTC start; all deletes returned204. Peak app memory
was20%,19%,16% respectively. Native duration remained -1. Channel15.4's audio
position stayed0 in the sample, so audible output needs physical verification.

The full pause run on3.3 is now captured: position1.151 before/through60seconds
paused, then11.161 ten seconds after resume. App memory6% initially,8% after the
pause,9% after resume; pauseBufferStart/End0/0 and overflowfalse throughout.
Proxy client count0 before,1 during pause,0 after local stop. This is a one-minute
observation, not an hour-long rewind guarantee or independent other-viewer proof.

A subsequent150-second near-live observation did not finish. Its original-start
session played, but own-session stats were not found at that sample. After the
near-live POST201, no completion/error was captured and query/active-app showed
Roku Home. Cause unknown; this run supplies no sustained-playback acceptance.

## Supported contract

The PO approved provider-backed Restart with **Archive not yet available** for
delayed/unavailable archives. The measured positive cases support a conditional
attempt, not universal provider availability or seamless progression to live.

- Current-program details offer **Restart Program (provider availability)** when
  account permission and advertised channel retention allow it.
- Launch rechecks current authorized lineup, permission, retention and time.
  Future/ended programs do not pass the current-program restart gate.
- Request the original UTC start and **full scheduled program length**. An initial
  elapsed-only-window implementation was revised before delivery to avoid asking
  the provider to truncate the request at the instant Restart was pressed.
- Reopen seeks are whole-minute offsets, bounded by program length and elapsed
  broadcast time. Seekability is a provider request window, not retained bytes.
- Missing/delayed/busy archives produce the agreed unavailable explanation;
  explicit authentication/rate/connection refusals retain their distinct errors.
- If the provider ends an ongoing archive early, keep an explicit end-of-window
  screen with Go Live/Return choices. Do not silently retune or reconnect forever.
- Existing one-reader/owner-session cleanup and Go Live behavior applies.

Full end-to-end playback of a growing archive, very-recent starts, perceptual
content alignment and provider-specific audio remain physical acceptance cases
for delivery. The150-second incomplete run does not establish a moving live edge.

## Position presentation

The archive/restart panel now shows native committed position plus reopened-window
offset, a progress bar against **guide length**, estimated broadcast date/time,
delay behind live and minute-granularity provider request bounds. Schedule length
is not advertised as a measured native duration. Broadcast time is explicitly an
estimate because providers may round window starts or return different content.

While paused, committed position/broadcast time remain fixed and delay behind live
grows. Buffering targets do not advance saved progress. If bytes run beyond the
listed program end, retain pinned identity and show **past listed end**, rather
than silently assigning the next guide program. Live/delayed rollover mapping,
configurable skips and held scrubbing remain unfinished stories.

## Verification

- Model checks: restart current/future/ended/denied cases; preserve original full
  scheduled duration; clamp seek against already-broadcast time; reopened offsets;
  pause clocks; unknown/negative positions; past-end progress; elapsed formatting.
- Actual player-controller regression: provider EOF stays explicit for Restart,
  unavailable503 text,403 does not masquerade as archive lag, existing VOD sticky
  failure behavior.
- Native production-controller fixture with a real current program: playing;
  new clock/delay labels present; forward60; backward0 preserving pause; Go Live
  same channel; owner DELETE204 for replacements/final release.
- Repeated the native sequence for completed-program archive playback as well.
- All42 suites and compiler checks pass. Normal package excludes fixture hooks.

Physical worksheet: `RETEST-0.3.26.txt`. Prior accepted worksheets are unchanged.
