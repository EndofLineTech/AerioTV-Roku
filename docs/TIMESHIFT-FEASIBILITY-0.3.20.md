# Restart and rewind feasibility checkpoint — 0.3.20

Work on34y.6/.9 and the Go Live portion of34y.12. This is a measured checkpoint,
not approval of universal restart or an hour-long retained buffer.

## Native setup

2026-09-20 UTC; Streaming Stick4K3820RW2 / OS15.3.4; Dispatcharr0.31.0.
The temporary fixture selected an authorized ESPN-matching channel with positive
advertised catch-up retention and a **currently airing program obtained from the
loaded guide**, not an arbitrary historical timestamp. Only one fixture media
reader was active at a time. Status polling was read-only; no shared channel/source
setting was changed.

The feasibility live reader used the explicitly accepted native `ts` reader hint.
That experiment did not change the production live playback configuration.

## Native live pause observation

| Sample | State | Position seconds | Pause range start/end | App memory |
| --- | --- | --- | --- | --- |
| Initial playback | playing | 0.033 | 0 / 0 | 10% |
| After1 second paused | paused | 0.033 | 0 / 0 | 12% |
| After30 seconds paused | paused | 0.033 | 0 / 0 | 20% |
| After60 seconds paused | paused | 0.033 | 0 / 0 | 21% |

Native duration remained -1; `pauseBufferOverflow` remained false in the captured
pause samples. The proxy client baseline was confirmed empty. The first run's
output was truncated; final resume, available-memory and client-cleanup figures
must be recaptured before they are used as acceptance evidence.

This establishes a short pause/resume observation only. It does not prove a usable
seek range, content alignment over an hour, overflow behavior after long pauses,
or60-minute retention. No other viewer was established in this fixture. Those
limits remain explicit in34y.9; a false `overflow` flag is not a retention guarantee.

## Currently airing archive windows

The fully captured targeted restart-only run observed program age907seconds and
2693seconds remaining:
- Original-start session: POST201, `playing`, echoed start matched, DELETE204.
- Separate near-live sample: start at request time minus120seconds, duration hint
  two minutes; POST201, `playing`, DELETE204.
- Peak sampled app memory14%; no live-proxy clients remained after this run.

These are positive samples on one channel/current-program context. They do not
establish every provider, very-recent program starts, physical content alignment,
or continuous playback all the way to the moving live edge. The near-live sample
was a separate window, not proof that the original-start stream automatically
followed the broadcast indefinitely.34y.6 therefore remains in progress.

## Decision proposal — not yet enabled

For34y.7, the viable candidate is **provider-backed, conditional Restart Program**:
only advertised catch-up channels; original guide UTC program start; an explicit
request to the existing session API; clear unavailable/lagging-archive errors;
one local reader; explicit Go Live. No extra service/container. This still needs
the PO's accepted availability/lag contract and physical content validation.

For34y.10, native pause is not an accepted60-minute architecture. A provider-backed
delayed window could be investigated separately, but would be limited by archive
availability/lag and would not be a device-retained buffer. The implementation
and recent-channel retention stories remain gated; no guarantee is substituted.

## Delivered Go Live action

Completed-archive playback now exposes **Up → Archive controls → Go Live**. It
validates the original account and current authorized lineup, closes the local
archive reader, revokes its owned session, and tunes that same live channel using
normal live preferences. It does not expose this action for movies/episodes.

Production-controller native verification repeated accepted archive forward/back
window replacement, preserved pause, opened the two-button controls dialog and
selected Go Live. Result: live `playing`, same channel UUID, archive session
released, DELETE204. The fixture then stopped its local live playback.

Model tests cover matching account/channel and rejected changed/removed identities.
The broader configurable timeline/scrub work in34y.12 is still unfinished.

## Reproduction / cleanup

Fixtures: `tests/native/TimeshiftProbe.brs`, `TimeshiftProbeTask.*`, and the updated
`ArchiveSeekProbe.brs`. Copy/import hooks are temporary only. The restart-only
manifest flag skips repeating the pause test. All hooks/flags are removed from the
normal app; the normal development package is restored after testing.
