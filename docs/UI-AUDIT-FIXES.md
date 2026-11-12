# Confirmed UI audit fixes

Scope: `AerioTV-Roku-iut`, `mrr.2`, `mrr.3`, `tk5`, `tm8`.
This implementation follows the findings in `UI-REAUDIT.md` and
`UI-LIBRARY-AUDIT.md`; those documents remain the before-fix evidence.

## Production changes

- Shared native-font labels keep symmetric full-height bounds and receive a
  font-scaled optical correction when the string has no lowercase descenders.
  Text/font observers reapply it when a control changes. Informational rows
  explicitly release this behavior.
- Primary navigation centers the text itself, not the icon/text combination.
  Leading icons retain a symmetric trailing gutter. Compact library tabs omit
  icons so full tab names remain readable at large sizes.
- Common pill heights use one nine-patch texture, stretching only its center.
  Height-specific antialiased masks retain circular end caps without separate
  Poster/Rectangle joins. Geometry with unsplit semicircle caps remains the
  fallback for other heights/circles. Generator and PNG-border regressions
  cover the packaged 20–128px even-height masks.
  Hidden fallback Posters have explicit 1x1 bounds: zero dimensions mean
  natural image size on Roku, and native Button layout measures even invisible
  descendants. This prevents their intrinsic 128x256 bounds inflating dialogs.
- Channel-browser group choices and search navigation actions use rounded,
  centered controls. Search results/channel cards remain content rows. Search
  footer uses the shared remote hints.
- Compact VOD category/provider/source selectors use full pill radii and
  centered multiline labels. Long names may ellipsize within the control;
  they must not escape it. Shorter Providers/Sources headings and bounded
  heading widths avoid library-tab collisions.
- Scene background and DVR static colors participate in appearance repainting.
  Guide subtitle color maps to secondary ink. Browser translucent surfaces use
  mapped, sufficiently opaque backgrounds. Native DVR captions use a transparent
  documented `captionBackgroundBitmapUri`, rather than the fixed gray bitmap.
- Guide clears programme subtitle/layout before the empty-channel early return.

No provider/account flow, media operation, recording command, permission rule,
or saved preference is changed by these fixes. Native keyboard styling remains
as accepted by the owner.

## Verification and limitations

Two native preflights exposed additional cap-edge and light-mode issues; their
captures are diagnostic evidence, **not** final acceptance:
`out/ui-reaudit/fixes-preflight/` and `fixes-preflight2/`.
The second preflight confirmed readable light guide subtitle/DVR captions and
contained large category labels, but still showed small sidebar cap tabs.
An inset center overlap was then tried in the full `fixes` run. Early full-size
inspection still found a cap tab: sampled Poster edges and Rectangle edges did
not coincide reliably under focus scaling. That run is not final pill-shape
acceptance. The next revision uses a single nine-patch texture for common pill
heights, avoiding that mixed-node boundary entirely.

The intermediate `out/ui-reaudit/fixes/` run completed 146 starting cases,
409 captures and 493 observations with no runtime/forbidden-operation or
navigation assertion failure. Probe SHA256:
`8cf6a3c849f1a966358f74403fb9eddbc10625e449d543fedcc84ab1375df83e`.
It is **not** final pill-edge approval, for the reason above.

Ten bounded text-only measurements from that run are in
`out/ui-reaudit/fixes/ink-bounds.json`. The final run reproduces these values in
`out/ui-reaudit/verified-fixes/ink-bounds.json`, using
`swift scripts/ui-audit-ink-bounds.swift scripts/ui-audit-fixed-ink-regions.json`.
All Channels/Favorites vertical offsets improved from about -2.5px to 0/+0.5px;
Live TV text-only horizontal offset improved from +16.5px to +0.5px. Live menu,
OK hint, confirmation and Settings examples measured between -1 and +0.5px
vertically. Text-only horizontal bounds were within 1.5px in these samples.
These are explicit bounded samples, not a universal typography assertion.

## Final rendered acceptance

`out/ui-reaudit/verified-fixes/` completed **146 starting cases, 409 captures,
493 native observations** with no runtime/forbidden-operation or navigation
assertion failure. All 409 captures were actually inspected across all 69
contact sheets, with full-size reinspection of guide navigation/sidebar
normal/large/light, empty-group transition, search actions, browser groups,
Providers/Sources headings, large category labels, light DVR captions and
duplicate confirmation. Pill joins/tabs and the temporary native-dialog
inflation are no longer visible. All confirmed audit defects are addressed in
these isolated production renderers; no remaining visual defect was identified
in this final matrix. Long names still intentionally wrap/ellipsize inside
bounded controls. Native keyboard appearance remains system-owned.

Final probe SHA256:
`2143033c935ff079b3f2d4e9be3d9619c787b95f9f19cfa3ed811b8c7a006aaf`.
The exact probe is `out/ui-fixes-bounded-probe.zip`; it is not an owner app or
shipping artifact. Diagnostic preflights are retained, not passed off as final
acceptance. Native runner restored developer ZIP SHA256
`91f8b8b1f3c2f45e625588e198b8f0a66af963ea285d49e1a27483461afb8734`.

Final gates: `npm test` (including 12 Python checks), `npm run check`,
`npm run build`, package tests (11), tools tests (6), fixture isolation and
`node scripts/verify-package.mjs` pass. Shipping-layout verifier accepts the
normal app ZIP with 279 entries and rejects the isolated fixture ZIP.

Local normal developer build: `out/aeriotv-roku.zip`, version `0.3.100`, SHA256
`61333fe4b57bd1f16aeaf5ee4e12a1062be2e9469b847db0b4c85bd1233d1c2b`.
It includes the owner's existing local version/cache/mapping edits and is not a
signed Beta/Store candidate. The previous developer app, not this build, remains
installed after validation.

## Remaining integration limitation

Confirmed defect tasks `iut`, `mrr.2`, `mrr.3`, `tk5`, `tm8` are closed on the
evidence above. Owner-authenticated/video-backed acceptance remains open as
`AerioTV-Roku-dgt`; the broader VOD/DVR/profile epic is not closed by this work.

The fixture ZIP uses real production renderers with synthetic, disconnected
data and read-only Task substitutes. It does not establish authenticated guide
integration or video-backed live-overlay acceptance. The installed developer
app requires session-only Xtream sign-in; no credentials were entered or
extracted. No real settings, playback, or recording mutations are performed.
The native runner restores the checksum-pinned prior developer ZIP afterward.

The build uses the owner's current uncommitted version/cache/mapping work;
those files are not part of this UI commit. No signed Beta/Store package is
produced by this work.
