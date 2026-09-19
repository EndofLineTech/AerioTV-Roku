# Guide screen — 0.2 working specification

Reference: AerioTV's tvOS preview layout at the commit in PORT-PLAN.md.
Design space: 1920×1080. This is a source-based interpretation pending TV review.

```text
┌───────────────────────────────────────────────────────────────────┐
│ AerioTV             Live TV            Group · channel count · time│
│                                                                   │
│ Focused program title                                             │
│ Channel · program times · synopsis                                 │
│                                                                   │
│ Date           12:00          12:30          13:00         13:30    │
│ Channel/logo │ Program ───────────── │ Next program ────────────── │
│ Channel/logo │ Program ───── │ Focused program ─────── │ Next ──── │
│ … seven rows, reused as the user scrolls …                          │
│                                                                   │
│ OK Watch/Details    * Options/groups/search/date    Back Connection  │
└───────────────────────────────────────────────────────────────────┘
```

- 240-pixel channel rail; 96-pixel rows; 600 pixels per hour.
- Grid width 1,488 pixels, showing approximately 2.48 hours.
- Horizontal movement selects adjacent program intervals; missing-data intervals
  remain selectable. Vertical movement preserves the selected UTC instant.
- Now remains anchored to the clock until horizontal browsing/date navigation.
- Groups, channel search, date/time selection and refresh are in the `*` menu.
  Long menus use a scrolling LabelList, not an off-screen stack of dialog buttons.
- Date selection enumerates actual half-hour instants and then groups them by
  local calendar date. DST repeated times include a UTC reference; missing hours
  are not invented.
- Current program: OK tunes. Past/future: OK opens details. The details action is
  explicitly “Watch channel live” until archive playback is implemented.
- Back dismisses menus/details first. Back from the guide opens connection
  settings. Back from playback restores the guide's channel/time focus.
- Favorite state, group and last selected channel persist per last-connected
  account. Search text and historical time are session-local.
- Missing guide, loading, stale data and request failure are distinct states.
  Failed metadata loading never disables channel tuning.
- Returning to the guide does not require recreating its scene rows or refetching
  all channels. Account changes replace data and cancel the old guide task.
- During fullscreen playback, unhandled Up/Down steps through the active filtered
  lineup. A 250 ms timer combines rapid presses; pending candidates don't move
  guide focus until a tune is committed. Back cancels pending tuning. First/last
  boundaries remain on the same channel and show a boundary hint.

## Known fidelity gaps

Rectangular cards, Roku system fonts, and standard details/keyboard dialogs remain
provisional. No running Apple TV comparison has been
performed. The first TV review should address density, truncation, safe areas,
color/focus contrast, navigation speed and missing logo treatment.

## Fullscreen information overlay — 0.2.6

- Bottom panel at `[96, 684]`, size `1728×328`, deep-navy translucent background
  and cyan accent edge. Channel/logo above current title, times and synopsis;
  upcoming title/times in a separate right column.
- Schedule progress is a wall-clock fraction of the current on-air program, with
  remaining broadcast minutes. Paused playback is labeled PAUSED; the schedule
  still follows the broadcast clock rather than the frame/playhead.
- Appears on tune, buffering and pause. Auto-hides after eight seconds of normal
  playback. OK toggles it independently of playback. Back returns to the guide.
- The Scene owns playback key focus. Video's native transport UI is disabled;
  otherwise it consumes OK as pause. `*` opens the app's audio/caption menu.
- Menus consume navigation so choosing a track cannot switch channels. Closing
  a menu restores player-controller focus. Back from a menu closes it first.
- Metadata updates never reopen a hidden overlay or change key focus. A result
  for a different channel cannot replace the current or pending channel preview.
- Current/next guide windows refresh using the existing three-window cache.
  Long programs can request a third window containing their end. Historical
  guide browsing windows are not mistaken for “Up next.”
- Logo load dimensions are bounded before assigning URI in both guide and player.
