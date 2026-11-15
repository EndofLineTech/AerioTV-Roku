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
