# In-progress recording controls — AerioTV-Roku-0i3

PO report: an active server DVR recording used Roku's native “Rewind live TV”
overlay while Live TV used Aerio's player information panel and action pills.
The existing native availability-window seek had been tested on the target;
replacing its UI required proving app-controlled seeking, not simply hiding
the native overlay.

## Adaptation

Growing HLS recording playback now uses the **same `PlayerControls` component**
and pill focus styling as Live TV, configured with Play/Pause, Rewind 30s,
Forward 30s and Back to DVR actions. Its information/timeline panel uses the
same colors and spacing as Live TV. FF/REW remote keys from the idle player
open an in-app seek preview: a tap commits one step, a hold previews multiple
steps, OK/Play commits and Back cancels. When the controls have focus, the
Rewind/Forward pills or FF/REW keys seek one step immediately. The app sets
`Video.seek` only for a known numeric
position and duration, clamped to 0 through six seconds before the current
growing end. When the range cannot be measured or playback is buffering, it
shows a message rather than guessing a seek. Back/Stop exits only this viewer;
it does not stop the Dispatcharr recording. Completed-file playback retains
its proven native timeline. Catch-up's separate provider-seek controller is
unchanged.

## Evidence — 2026-09-26

- Model/controller coverage in `npm run verify` checks initial bounds, missing
  duration, edge clamping, short tap and held preview/commit/cancel, paused
  control routing and keeping completed recording input on the native path.
- On the 3820RW2 / Roku OS 15.3.4, a synthetic local HLS playlist without
  `#EXT-X-ENDLIST` allowed `Video.seek` with its native UI disabled: a request
  after position **40.234 s** resumed near **8.533 s**. A probe using the actual
  `OnDemandPlayer` displayed the shared Aerio control pills. Its Rewind action
  requested 0 s from 26.635 s and playback returned to `playing` near 18.058 s
  (the native reader chose the available position); Forward requested 89 s
  from 59.343 s and playback resumed near 86–90 s. The synthetic HLS server
  was private to this test, not a Dispatcharr profile. A synthetic completed
  MP4 run still reported `nativeUI=true`, displayed the native FF overlay and
  exited with Back. Private screenshots stay ignored under `out/`.
- A single **PO-approved disposable** Dispatcharr recording was created by an
  isolated one-shot hook after DVR manage permission and identity checks. Its
  numeric ID was verified before playback and cleanup. The normal, non-probe
  client selected the real growing HLS, showed Aerio's controls and reached native
  `playing`. A 30-second Rewind requested a bounded seek to **104 s** and the
  reader returned through `buffering` to `playing`. A later Forward attempt
  near the scheduled recording's end coincided with native error **-3**,
  `reader pick stream error:bad:mpr playlist file is too large`; the recording
  subsequently became completed. This **does not prove** whether Forward or
  the growing-to-completed playlist transition caused the error. Follow-up
  `AerioTV-Roku-4vb` tracks that distinct reader problem. The identity-checked
  disposable recording was deleted with confirmation: DVR returned to **Now
  0 / Scheduled 0 / Recent 1**, the same counts as before the test.
- The changed normal app's Live TV control row was checked on an authorized
  channel; its six original actions still rendered with the same pill styling
  and the short playback was stopped from that row. Developer screenshots omit
  video pixels, so neither the live nor DVR observations assert physical
  picture/sound continuity after a seek.

The synthetic fixtures are built from `scripts/build-growing-controls-probe.py`
using a credential-free local HTTP URL. `tests/native/RecordingControlsFixture.brs`
is an opt-in, one-shot server fixture hook and is **not** part of the ordinary
application. Its builder requires a specific approval flag, and its package
must not be launched a second time before the ordinary app is restored. Use it
only with owner approval and confirmed cleanup of the resulting ID. Rollback:
reinstall the prior v0.3.81 ZIP to restore Roku's native growing-recording UI.
The verified release ZIP was reinstalled after these checks.
