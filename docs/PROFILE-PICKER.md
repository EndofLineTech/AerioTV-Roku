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
