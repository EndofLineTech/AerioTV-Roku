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

Full native post-fix verification is running in `out/ui-reaudit/fixes/`.
Do not infer visual approval from successful capture/navigation alone.

The fixture ZIP uses real production renderers with synthetic, disconnected
data and read-only Task substitutes. It does not establish authenticated guide
integration or video-backed live-overlay acceptance. The installed developer
app requires session-only Xtream sign-in; no credentials were entered or
extracted. No real settings, playback, or recording mutations are performed.
The native runner restores the checksum-pinned prior developer ZIP afterward.

The build uses the owner's current uncommitted version/cache/mapping work;
those files are not part of this UI commit. No signed Beta/Store package is
produced by this work.
