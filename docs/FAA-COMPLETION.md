# Visual epic completion work

## faa.2 — shared styling foundation

All app-built rectangles, rounded surfaces and labels now register their original
palette role. Dynamic state changes (navigation, guide, browser, VOD, settings,
options/search/details) use the same color resolver. XML-built settings/detail
surfaces, notifications and mini-player chrome are registered explicitly.
Repainting walks existing nodes in place; it does not recreate Video or change
its ContentNode. Native black video backgrounds and semantic EPG flag colors
remain independent of the theme. The earlier shared typography/state/shape helpers
and generated assets are retained.

Unit tests cover palette substitution, retained alpha, focus ink separation and
semantic-color preservation. Tests, compiler and package inspection pass; a normal
native install and 15-second error-filtered launch observation succeeded.
Final screenshot/physical acceptance is tracked separately by faa.11.

## faa.3 — themes and colors

Appearance now offers AerioTV, Midnight, Sunset, Forest, Lavender, Monochrome and
Neutral presets using the upstream palette family, explicit Dark/Light, a validated
six-digit custom accent (empty restores the preset), Translucent/Solid panels and
confirmed reset. Roku has no defined system light/dark contract here, so no fake
System option is offered. Solid/translucent is a color-opacity approximation, not
native blur. Saved choices are device-scoped and use the existing rollback path.

Palette tests exercise every preset/mode, >=4.5 contrast for main text and selected
accent ink, invalid-value migration, custom colors and semantic EPG colors.
Native in-memory light-Lavender Settings capture succeeded (`out/faa-light.jpg`)
without changing saved preferences or Video content. Final physical appearance
and custom-accent keyboard acceptance remain in the final worksheet.
