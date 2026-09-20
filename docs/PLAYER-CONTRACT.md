# Roku Live TV interaction contract

Decision: `AerioTV-Roku-ihp.1`. The direction/default and Back/minimize ladder
were accepted by the Product Owner on 2026-09-18. Additional bindings below are
the implementation contract to verify during device acceptance.

0.3.11 decision: after fullscreen tap/hold-star experiments failed, the PO
approved moving away from fullscreen star. Hold OK is the replacement shortcut;
the old star-interception criteria are superseded, not declared fixed.

- Default player direction matches Apple TV: **Up = next, Down = previous**.
  The choice is a persisted device preference so settings can expose an alternate
  guide-order mapping. Existing installs without a stored choice adopt the new
  explicitly approved default; it is announced in the release notes/hints.
- Channel surfing stays in the guide filter used for entry. A channel selected
  from the player browser may have an overlay-local group; that local browser
  filter does not silently rewrite the guide's group.
- Bare fullscreen: Left opens Channels; Right toggles the last channel; Replay
  opens Recently Watched. Held Up/Down repeats are coalesced before tuning.
- Tap OK shows/hides information immediately. Hold OK for about one second in
  fullscreen playback or information view opens player options, including while
  paused. Repeats do not toggle information repeatedly; the opening hold/release
  cannot activate an item in the newly opened menu. Another action or lifecycle
  transition cancels a pending hold. Menu/browser/transport OK keeps its normal
  selection behavior. Up or Down from explicitly summoned information enters
  the focusable transport row; Left/Right then move between controls and OK
  activates one. Up returns to the information panel. Auto tune-in information
  does not capture channel-surfing keys.
- Explicit information remains open until dismissed; only automatic tune-in
  information expires. The custom Video owns bare-playback focus and forwards
  keys to the Scene; hidden-picture mode uses a separate input Group. Fullscreen
  star is left to Roku; no application shortcut/wake behavior is promised for it.
  Guide/mini-guide star remains app-owned where delivered. The mini-guide also
  exposes AerioTV player options.
- Back dismisses the innermost menu/browser group/list first. Back from explicit
  information/controls hides the chrome. Back from bare fullscreen minimizes the
  same Video session into the guide. Back from the mini-player guide expands it.
- Selecting the currently playing channel in the guide expands it without
  reconnecting, including preserving pause. Play/Pause in the mini-player guide
  expands it. A labeled Stop action exists in player and guide options/controls.
- No hold-Back or double-Back stop shortcut is introduced in this iteration.
  Repeated Back presses traverse the same visible ladder; Stop is unambiguous.
- Player submenu Back returns to its parent option; source-change confirmation
  returns to the source list. Back from the main options menu returns to playback.
- Hide picture is a foreground-only player option. The explanation fades after
  six seconds; the existing connection continues with video/captions suppressed.
  The selecting OK gesture is consumed through release before a new wake gesture.
  Play/Pause remains functional. The first arrow, OK, or Back restores the picture
  and is consumed, including repeats until release. Later Back follows the normal
  ladder. Stop, errors, retune and mini-player transitions remove the cover.
  Home still exits the app; no background playback or TV-off behavior is promised.
- Sleep timer follows the viewing session across channel changes and minimize/
  expand; explicit Stop, logout or process exit clears it. It is not a device
  power-off timer or a background service.
- Before first playback, a confirmed native buffering stall or a 25-second
  startup timeout permits one local retry with the exact content/profile. A
  second failure stops with an error; successful or paused playback ends the
  watchdog. This is not midstream recovery. Stop/retune/account teardown cancels
  the old watch, and sleep expiry takes priority over a startup retry.
- Always AAC/explicit AAC requests wait at most 20 seconds for a discovered
  existing profile before opening media. Optional channel facts do not delay
  profile publication. Discovery failure never silently starts direct playback;
  choosing Automatic or Direct is explicit, and Cancel preserves the setting.
  Back or guide options can cancel the pending tune. If another channel is already
  playing, it remains intact during discovery. Stop/retune/account changes cancel
  the wait; late callbacks cannot resurrect it. Startup timing begins afterward.
- Menus own their directional input; data refreshes never steal focus. All
  playback modes use a single Video node; unsupported seek/record/multiview
  features are not advertised as working controls.
- Guide Up/Down holds accelerate after 1.5 and 3 seconds and stop on release.
  In pills/sidebar modes, a 400ms Left hold enters groups from any channel row
  without changing time; a shorter tap moves backward in time on release.
  Down/OK returns from pills; Right/OK returns from sidebar. Layout selections
  apply to the current guide immediately, without requiring Home/relaunch.
  Star from focused pills/sidebar opens guide options without selecting a group.

## Source-based visual baseline (`AerioTV-Roku-faa.1`)

Upstream reference: `8d5818456e0f4421d93b8ff120ad878d63331091`.
Source evidence: `Design/ThemeManager.swift`, `Design/Typography.swift`,
`Features/LiveTV/EPGGuideView.swift`, `Features/Player/ChannelListOverlay.swift`,
`App/PlayerView.swift` and `Features/Multiview/PlaybackChromeOverlay.swift`.

| Surface | Evidence / baseline | Roku adaptation |
| --- | --- | --- |
| Setup | Published Apple TV screenshots: navy, cyan labels, large remote-readable inputs | Explicit filled Connect and separate Forget buttons, device-confirmed readable text |
| Guide | Source: 240-pixel rail, 96-pixel preview rows, 600 pixels/hour | Seven reusable rows in 1920×1080; menu-based groups pending the guide epic |
| Program details | Source: program identity, times, synopsis, later enriched artwork/facts | Existing text dialog; richer details remain the guide epic |
| Player info | Source: navy/glass/tinted chrome and program information | Existing bottom panel at 96,684 sized 1728×328 with current/next and schedule progress |
| Transport | Source: focusable Pause, Options and capability-sensitive actions | Supported controls above info; no fake seek/record/multiview actions |
| Channels/recents | Source: left-side list over video; nested local group selection | Bounded rows with logos/now-airing and a Watching badge; right side remains visible |
| Options | Source: compact floating focusable options | App-owned menus, required because native Video consumes OK |
| Mini-player | Source: corner video while browsing, sharing one playback session | Top-right 400×225 viewport; caption ends above the guide timeline |
| Settings | Source: categorized split view | Connection screen remains current; the full settings hub is a separate story |

Known facts: palette and source layout constants, plus existing Roku screenshots.
Source-derived assumptions: exact current Apple TV animation/timing/composition;
no running Apple TV is available. The source-based baseline is not proof of pixel
parity. Capture Roku setup/guide/details/player/options/mini views at 1080p,
compare geometry/readability/focus against this baseline, and replace assumptions
with current tvOS captures when available. Record intentional adaptations and
test long names, empty lists, overlays, boundaries and video continuity.
