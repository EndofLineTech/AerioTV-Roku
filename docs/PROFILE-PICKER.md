# Profile picker implementation boundary

`UserProfilePicker` and its staged Scene controller are private:
`m.profilePickerReady` remains false. Init now has a guarded deferred route;
synthetic normal-app fixtures enable it, while shipping init retains its
existing route. There is no public top-bar action. The component grants no authentication,
PIN, management, or credential authority.

`source/UserProfilePicker.brs` calculates ordered presentation from a validated
roster. Child, single-profile, other-provider and deep-link launch cases return
no tiles. Explicit Ask Off is preserved. Launch and switcher purposes distinguish
Back exit/close, current-holder PIN/close and Add/Manage intent. Creation's
default-on Ask choice and existing explicit-choice migration remain unfinished;
no stored choices were changed here.

The component displays initial/color avatar fallbacks, wrapped names, a native
shape lock badge, current caption in switcher mode and four-column focus.
Catalog avatar artwork, appearance/text-scale variants and complete parent
admissions remain unfinished. `UserProfilePickerInput.brs` defers short OK until release,
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

The integration uses a distinct startup-selection boundary with no authenticated
outgoing actor/key, not a fabricated chosen-switch scope or unavailable-Child/
adult grant. Cached-own-key target authentication, protection import and changed
PIN continuation now have native controller evidence below. Complete automatic
startup routing, own forms, cancellation/failure/deep-link lifecycle and
certification-ready beacon acceptance remain unfinished.
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
zero Flush and exact storage preservation. These preflight tests alone do not
establish runtime or own-form acceptance; see the separate controller evidence.

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
the real storage APIs with a fake registry on native Roku, not the normal-app
controller. The latter now has separate bounded evidence below.

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
The API removal/default-selection cases here remain storage-suite evidence;
normal-app removal/recovery acceptance is not inferred.

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
does not suppress selection. The private Scene route now supplies readiness;
shipping `profilePickerReady` remains false (see deferred routing below).

Tests-first red: `out/mrr-startup-picker-order-red.log`. Final full verification:
`out/mrr-startup-picker-order-final-verify.log`; shared native policy suite:
`out/mrr-startup-picker-order-final-native.log`. These are policy tests, not
runtime deep-link/beacon acceptance.

## Private normal-app controller

`components/ProfilePickerNavigation.brs` owns the picker node, selected
connection/root, distinct incoming UUID and actual authentication/read/load
Tasks. There is no outgoing authenticated actor or runtime key to fabricate.
Stored selection/settings are not adopted before full verified content and the
atomic startup adoption API succeed. The existing switch controller now shares
only the post-commit runtime publication helper.

Native normal-app qualification using a disposable registry and isolated HTTP:

- Unprotected cached-own-key selection:
  `out/mrr-picker-launch-plain-repeat-qualified-native.log`.
- Protected restored default and protected target: the picker precedes the
  default's PIN; choosing B verifies B's real native PIN before **any** provider
  request: `out/mrr-picker-launch-pin-qualified-native.log`.
- Fresh import changes B's PIN after initial verification. Protection is durable,
  another real PIN is required, then a new own read with a distinct read UUID
  precedes full load: `out/mrr-picker-launch-import-pin-qualified-native.log`.

PIN fixtures submit wrong/correct text through the actual native dialog,
Scene callback, SHA verifier and registry/backoff path, never fabricated grants.
They use a private ECP-input handshake to trigger those submissions, not physical
remote digit entry. Wrong PINs stay covered; no heavy provider work precedes
the required verification/read. Initial selection uses actual ECP Right/Select.

All three cases show zero pre-selection requests, no runtime actor/key during
authentication/read/load, own B `/me`/App Data before own lineup, fresh B scope,
B guide/favorites/appearance, retained source data/default key/pending intent
and no autoplay or fabricated PUT acknowledgement. Final app state closes the
startup dialog; this is not Dashboard/certification beacon acceptance.
Screenshots were inspected. Existing chosen-switch/writer regression also
passes: `out/mrr-picker-shared-adoption-switch-native.log`.

The protected run first exposed `AerioTV-Roku-mbvu`: deep-copying an opaque
case-insensitive native PIN grant as settings JSON changed its map semantics.
Native same-PIN/learned-length publication tests reproduced the failure
(`out/mrr-picker-pin-grant-copy-red-native.log`). Publication now retains the
actual immutable verified grant, not a replacement. Shared native green:
`out/mrr-picker-pin-grant-copy-fixed-native.log`; actual protected/imported PIN
continuations pass without the temporary publication/failure diagnostic hooks.
Final full verification: `out/mrr-picker-controller-qualified-verify.log`
(0.3.100, 352 files).

Every isolated run, including failures, cleaned its disposable registry and
checksum-restored the exact owner app. New first-key timeouts remain preserved
under `667m`; passing repeats do not resolve them.

Still unfinished: the remaining default/removal/cancellation and stale-callback
matrices, own keyless/
held forms, Child selection, Add/Manage/reorder, default-on Ask migration,
top-bar switcher and full public acceptance. Current private handlers refuse
unsupported own-form/Child/management choices without requests. Shipping readiness
must stay false until those integrations and independent approval gates are met.

## Owned cancellation and rejection

Real Back while B's submitted `/me` is deliberately delayed now cancels the
owned Task, clears its key/nonce and closes the picker, then exits Main with
the exact initial roster/settings/keys unchanged:
`out/mrr-picker-launch-back-fixed-native.log`. The ECP Back is sent only after
foreground-dev/no-screensaver checks, receives HTTP 200 and is observed through
actual cancellation and Main closure. No App Data or heavy requests occur.

Typed rejected-key `/me` now returns to the covered picker with no actor/runtime
key, exact saved roots/keys and the required target-username rejection text:
`out/mrr-picker-launch-reject-repeat-fixed-native.log`. It sends only that one
own `/me`, never retries or deletes either credential.

`AerioTV-Roku-czoh` fixed the first rejection run's generic message: checking
permission to send **new** requests had prevented consuming the already-owned
failed Task result after the broker held the key. Failure consumption now checks
exact actor/key/root/PIN/actual global nonce ownership without reopening broker
admission. Successful read/adoption and every new Task still require it.
Tests-first handler red: `out/mrr-picker-owned-rejection-red.log`; native storage
regression: `out/mrr-picker-rejection-boundary-primitives-native.log`; full
verification: `out/mrr-picker-rejection-fix-verify.log`. The imported-PIN/fresh-
read normal-app case also passes after this change:
`out/mrr-picker-launch-import-pin-rejection-regression-native.log`.

All runs cleaned their private section and restored the exact app. A separate
first-key timeout before any target request remains preserved in
`out/mrr-picker-launch-reject-fixed-native.json`, not conflated with rejection
handling or claimed resolved by the later pass.

Failure now keeps the selected target focused by its ID in the freshly sorted
roster (`AerioTV-Roku-wvze`), not by a stale index or the restored source's
default focus. Host and native tests-first failures:
`out/mrr-picker-failed-focus-red.log`,
`out/mrr-picker-failed-focus-red-native.log`; the red screenshot is retained.
Actual native green and inspected target-focused rejection screenshot:
`out/mrr-picker-failed-focus-repeat-fixed-native.log`,
`out/profile-picker-launch-rejected.jpg`. A further real Select on the held
target creates no Task/provider request or adoption, and preserves exact saved
roots and both keys. This is safe refusal, not completed own-sign-in forms.
Full verification: `out/mrr-picker-failed-focus-verify.log`. The preceding
first-key transport timeout remains separate at
`out/mrr-picker-failed-focus-fixed-native.json`.

## Deferred startup and deep links

The private init route is now implemented, not a fixture-only cold-call hook.
Main signals `startupReady` **after** `screen.show`, exit observation and a
check for an already-requested exit. Only private picker readiness can defer
startup. The Scene waits for that actual signal before starting its one-shot
decision timer; it never reads `launchRequest` in init or guesses readiness
from elapsed time. A changed captured connection root stays covered without
requests or rewriting data.

Cold media intent skips selection but not the actual restored holder's own
key/PIN. A warm media intent closes the picker, cancels its owned incoming
Task/nonce and scrubs/detaches its own native PIN node before returning to the
restored holder's ordinary launch gate. It reloads current retained protection,
not the pre-import snapshot. No authenticated outgoing/default scope or adult
grant is invented. Malformed media intent still skips optional selection;
`normalizeLaunchRequest` remains the sole playback validator and rejects URLs,
unsupported media and invalid IDs.

Native evidence:

- Cold link: no picker created, real restored PIN before any provider request,
  then own `/me`/App Data before own guide:
  `out/mrr-picker-cold-link-qualified-native.log`; inspected native PIN image
  `out/mrr-picker-cold-link-qualified-native.jpg`.
- Link while picker is open: one picker created then closed, restored PIN
  required, own source data and keys preserved:
  `out/mrr-picker-warm-link-first-native.log`.
- Link replaces the selected target's PIN pad: actual old pad is detached;
  stale submit/close callbacks cannot affect the new source pad or exit it.
  Real source verification then loads only the restored user's guide:
  `out/mrr-picker-warm-pin-link-repeat-qualified-native.log`; inspected source
  PIN image `out/mrr-picker-warm-pin-link-repeat-qualified-native-source-pin-2.jpg`.
- Link during a submitted/delayed target `/me`: cancels the incoming Task and
  key/nonce, requires restored PIN, then uses only the restored own key. The
  restored guide remains correct past the delayed reply:
  `out/mrr-picker-warm-auth-link-qualified-native.log`; inspected source PIN
  image `out/mrr-picker-warm-auth-link-qualified-native-source-pin-1.jpg`.
- Deferred protected-target/imported-PIN regression:
  `out/mrr-picker-deferred-import-pin-repeat-native.log`.
- Shipping-fenced held Child launch/own PIN/Back regression:
  `out/mrr-picker-deferred-child-launch-regression-native.log`.
- Shared native model/storage regression:
  `out/mrr-picker-deferred-primitives-native.log`.
- Final full verification:
  `out/mrr-picker-deferred-routing-checkpoint-verify.log`.

The link ID deliberately does not exist in the authorized lineup: these cases
prove selection suppression/authentication/account routing and safe non-play,
not media playback or certification. Local beacon instrumentation records one
launch completion and paired dialog initiate/complete events; replacing the
picker with a source PIN closes the old dialog and begins a new one. This is
not Dashboard, production entropy or owner acceptance.

All isolated runs cleaned and checksum-restored the exact app. First-key
timeouts remain preserved under `667m`. A distinct install-success/no-launch
trace failure is preserved under `36eu`, including its exact ZIP and checksum;
later passing repetition does not establish its cause.

`r7pl` separately fixes a runner race: Main could report actual cancellation
and exit before the fixture HTTP thread assigned the ECP acknowledgement.
The verdict now joins that bounded acknowledgement event, rather than sampling
it before cleanup. Timeout/non-200 still fail; no key is retransmitted.
Tests-first red: `out/mrr-picker-cancel-ack-red.log`; actual native green:
`out/mrr-picker-deferred-back-ack-repeat-fixed-native.log`.

## Known account mismatch

An owned `identityChanged` result now retains an in-process refusal bound to
the exact server/slot/local holder/user ID/username/credential digest. Repeating
selection with that known-mismatched key sends no request; a media intent cannot
retry it through the restored-holder route either. Other holders and replacement
keys remain independent. This is not a typed key rejection, broker hold, key
deletion or authenticated adoption. It survives picker cancellation, not app
restart; own-form integration remains unfinished.

Tests-first handler red: `out/mrr-picker-identity-refusal-red.log`.
Native HTTP-200 wrong-identity plus repeated real Select green:
`out/mrr-picker-identity-refusal-repeat-native.log`; inspected image:
`out/mrr-picker-identity-refusal-repeat-native-rejected.jpg`.
The report proves one target `/me`, no App Data/lineup, no broker hold and
unchanged roster/settings/both keys. Typed rejection and cold-link regressions:
`out/mrr-picker-identity-refusal-rejection-regression-native.log` and
`out/mrr-picker-identity-refusal-cold-link-regression-native.log`.
Full verify: `out/mrr-picker-identity-refusal-final-verify.log`.
The first native attempt timed out before selection; its separate evidence is
preserved at `out/mrr-picker-identity-refusal-native.log/.json` under `667m`.
All attempts cleaned their fixture data and restored the exact owner app.
