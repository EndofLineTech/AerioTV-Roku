# Profile picker implementation boundary

`UserProfilePicker` is a private, compiled full-screen component, not yet
connected to application startup or a public top-bar action. It grants no
authentication, PIN, management, or credential authority.

`source/UserProfilePicker.brs` calculates ordered presentation from a validated
roster. Child, single-profile, other-provider and deep-link launch cases return
no tiles. Explicit Ask Off is preserved. Launch and switcher purposes distinguish
Back exit/close, current-holder PIN/close and Add/Manage intent. Creation's
default-on Ask choice and existing explicit-choice migration remain unfinished;
no stored choices were changed here.

The component displays initial/color avatar fallbacks, wrapped names, a native
shape lock badge, current caption in switcher mode and four-column focus.
Catalog avatar artwork, appearance/text-scale variants and parent admissions
remain unfinished. `UserProfilePickerInput.brs` defers short OK until release,
emits one hold intent and consumes that release, preventing an accidental switch
after reorder. Parent handlers must independently recheck node identity, lifecycle,
current roots, role, target PIN and own credentials before acting on any intent.

## Developer evidence

- Tests-first policy/input failures:
  `out/mrr-picker-model-red.log`, `out/mrr-picker-input-red.log`.
- Native shared model/store suite including the same policy/input tests:
  `out/mrr-picker-model-native.log`.
- Real ECP short Select → protected-current launch intent → switcher-current
  close → Left/held Select/release → reorder-only → Right/Select/current close
  → Back, all HTTP 200 and exactly five expected intents:
  `out/mrr-picker-ui-qualified-native.log` and
  `out/mrr-picker-ui-qualified-native.json`.
- Inspected native screenshot: `out/profile-picker-native.jpg`. Long name,
  current focus, initial/color fallback and lock badge fit.
- Full verification: `out/mrr-picker-qualified-verify.log`.

The UI fixture is isolated: no application initialization, registry or provider.
Every run checksum-matched the installed app before replacement and restored the
exact preceding app. The first run's Select delivery timeout remains preserved
in `out/mrr-picker-ui-first-native.json`; later passing delivery does not explain
or resolve `AerioTV-Roku-667m`.

The next integration must use a distinct startup-selection boundary with no
authenticated outgoing actor/key, not a fabricated chosen-switch scope or
unavailable-Child/adult grant. Target authentication, fresh protection import,
PIN changes while waiting, keyless/held own forms, rollback, deep-link closure,
beacons and heavy-work fencing still require normal-app native qualification.
This checkpoint does not complete `AerioTV-Roku-mrr.9` or the epic.

## Startup-selection preflight

`UserProfileStartupSelection.brs` now supplies a distinct, read-only preflight.
It requires an absent runtime actor and empty runtime key, the startup-picker
purpose/fresh UUID, exact captured connection and roster roots, current selected
Dispatcharr slot, Ask On/multiple holders, full-access restored holder and exact
target record. It resolves only that target's own credential, ignores a memory
override when Remember is On, and rechecks shared broker admission. Transport
admission additionally requires the target's exact PIN grant. An explicit
pre-PIN check is only for pad admission, not permission to send requests.

Child targets remain refused at this boundary until their picker continuation
is qualified. This preflight does not authenticate, read/import a roster, flush,
change the active holder, publish settings, create an authenticated scope or
enable application routing.

Tests-first red: `out/mrr-startup-selection-preflight-red.log`. Host, shared
native (`out/mrr-startup-selection-preflight-native.log`) and full verification
(`out/mrr-startup-selection-preflight-verify.log`) pass stale actor/key/nonce,
changed URL/root/target, Child source/target, Ask Off, missing/replaced own key,
Remember-On memory borrowing and missing/changed PIN refusal. All cases prove
zero Flush and exact storage preservation. Normal-app authentication/import/
adoption and own-form integration remain next, not inferred from these tests.

The separate storage adoption API is now tested too. Its memory-only protection
receipt binds the actual current read lifecycle, own identity/authority, key,
retained roster root and exact target PIN record. Missing/legacy/valid canonical
reads can produce a receipt; failed, unknown, malformed Profiles, foreign-user
or stale reads cannot. Changed target protection invalidates the receipt and
requires the controller to retire that read and issue a new one.

`commitUserProfileStartupSelection` independently rechecks the no-actor preflight,
PIN and receipt against the full verified own-user lineup. It then reuses only
the shared content/settings transaction mechanics, not another flow's admission.
The active target, own settings and fresh scope publish together in one Flush;
pending edits and the default key remain. Failure restores exact prior storage.

Tests-first red: `out/mrr-startup-selection-adoption-red.log`; native shared
storage/receipt cases: `out/mrr-startup-selection-adoption-native.log`; full
verification: `out/mrr-startup-selection-adoption-verify.log`. These exercise
the real storage APIs with a fake registry on native Roku, **not** a completed
normal-app startup authentication/import/controller flow. Actual Task callback
binding, changed-PIN re-read and runtime adoption still require implementation
and qualification.

Retained protection publication is now implemented separately in
`commitUserProfileStartupRosterPull`. It rechecks the actual absent actor/key,
original target PIN and current own read before importing metadata. Newly
imported PINs are durable before continuation; an old grant produces no receipt.
Local pending intent and local tombstones are not acknowledged by this read.

Because no runtime actor exists in this boundary, received removals atomically
clean only removed holders' keys, backoff and scoped preference blobs. Removing
the restored holder selects the retained default and returns **no authenticated
scope or adoption receipt**; an ordinary default launch gate is still required.
This is not the live-switch retirement shortcut. Corrupt present preferences,
stale actors/read nonces/PINs and injected Flush failure preserve exact storage.

Tests-first red: `out/mrr-startup-selection-publication-red.log`; native shared
storage qualification: `out/mrr-startup-selection-publication-native.log`
(zero failures, exact app restored); full verification:
`out/mrr-startup-selection-publication-verify.log` (0.3.100, 351 files).
The current read/PIN/adoption APIs are not yet wired to actual normal-app Task
callbacks or the launch UI; public/runtime acceptance remains unfinished.

## Ordering/palette correction

Integration audit found that the first private component used a sample palette
and the plan used raw stored-array order. `AerioTV-Roku-9hcs` corrects both:
the plan now uses existing `userProfileSorted` (moved order, default/creation
tie-breaks and stable insertion), and the component uses the exact eight-color
hex lookup in `UserProfileAvatar.brs`, with the existing contrast-ink policy.
Tests-first failures are preserved in `out/mrr-picker-order-palette-red.log`
and `out/mrr-picker-palette-red.log`. Shared native model checks and full
verification pass. Real ECP UI requalification passes in
`out/mrr-picker-order-palette-ui-repeat-native.log`; the updated screenshot
was inspected. The preceding run's Select timeout is retained separately in
`out/mrr-picker-order-palette-ui-native.json`; exact restoration succeeded on
both. No intermittent delivery root cause or public startup completion is claimed.

Busy loading now fences new selections but still dispatches Back to its owner
(`AerioTV-Roku-ce25`). Tests-first direct `onKeyEvent` failure is retained at
`out/mrr-picker-busy-back-handler-red.log`. The expanded native fixture
deliberately sets busy before real Back; it now receives the expected final
intent, with all ECP responses 200:
`out/mrr-picker-busy-back-qualified-native.log`. Full verification:
`out/mrr-picker-busy-back-verify.log`. Earlier transport and reached-busy
failures remain separate; the direct-handler red establishes the guard defect
without treating HTTP acknowledgement alone as app event delivery.

The startup gate now accepts a typed, private selection-state object. With
explicit readiness, an unresolved adult Ask launch chooses the picker before
the restored holder's PIN/key gate. Actual resolved selection or a deep link
suppresses only that picker, never PIN/own-key/Child protection. Malformed or
absent readiness preserves the existing shipping behavior; malformed closure
does not suppress selection. No Scene caller supplies readiness yet.

Tests-first red: `out/mrr-startup-picker-order-red.log`. Final full verification:
`out/mrr-startup-picker-order-final-verify.log`; shared native policy suite:
`out/mrr-startup-picker-order-final-native.log`. These are policy tests, not
runtime deep-link/beacon acceptance.
