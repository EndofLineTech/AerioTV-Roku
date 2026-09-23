# Four-epic overnight evidence — development 0.3.50

Target: Streaming Stick 4K `3820RW2`, Roku OS `15.3.4`, 1080p, existing
Dispatcharr `0.31.0`. Normal development `0.3.50` passed `npm run verify`, was
installed after all temporary probes, and ECP `/query/active-app` reported
`0.3.50`. Device screenshots stay in ignored `out/` and are not public test
proof of sound or decoder-plane video. This note contains no credential, URL,
real media label or screenshot.

## Visual/accessibility (faa)

- Native `0.3.40` initially paused in the debugger on an AerioSurface float vs
  vector2d comparison. The corrected focus animation was installed; group/top
  navigation, Settings and Basic/Preview round trips succeeded; the owner
  confirmed the physical remote responded again. `AerioTV-Roku-idr` closed.
- Basic showed ten compact rows, Preview seven. Toggling logos Off hid them;
  Preview and logos On were restored. Other visibility controls/long-text cases
  need the morning physical worksheet.
- `channelHeading` now strips only an exact delimited channel-number prefix.
  Boundary tests include decimal numbers, longer numbers and genuine titles.
  Native player-heading sample verification remains open under `faa.9`.
- With the system reader enabled and app Audio Guide On, the owner reported
  **no guide speech** in two physical listening checks. Diagnostic build
  `0.3.42` confirmed app preference/global gate true and that `roAudioGuide.Say`
  was invoked; build `0.3.45` recorded an integer speech ID of 0. Neither
  proves audible speech. `zvi` remains open. Do not mark F05 PASS from logs.
- Lowercase/camel-case duplicate Settings keys were migrated and new writes
  use canonical field names (`zma`); after relaunch native global preference
  matched the displayed choice. This did not resolve spoken feedback.
- The app's Audio Guide preference was restored to **Off** in Settings and
  confirmed in a native capture. The owner enabled Roku's system screen reader
  for the earlier test; its current OS setting was not remotely verified or
  changed after that test. Restore it with the physical remote if desired.

## On demand (l4j)

Normal `0.3.50` opened a populated saved Movies search, selected a poster,
rendered English TMDB detail/cast/attribution and visible source/link actions,
then returned to the same focused poster and back to the guide. Existing
provider6 HTTP 405, missing-synopsis completeness, other library flows,
episode playback and physical acceptance were not repaired or retested here.

## Server DVR (a59)

Isolated native `0.3.46` used the existing account to create one disposable
future schedule, GET-verified its channel/program identity, cancelled only that
new future recording, and GET-verified its removal. Earlier no-write probes
caught a Roku `roInt` EPG epoch type mismatch. See `docs/DVR-CLIENT-0.3.40.md`.
The client is still not wired into guide/player UI, and server ownership after
app exit plus the DVR library/rules/playback remain open.

## Multiview (wt1)

Isolated `0.3.47`–`0.3.49` two-Video trials: first live MPEG-TS Video played,
second returned native code -5 concurrently, even for the same source; alone
the second source could play. Both were stopped/removed. One application-memory
sample was about 78.6 MB; peak texture and real picture/audio weren't measured.
See `docs/MULTIVIEW-FEASIBILITY-0.3.47-49.md`. Per the PO's conditional
decision, do not advertise multiview without a useful supported two-session
result; capacity/provenance measurements and the final deferral decision stay
open. The normal app was restored after probes.

## Morning handoff

Use `docs/MORNING-EPIC-ACCEPTANCE.txt` to mark only physically observed
PASS/FAIL/SKIP results on the exact installed build. The four epics remain
open/in progress where their child acceptance and Product Owner review are
still pending. A green package/install does not close them.
