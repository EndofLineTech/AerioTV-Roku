# DVR UI controller evidence — development 0.3.58

## Native guide and scheduling check

The normal `0.3.58` package passed `npm run verify`, installed through Developer
Mode, and ECP active-app reported `0.3.58`. A native guide ProgramDetails
screen exposed `Record on server` for a future program on the permitted account.
Saved padding (0/0 minutes in the native picker inspected) or per-recording
0/5/10/15/30-minute choices led to a separate confirmation before any POST.
The 5-minute early and 10-minute late selections appeared together in the
confirmation. Selecting its default **Cancel** returned to the exact guide
program. No UI schedule was submitted.

With explicit authorization, one disposable future program was then selected
with saved 0/0 padding. Scheduled was empty beforehand. After one UI confirmation,
the library showed exactly one new schedule with the selected channel, title and
start time. Roku Home exited the app; ECP launched `0.3.58` again, and Scheduled
still showed that same future item. Its detail showed matching UTC start/end and
server status `scheduled`. The guarded `Cancel future schedule` confirmation
removed that item and showed server confirmation; Scheduled returned to zero.
A second app exit/relaunch and fresh library load still showed zero scheduled
items. The one disposable UI schedule is removed; existing completed recordings
were not modified. Earlier `0.3.57` and isolated API probe evidence remain
separate. The Task preflights duplicates and guards repeated submission in code;
an actual repeated-OK server test and ambiguity/failure path were not exercised.

The DVR library exposes Now, Scheduled and Recent shelves, status refresh,
search, facts, and guarded cancel/stop/delete/commercial-processing actions.
Normal `0.3.58` showed empty Scheduled and one external completed item in Recent;
its facts dialog displayed status and guarded processing/delete choices. The
dialog's default Close returned to the library and Back returned to the guide.
Cancellation of the single newly created future schedule was device checked;
stop/delete/commercial-processing confirmations, processing output and recording
playback are not device accepted. No existing server recording was stopped,
deleted or processed.

The `0.3.58` change adds controller regressions for stale guide scope/account,
DVR capability downgrade from manage to view, revocation, stale mutation
confirmation after account change, and dialog dismissal on config changes.
Capability refresh now updates the active DVR's permission; config changes
cancel/dismiss in-flight UI operations before refreshing the library. The
controller tests do not exercise an actual permission downgrade on the server;
physical picture/sound and spoken labels remain separate acceptance
checks in `docs/MORNING-EPIC-ACCEPTANCE.txt`. Screenshots remain ignored in `out/`.
