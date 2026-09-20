# Archive controls, settings prerequisite and delayed information — 0.3.27

Implements the remaining transport-control work in34y.12 and clock presentation
in34y.13, plus its categorized-settings prerequisite b17.2. Physical results are
separate from scripted/controller evidence.

## Archive / Restart controls

- Tap Rew/FF: commit one configured skip when the button is released.
- Hold Rew/FF: move a timestamp/marker preview every450ms. Releasing a held button
  leaves the preview open. **OK/Play commits; Back cancels.** Previewing sends no
  provider request and does not pause or stop the current reader.
- Choices are1,2,5minutes, matching verified whole-minute provider windows.
  Configure through **Up → Skip interval** or **Settings → Player → Archive skip
  interval**. The setting is device-wide, normalized and persisted through the
  existing versioned preference store. Failed writes retain the existing warning.
- Commit revalidates the current session and bounds; one owner DELETE precedes
  replacement. Pause is preserved. Go Live remains explicit.
- A seek back to the current window's opening offset is now honored even if the
  offset equals the last opened offset; previously this was incorrectly ignored.
- VOD retains native transport controls. Ordinary live is not given a fictional
  seek range. These controls do not imply a60-minute retained live buffer.

## Categorized settings

Guide header **Settings** (also reachable through guide Options) opens Live TV,
Player, Appearance, General and Connection categories. Back restores category/row
focus, then the existing guide position. Connection opens the existing editor,
including its original Forget/reconnect flow.

Only existing supported settings are exposed. Archive skip is hidden without
catch-up permission; the account VOD toggle is hidden without either VOD capability.
Device/account fields remain separately scoped, and stale-account selections are
rejected. Audio mode is labelled next-tune; navigating settings does not retune.

## Delayed live information

For relative TS positions, anchor media seconds to wall time once at playback
start and label the result **estimated**. While paused, the broadcast-time estimate
stays fixed and delay grows; after resume, it advances with native media position.
Player information selects the program at that playhead, rather than substituting
the next on-air program at a schedule boundary. Available cached metadata is used;
missing historical metadata remains unavailable.

Freshness is checked against real wall time, separately from historical selection
time. A paused playhead cannot make expired cache entries look fresh. Native UTC
position epochs can supply direct time; relative estimates do not claim knowledge
of provider latency. Overflow or a clock discontinuity invalidates the estimate.
The UI then shows time/program identity unavailable until a fresh timing reference.

## Verification

44 suites cover preference normalization, actual scrub-handler commit/cancel and
stale-session suppression, allowed settings/capability changes, delayed-clock
rollover and actual PlayerInfo rendering, including unknown time and stale cache.
Native fixtures: `TimeshiftControlsProbe.brs` and `RewindSoakProbe.brs` under
`tests/native/`. Device control results and rewind architecture evidence are
recorded separately; none of these files is a physical-remote PASS.

The controls fixture passed all native checks: category Back/focus; device skip
write/reload; account VOD enable/disable gating; guide-setting application; held
preview without session mutation; cancel; same-opening-offset rewind; configured
tap skip and held commit preserving pause; same-channel Go Live; fixed paused live
clock with growing delay; resumed delayed clock; existing connection editor route.
It restored the original skip, VOD choice and watch history.

Native-only defects found and fixed: dynamic preference keys must be canonicalized
to lowercase before normalization; and `Int()` must not receive a large absolute
Unix epoch through a single-precision argument. Live clock conversion now uses an
integer UTC anchor plus a small elapsed delta, with small startup leads calibrated
instead of showing paused media ahead of wall time. Modern-epoch regressions added.
