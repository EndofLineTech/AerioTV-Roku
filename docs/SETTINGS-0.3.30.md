# Settings, preferences and bounded remote behavior — 0.3.30

Development increment for `b17`. It is not a public release. Existing Roku
controls remain unchanged except where a saved preference explicitly selects one
of the supported alternatives.

## Settings

Settings now exposes only bounded, implemented choices:

- Player Replay action: Recent (default) or provider rewind history.
- Guide Replay action: Jump to Now (default) or open Guide options.
- Startup behavior: Guide/no autoplay (default) or resume the last available
  channel in mini-player after native playback starts.
- Individual player-overlay controls: logo, channel, title, time/progress,
  description, next program and remote hints. Defaults are all visible.
- Network request timeout: 10, 20 (default), or 30 seconds. This may only
  reduce an individual Task's existing safe per-request ceiling; it never
  extends its total deadline or response-size limit.
- Active-session capability refresh: 2, 5 (default), or 10 minutes while the
  app is open. Roku has no background refresh after the channel closes.
- About, What's New and license notices. The settings view displays the package
  version, independent-port attribution, `LICENSE.md` and the Material icon
  attribution file. What's New can be marked read per account and re-opened.

Fixed escape behavior remains fixed: Back keeps its established role, fullscreen
`*` remains Roku-owned, and no setting changes a key into a focus trap. The
existing Channel Up/Down direction preference remains available.

## Persistence and failures

New device preferences are normalized to their defaults on missing, malformed or
unsupported values. Account startup and What's New state are separately scoped
to the authorized Dispatcharr account. The existing bounded preference store and
quota remain unchanged.

Settings writes now roll back the affected device, guide or account value when
the registry write/flush cannot complete. The active screen shows the existing
sanitized notice; it reveals no server URL, API key, password or token. This is
in addition to the already-existing generic persistence error path used by other
preference writes.

## Network behavior

`networkTimeoutMs` is published through the SceneGraph global state. Task-thread
HTTP reads apply it as a lower bound than their own established timeout; task
deadlines, retry limits, cancellation, byte limits and memory guards remain in
force. The selected cadence directly updates the active capability-refresh Timer.
It does not run while the application is closed and does not imply background
operation.

## Verification

Model tests cover defaults, malformed preferences and every new permitted
setting. Existing suite coverage still verifies registry quota/write/flush
failures and rollback safety. Run `npm test`, `npm run check`, and `npm run build`.

On the target Streaming Stick 4K (3820RW2, Roku OS 15.3.4), a temporary native
fixture exercised General settings, changed Guide Replay and request timeout,
opened About then license notices, rendered 183 packaged license/attribution
lines, restored saved preferences and completed. This is scripted device evidence,
not physical-remote acceptance. The fixture is retained only under
`tests/native/SettingsProbe.brs` and is excluded from the normal package.

Physical checks are in `PHYSICAL-SETTINGS-0.3.30.txt`. Device scripted checks and
model tests do not pre-fill physical results. `b17` remains in progress pending
that acceptance and final Product Owner review.
