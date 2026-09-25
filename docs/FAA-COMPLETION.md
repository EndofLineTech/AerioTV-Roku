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

## faa.4 — text/subtext and contrast

Device preferences now expose 90/100/110/120% primary and independent secondary
text scaling, plus Standard/High contrast. Original font faces/sizes are retained
as metadata so changes never compound. Text is bounded by its available line box;
compact badges may cap growth to stay inside their control. Navigation/hint strips
remeasure their text, settings lists retain safe clipping, and VOD large-text mode
trades some artwork height for two-line title space. High contrast raises secondary
ink and makes themed surfaces solid. Native/system keyboard styling stays native.

Unit tests cover scaling/migration/clamping and contrast. A native 120% primary +
120% secondary/high-contrast Settings capture (`out/faa-large.jpg`) was inspected:
controls and footer stay in their safe areas. Living-room and spoken-feedback
acceptance remain in the final physical worksheet.

## faa.7 / faa.9 — onboarding and numbered headings

The attributed Roku launcher/splash assets remain in the manifest at their
verified FHD/HD/SD sizes (see `images/README.md` and
`docs/DEVICE-VALIDATION.md`). A first-run empty connection roster now opens a
single remote-readable welcome page; OK or Back enters the existing setup form.
An existing saved roster, including a session-only connection, bypasses welcome;
an unreadable/newer roster still shows the recovery setup message. No onboarding
state is written to the registry and automatic remembered-key connection is
unchanged. The ConnectionStore model test covers those entry gates and the full
`npm run verify` passes.

On the target 3820RW2 / OS 15.3.4 a disposable visual probe displayed the
welcome page; a Developer Mode capture was inspected privately under ignored
`out/` and showed legible 1080p copy and an unobstructed Continue button. The
normal 0.3.80 ZIP was then reinstalled, and the disposable ZIP removed. This
probe did not reset the real connection, demonstrate the *actual* first-run
branch, or verify physical remote/Audio Guide behavior. An ECP Select attempt
timed out, so no native OK-to-setup claim is made. First-run remote, warm sign-in,
and perceived delay remain for the PO on the delivered build (`faa.7`).

The shared `channelHeading` helper removes an exact delimited number prefix;
the existing model tests distinguish channel 24 from 240, 24Kitchen/24 Hours,
decimal numbers and missing numbers. The observed provider-number heading is
still pending a genuine native playback/physical check (`faa.9`). No synthetic
model test substitutes for that screen observation.

## Audio Guide platform investigation — zvi / faa.8

Roku's current [roAudioGuide reference](https://developer.roku.com/dev/docs/roaudioguide)
and [ifAudioGuide reference](https://developer.roku.com/dev/docs/ifaudioguide)
explicitly list older 3600X/3700X/3710X/4620X/4630X/4640X devices and Roku TVs
as supported. The target 3820RW2 Streaming Stick 4K is not on that list. The
documented `Say(text, flushSpeech, dontRepeat)` signature matches the current
`uiAnnounce` call, but its returned ID does not establish audible speech. The
owner previously heard system-menu speech but no custom guide speech on the
target (`docs/OVERNIGHT-EVIDENCE-0.3.50.md`). The public compatibility list
could be incomplete; it is a platform-support warning, not proof of a device
fault. No replacement speech API or spoken-label PASS is claimed.

**Product Owner decision, 2026-09-25:** Absent custom AerioTV speech on this
3820RW2 is an accepted platform limitation for the current Roku scope. This
does not change the earlier observed silence into a PASS or establish the
cause conclusively. `zvi` is closed as an accepted limitation; `faa.8` remains
open for final-build physical verification of visual focus, readable selected
content/actions, menus, loading/errors and large-text behavior. Do not present
the app as providing verified spoken navigation on this target.
