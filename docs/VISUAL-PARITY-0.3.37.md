# Roku / Apple TV / Android TV visual comparison

Tracking: `AerioTV-Roku-faa.12`. Roku baseline: **v0.3.37**, commit `4e9c9e1`.
This is a source-based comparison, not a claim of a new three-device screenshot
comparison. No UI changes were made as part of this audit.

## Sources and scope

Both upstream repository HEADs were checked and matched the existing pinned
revisions:

- [Apple TV source](https://github.com/jonzey231/AerioTV/tree/8d5818456e0f4421d93b8ff120ad878d63331091)
  — `8d5818456e0f4421d93b8ff120ad878d63331091`.
- [Android TV source](https://github.com/jonzey231/AerioTV-Android/tree/7bf4a2ddad9dd6d58152eee5b4eee08873c1da3b)
  — `7bf4a2ddad9dd6d58152eee5b4eee08873c1da3b`.

The references below use the TV-specific branches/components, not Android phone
bottom navigation or iOS-only presentation. Apple top navigation uses native
SwiftUI TabView, so its exact rendered appearance also depends on tvOS. Android's
TV implementation explicitly models the Apple TV appearance.

## Main finding

Roku has the basic Aerio navy/cyan palette, but not its shared TV control styling.
`source/SceneUi.brs:1–7` implements `uiRect` as a plain SceneGraph Rectangle. Top
navigation, group navigation, transport buttons and most cards build on that
primitive. Calling a navigation mode "pills" does not currently change its shape.

The upstream design has several distinct component families:

| Family | Shape and states to match |
| --- | --- |
| Primary navigation | Capsule focus background; Android TV uses white/dark ink when focused, accent/on-accent when selected but unfocused, transparent otherwise. |
| Group/category/season choices | Capsule with accent fill when selected. Focus adds a white ring to selected choices, an accent ring to unselected choices. |
| Small actions | Circles for search, sort, filter, refresh and manage groups. White focus background/dark glyph, quiet translucent rest state. |
| Settings rows/dialog cards | Rounded rectangles, not capsules everywhere. |
| VOD artwork | Portrait posters with modest rounded corners; rectangular content composition. |
| Guide program cells | Intentionally square, flat cells, with a white focus outline. |

## Detailed differences

### Primary tabs and library tabs — highest visual priority

**Upstream:** Apple `Features/Home/HomeView.swift:6258+` uses TabView with icon/text
tab items; `TVNavCircleButtonStyle` at 4242–4260 defines the adjacent round actions.
Android `feature/main/MainScaffold.kt:2159–2237` implements `TvTab` with CircleShape
(a capsule on a wide control), icon + semibold label, 1.04 focus scale, and 150 ms
color/scale transitions. Focus is white/black; selection is accent/on-primary.

**Roku:** `components/TopNavigation.brs:14–20,39–50` uses fixed 200x50 rectangular
backgrounds, text-only labels, cyan focus fill and a 176x3 selected underline.
The same component is reused for VOD subnavigation. This is a directly confirmed
source-level difference in shape, state treatment and composition.

**Recommendation:** replace rectangular tab chrome with a reusable pill component,
add suitable licensed icons, distinguish selected from focused, and size/pad labels
coherently. Preserve the accepted selection and key-routing behavior; adopting a
new visual style does not require switching tabs on focus.

### Guide groups and VOD filters

**Upstream:** Apple `Features/LiveTV/ChannelListView.swift:4903–4949` defines
`TVGroupPill` / `TVGroupPillButtonStyle`: capsule, 26-point horizontal / 13-point
vertical padding, 22-point medium text, 3-point white-or-accent focus ring,
1.05 focus scale and 150 ms transition. `Features/VOD/MoviesView.swift:4263–4277`
uses the same pattern in `MoviesPillStyle`.

Android `ui/tv/TvChrome.kt:48–137` deliberately mirrors this through `TvPill`:
13/6 dp padding, 11 sp text, 2 dp ring and 1.05 focus scale. `TvActionCircle`
at 140–199 supplies the distinct round icon-only controls. `feature/movies/tv/
TvMediaTab.kt:220–223` uses these pills for provider filtering.

**Roku:** `components/GroupNavigator.brs:27–48,69–83` draws 235x40 rectangular
group cells in Pills mode and 280x94 cells in Sidebar mode. Selected and focused
states change color, without a capsule/ring/scale treatment. VOD category/filter
workflows largely reuse grids and option lists rather than the upstream toolbar.

**Recommendation:** implement true group pills first; keep sidebar rows as a
separate rounded-row style. Apply the shared choice style to VOD filters where
those controls are present. Do not change category/provider filtering semantics.

### Guide program grid — preserve square geometry

Apple `Features/LiveTV/EPGGuideView.swift:7785–7807` explicitly says "flat rectangle,
no rounded corners" and applies a white 20% brightening wash plus a 4-point white
inset focus outline. Android `feature/livetv/grid/GuideGrid.kt:994–1016` uses
`CornerRadius.Zero`, white brightening and a 2 dp white outline.

Roku `components/GuideView.brs:531–582` already has square cells, but the focus
border is cyan with a dark teal fill, rather than the upstream white cue. Its
cell contains title and time/badges; upstream also has richer text arrangements
and density/layout variations.

**Recommendation:** retain square cells and bounded/reused nodes; match focus
contrast first. Treat density, descriptions and preview layouts as a separate
`faa.5` pass rather than rolling them into the pill conversion.

### Player controls and options

Apple `App/PlayerView.swift:4531–4620` uses capsule option controls with a shared
shape-following focus style. Android `feature/player/PlayerChromeOverlay.kt:911–958`
documents a center-anchored action-pill row, while `PlayerControlCircle` at
984+ defines the modern 30 dp transport circle: frosted 14% white at rest,
white/dark glyph on focus, with the focused caption below. Its player uses a mix
of action capsules and icon circles, not a row of identical square text buttons.

Roku `components/PlayerControls.brs:6–12,26–35` builds six 150x66 rectangular
buttons with nested rectangular borders/fills and text labels. This clearly
differs from the upstream pill treatment.

**Recommendation:** use compact circles for icon-only transport and capsules for
labeled actions, preserving the current actions and physical input contract.
Follow with compact rounded options panels. Keep fullscreen star Roku-owned;
the styling work must not reopen that already-resolved platform behavior.

### VOD library composition

Apple `Features/VOD/MoviesView.swift:2864–2910` uses 2:3 poster artwork with
8-point rounded corners. Android `feature/movies/tv/TvMediaPage.kt:2125–2165`
uses a poster card with 2:3 artwork, 4 dp corners and an accent focus border/scale.

Roku `components/VodView.brs:33–48` renders a 5x4 grid of 336x170 horizontal tiles,
each with a 104x154 poster and text alongside. The artwork proportion is close,
but the overall card composition is not the upstream poster-led library.

**Recommendation:** a later poster-grid pass with titles below artwork, shared
focus treatment and optional richer feature areas. Keep catalog loading bounded
and preserve the accepted enabled-category and playback behavior.

### Settings and typography

Apple `Features/Settings/TVSettingsSplitView.swift` uses a rail/detail structure.
Its rail row style at 280–305 has 14-point corners, an accent wash/outline,
persistent selection state, 1.02 scale and a 150 ms transition. Android shares
the TV type/layout ladder via `ui/settings/TvSettingsMetrics.kt:23–84`: titles
15 sp, row titles 12 sp, secondary text 10 sp, and a 48 dp title-safe inset.

Roku `components/SettingsHub.xml:17–21` uses one full-width LabelList with a large
heading and explanatory note. `source/SceneUi.brs:10–22` changes system font size
per call rather than applying a shared semantic type ladder. Thus matching color
alone cannot make the hierarchy and spacing look equivalent.

**Recommendation:** first centralize title/body/secondary/button styles while
preserving the resolved Roku system-font behavior. Then build a rail/detail
settings layout and rounded rows as a distinct change.

### Colors and motion

Apple `Design/ThemeManager.swift:29–75` defines the Aerio accent `#1AC4D8`, app
background `#0A1628`, and card background `#0D1E35`. These exact core colors
already recur throughout Roku. The problem is mostly component geometry,
hierarchy, state styling and composition, not an incorrect base brand palette.
Upstream has shared theme/appearance controls; Roku mostly repeats fixed colors.

Focus in the inspected Roku navigation/transport components changes colors
immediately; it does not implement upstream's subtle 150 ms scale transitions.
Use a common small animation treatment for controls, but keep the EPG grid flat.

## Roku implementation order

1. **faa.2:** shared color/type/state tokens and reusable primary pills, choice
   pills, circles and rounded panels. Use reusable image-backed capsule/corner
   assets with bounded node/texture use; validate the chosen rendering technique
   on Roku rather than assuming SwiftUI/Compose corner APIs exist.
2. **faa.2 / faa.6:** apply to TopNavigation, GroupNavigator Pills mode, VOD
   subnavigation and PlayerControls. Preserve focus ownership and accepted mappings.
3. **faa.6 / faa.5:** white guide-cell focus cue, rounded options/details chrome,
   then guide layout/density and poster-led VOD presentation.
4. **faa.2 / faa.4:** consistent typography, safe areas and larger-text reflow;
   settings rail/detail presentation. Theme presets remain under faa.3.
5. **faa.11 / faa.8:** annotated screen captures, physical focus/readability checks
   and explicit spoken-feedback verification. Record selected-unfocused,
   focused-selected, focused-unselected, disabled and pressed states separately.

Do not multiply Android dp values blindly: upstream intentionally uses roughly
half the tvOS point values on its assumed 1080p TV canvas. Roku uses a 1920x1080
scene, but actual font metrics, density, safe areas and rendering must be checked
on the target display. This report does not establish pixel-perfect parity or
verify native blur/shadow performance.

## Key upstream source links

- [Apple group pills](https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/LiveTV/ChannelListView.swift#L4926)
- [Apple VOD pills](https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/VOD/MoviesView.swift#L4263)
- [Apple primary navigation/actions](https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Home/HomeView.swift#L4242)
- [Android shared TV controls](https://github.com/jonzey231/AerioTV-Android/blob/7bf4a2ddad9dd6d58152eee5b4eee08873c1da3b/app/src/main/java/com/aeriotv/android/ui/tv/TvChrome.kt#L48)
- [Android primary tabs](https://github.com/jonzey231/AerioTV-Android/blob/7bf4a2ddad9dd6d58152eee5b4eee08873c1da3b/app/src/main/java/com/aeriotv/android/feature/main/MainScaffold.kt#L2159)
