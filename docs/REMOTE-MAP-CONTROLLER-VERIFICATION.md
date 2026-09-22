# Remote-map controller verification

Issue: `AerioTV-Roku-b17.6.3`. Repairs after v0.3.36, committed as `2684900` and
included in v0.3.37. The published v0.3.36 artifact does not contain these repairs.

## Repairs

- All four Player directions use the same action dispatcher. Channel actions on
  Left/Right support held selection and deferred tuning; non-channel actions on
  Up/Down execute rather than being discarded.
- Guide Left short actions execute on release for every mapping, so Left hold is
  independently usable. A completed hold consumes native repeats and release
  without executing the short action, including when the hold action is None.
- Player Hold OK=None keeps the key latched until release; native repeated presses
  cannot retrigger short OK after the hold threshold.
- Guide Open groups uses the visible group picker in Modal layout and the group
  navigator in Pills/Sidebar. Primary navigation remains reachable through Up at
  the top of the guide.
- Displayed hints use compact labels from the effective map, including disabled
  OK/hold gestures and mini-player Play. Fixed Back and info-panel control hints
  describe their contextual behavior.
- Saving or resetting the remote map republishes device preferences to Guide and
  player-info components immediately. Failed saves restore and republish the prior
  effective map.
- Home is not consumed by the Video, Scene, or Guide input handlers. Fullscreen
  Options remains Roku-owned; Back keeps contextual recovery behavior.

## Controller coverage

`PlayerRemoteInput.test.brs` exercises each offered action for all four directions,
Replay, Rewind, and Play/Pause using the production dispatcher and action spies.
`PlayerOkHold.test.brs` covers every offered short/hold OK combination, native
repeats, release guards, and overlay cancellation. Short OK remains immediate;
if it opens Options, that overlay owns subsequent input.

`GuideRemoteInput.test.brs` exercises every offered Guide action and all Left
short/hold combinations, paging bounds, no-mini behavior, overlay cancellation,
Modal/Pills/Sidebar group routing, and effective-map hints.

`PlayerLifecycle.test.brs` also routes custom Left channel switching and Up info
through the actual Scene handler, checking hold/release, Back recovery, and
content preservation. Existing `GuideInput` and `VideoInput` tests cover guide
navigation/picker wake guards and native Video forwarding/system-key boundaries.
`SettingsModel.test.brs` exercises production remote-map persistence publication,
failed-save rollback, and reset.

`npm run verify` passed: unit suites, package/tool tests, compiler, build, and ZIP
inspection. `git diff --check` passed.

## Physical acceptance

After installation of the local development build, the user reported testing
complete and updated `PHYSICAL-TESTING-CURRENT.txt`: **RM01–RM10 all PASS**.
This replaces the earlier missing-menu/skip results from a non-qualifying build.
Together with the controller tests, this supplies the remote-map acceptance for
`b17.6.3`, `b17.6.4`, and `b17.6`.

The installed ZIP was `out/aeriotv-roku.zip`, with SHA-256
`47caf72eae1e3a8db3c88de1bb5a72ee8f1f018cea81d713ba354ceb4f9a5ff7`.
Installation and ECP launch verification identified it as **0.3.36 local
development build**, distinct from the published v0.3.36 release.

The worksheet's per-action detail, optional second-account, date, and measurement
fields remain blank; no additional observations are inferred from those blanks.
Existing B01–B03, S01–S06, and Q01–Q04 PASS marks were preserved, not newly supplied
by this remote-map update. The new update-notification story `b17.11` remains open.
