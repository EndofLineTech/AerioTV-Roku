# Aerio TV visual refresh - 0.3.38 development build

The first implementation pass from `VISUAL-PARITY-0.3.37.md` is delivered on `dev`.
It is a development candidate, not a published GitHub release or full visual epic
acceptance. Public v0.3.37 remains the last release.

## Completed implementation beads

| Bead | Delivery | Commit |
| --- | --- | --- |
| faa.13 | Shared palette/type/state helpers; reusable antialiased rounded/capsule surfaces and asset generator | 011238b |
| faa.14 | Primary and library capsules, group pills/rounded sidebar, original icons and focus growth | 0d68353 |
| faa.15 | Circular player controls, rounded panels/options/actions, square guide cells with white focus | 5fc5970 |
| faa.16 | Bounded portrait-poster library, two visible rows from a 20-item page; compact category/version cards | 1daebc7 |
| faa.17 | Settings rail/detail layout, row states, shared typography, preserved choice/persistence logic | 4c7f698 |
| faa.18 | Integrated checks, native captures, final typography/focus refinements, development version and physical worksheet | See Git history |

## Verification

- `npm run verify`: unit/controller suites, package/tool tests, compiler, build and
  ZIP inspection pass. Beads sync wrapper tests also pass.
- Native installation and launcher verification on the configured Streaming Stick
  4K succeeded. Scripted settings, VOD and Pills-view captures completed without
  captured compiler/runtime errors.
- ECP screenshot returns HTTP 404. Authenticated Developer Mode capture works;
  `capture-roku-screenshot.py --developer-mode` was added without changing Roku
  remote-control policy.
- Actual native images were inspected locally: capsules and white primary focus,
  rounded sidebar/settings, poster artwork/title hierarchy, and square guide cells.
  Captures revealed oversized default list text and duplicate guide/top-navigation
  focus; both were corrected and recaptured.
- The capture fixture changes screens without physical key injection. Its temporary
  Pills layout is in-memory only; the normal application ZIP is restored afterward.

Final normal ZIP: `out/aeriotv-roku.zip`, **156 files**, SHA-256
`1130c0c7003cc938e80c34edf5ea7beb790bee6ca059b4d56b2c3ed2ed395833`.
After restoring this exact ZIP, installation succeeded and ECP active-app reported
**0.3.38**. A 15-second filtered native-console observation captured no runtime
errors. This is short scripted evidence, not an endurance run.

Local captures (ignored by Git; review/redact before sharing):

- `out/visual-0.3.38.jpg` — initial normal guide/sidebar.
- `out/visual-pills-0.3.38.jpg` — focused primary capsule and group pills, with
  the inactive grid focus outline removed.
- `out/visual-vod-0.3.38.jpg` — populated poster-led library.
- `out/visual-settings-0.3.38.jpg` — rounded settings rail/detail and corrected type.

## Boundaries and next physical check

Use **VISUAL-TESTING-0.3.38.txt**. Earlier accepted remote-map and settings results
remain historical; changed visuals/navigation need the new checks. Screenshots
and programmatic screen selection do not prove physical remote behavior, spoken
feedback, audiovisual continuity, animation smoothness or sustained resource use.

`faa.11` remains open for annotated physical comparison/PO visual acceptance,
`faa.8` for Audio Guide, and `05e` for measured final-build resource profiling.
Theme presets, global text-size preferences, richer Basic/Preview guide modes and
full upstream feature parity remain existing separate roadmap items; this pass
provides the shared visual foundation and the reviewed navigation/library/settings
changes. No automatic updater or new unsupported playback action was added.
