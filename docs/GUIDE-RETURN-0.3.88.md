# Guide follows current time on return — GitHub #12

The reported behavior was a guide left at its pre-playback time after an hour
of viewing. The v0.3.88 GuideView re-entry handler restores the current time
when the viewer was following live time, but retains an explicitly selected
historical/future guide position. `tests/GuideSettingsModel.test.brs` covers a
one-hour elapsed interval in both modes.

## Native comparison (3820RW2 / Roku OS 15.3.4)

- On the committed v0.3.88 ZIP, a real authorized channel reported ECP `play`
  for two minutes. Back returned to the guide and its current-time marker and
  clock had advanced without pressing Replay. Private captures:
  `out/gh-12-normal-guide-before-tune.jpg`,
  `out/gh-12-real-playback-guide-return.jpg`, and
  `out/gh-12-normal-guide-after-stop.jpg`.
- An attempted real one-hour soak could not finish: after approximately 15
  minutes in `play`, Roku reported a malformed-stream demux error and stopped.
  This is a playback-source outcome, not a verified hour of uninterrupted A/V.
- A disposable read-only `guide-return-hour` probe placed the actual GuideView
  anchor one hour behind, toggled its `active` field through the real re-entry
  handler, and checked the selected programme against in-memory fictional EPG
  cells. When following now, the guide returned to within one second of current
  time and selected **Current fictional programme**. With intentional time
  travel, the anchor stayed **3600 seconds** behind and selected **Prior
  fictional programme**. The current programme was visible in private
  `out/gh-12-current-program-fixture.jpg`. No shared-server EPG mapping or
  programme data was changed. The verified normal versioned ZIP was reinstalled
  afterward and the authorized guide was restored.

This combination exercises the one-hour stale state on Roku and the actual
playback-to-guide navigation, but **does not claim** a continuous real-provider
hour, a mapped real programme *during that test*, or physical picture and sound.
The account did not have usable guide mappings at the time of this comparison.
The owner subsequently repaired them: an explicit guide refresh displayed
real current/next programmes and detail artwork, including after a separate
brief playback error returned to the guide. That later return is not a
substitute for an uninterrupted one-hour provider stream.
