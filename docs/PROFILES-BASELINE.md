# Developer profiles baseline

This is an unsigned, developer-only build, not a Beta/Store release or completed
profiles/sync acceptance. Normal builds keep the new entry points off.

## Build

```sh
npm run verify
python3 scripts/build-profiles-baseline.py
```

Output: `out/profiles-baseline/aeriotv-roku-profiles-baseline.zip`, with its
`.zip.sha256` checksum. The title is **AerioTV Profiles Baseline** and the
manifest contains `aeriotv_profiles_baseline=1`. Shipping verification rejects
that field under any value. Building does not install or sign anything.

## Try it

The currently installed checkpoint uses **Settings → Profiles
(baseline) → Open Profiles**. Add another account using its own username/password, then choose
it from the Profiles menu. Manage Profiles offers rename, avatar and earlier/
later movement. The menu also toggles the per-playlist Ask-at-launch choice.
With multiple profiles and Ask on, startup shows the picker; holding OK on a
tile and releasing opens its Move menu.

Add verifies the new login and reads that account's existing protection before
saving an inactive profile. Selecting it uses its own key, protection check and
fresh lineup; source credentials/preferences are not copied. Existing PINs
remain required. Local roster edits remain pending, not falsely uploaded or
acknowledged.

## Deliberate limits

- Dispatcharr Sync must be off for baseline Add/local switching. No Sync writes
  or scheduler is enabled.
- No new PIN creation or Child setup is enabled by the baseline flag.
  Unsupported protected/legacy/recently removed additions refuse safely.
- Complete onboarding and broader
  physical-remote/accessibility/certification acceptance remain unfinished.
- This uses the existing application registry. Do not clear data, reset keys or
  change the server merely to test it.

## Current device evidence

### Follow-on source (not installed as the persistent baseline)

Settings now uses **Connection → Profiles**, with profile rows, Add and
Ask-at-launch. The authenticated top-bar avatar opens the full-screen TV
switcher with Add/Manage, current/locked indicators and hold/release reorder.
All twelve non-initial avatar catalog choices have distinct original packaged
glyphs, tinted with the shared contrast ink in both tiles and top-bar avatars;
unknown icons retain the initial fallback. `scripts/generate-ui-assets.py`
reproduces the assets, and `out/mrr-avatar-catalog.jpg` is the inspected catalog.
`out/mrr-core-avatar-native.json` passes the full core flow with a selected
custom rocket avatar, including the adopted top-bar glyph URI.
Management removes inactive non-default profiles atomically; active removal
first switches to the default using its own access, then confirms again.
Existing numeric PIN removal requires the target's current PIN and refuses
adult PIN removal while any Child remains. Cancel restores management.
New-salt PIN creation/change/reset and Device Admin creation remain unavailable.

The focused real-server flow passed in `out/mrr-controls-canonical-native.log`
and `.json`: Settings Add, own-account switcher, TV reorder, native PIN Cancel
and verification/removal, active-profile removal, credential/preference isolation,
private-fixture cleanup and exact installed-baseline restoration all passed.
The earlier `out/mrr-controls-native.log` stalled in synthetic PIN seeding;
canonical field replacement fixed the fixture without weakening app checks.
Chosen own-sign-in now preserves outgoing playback through the credential/PIN
form; focused host evidence is `out/mrr-own-playing-host.log`, not yet native
playing-media acceptance. Bounded server-admin policy/payload tests exist, but
its transport/UI has since been implemented behind the developer baseline gate;
synthetic native policy/task checks pass in `out/mrr-admin-policy-final-native.log`.
Real server-user mutations and native admin UI success-path acceptance remain
unverified.

`out/mrr-child-live-native.log` extends the same real-server main flow with an
imported-PIN Child selection and actual adult-PIN management escape back to the
other account. It passes hidden Child switcher, own keys, both native PIN pads,
the rest of the core flow, cleanup and exact baseline restoration. Developer
baseline source now enables existing Child loading/recovery and import-only role
controls; normal builds still leave Child readiness false. New-salt/Device Admin
creation and Directions access remain separately gated. Chosen missing-key Child
own-sign-in has focused host checks; this is not full interoperability acceptance.

The fixed developer ZIP is
`out/profiles-baseline/aeriotv-roku-v0.3.100-profiles-baseline.zip`.
SHA256: `86b92a22d10bd031e5a932c71f010295825a4983f1c8b418b373dbe63bb9cf21`.
It includes Add retry cleanup, the actual Settings page/action integration, and
management movement based on visible position rather than unset stored order.
With explicit owner approval, **Profiles Test** was added and selected, signed
in as the first approved test account through the normal password/auth/read/
guide controllers. Existing Home metadata, saved key and profile root were
verified unchanged. `out/mrr-baseline-provision-ready-native.log/.json` reports
success; the normal fixed ZIP was reinstalled and its installed MD5 verified.
The subsequent normal-build guide screenshot was inspected:
`out/mrr-baseline-profiles-test-ready.jpg`. No provisioning fixture remains.
The second test account was used only in the disposable flow; add it through
the baseline menu when desired.

The real Dispatcharr flow passed in
`out/mrr-baseline-real-dispatcharr-move-fixed-native.log/.json`:
Settings category → Open Profiles → own-password Add/protection read → own-key
switch → management Move earlier. Final Add isolation, switch isolation,
reorder and active-holder checks are all true; disposable registry cleanup and
exact previous-baseline restoration passed. The source used its own verified
key; form submission and management choices used owned controller events.
This is real app/network/storage evidence, not physical-keyboard or
accessibility/certification acceptance.

The run exposed and fixed the Settings rail/action crash (`AerioTV-Roku-oq1r`)
and unset-order movement bug (`AerioTV-Roku-ymqz`). Bounded real-server flow
qualification is closed in `AerioTV-Roku-bou2`; broader epic acceptance remains
open. Full regression: `out/mrr-baseline-real-settings-final-verify.log`.
Focused policy/storage evidence remains in
`out/mrr-baseline-focused-fixed-tests.log` and
`out/mrr-baseline-policy-qualified-native.log`.

The earlier synthetic host-callback journey was blocked by VPN reachability;
no network configuration was changed. The separate held-OK startup Move attempt
hit the tracked initial ECP Right timeout and is not counted as native success.
That is separate from the now-qualified management Move action.

For an authorized, existing Dispatcharr test server, the focused runner accepts
`--dispatcharr-credentials /private/path/logins.json --restore /path/to/baseline.zip`.
The private JSON contains `baseUrl` and exactly two `accounts`, each with
`username` and `password`. Keep it outside the checkout. Both accounts must
already have API access enabled. The runner uses auth POSTs and read requests,
never creates accounts or uploads App Data, stores credential-bearing ZIPs in
a private temporary directory outside the checkout, and restores the exact
baseline after cleaning its disposable registry.

Persistent setup is a separate, explicitly confirmed operation:
`scripts/provision-profiles-baseline-native.py --confirm-create`. It uses normal
connection and sign-in controllers, binds the intended username, refuses an
existing test-name collision, verifies prior connection ownership unchanged,
and installs the normal baseline afterward. Its credential payload and one-shot
package stay in a private temporary directory outside the checkout. Shipping
verification rejects provisioning material. It is not part of ordinary testing.

The owner-supplied test logins both authenticated successfully. They initially
returned no API key; after the owner enabled API access, both returned their own
keys. The focused real-server journey then passed. A temporary HTTP
429 during repeated sign-in checks was respected without automatic retries;
no server settings were changed by the agent.

## Rollback on the authorized development Roku

Reinstall the preserved owner build
`out/pairing-tests/pill-ui/aeriotv-roku-v0.3.100-pairing-test.zip`.
SHA256: `91f8b8b1f3c2f45e625588e198b8f0a66af963ea285d49e1a27483461afb8734`.
Reinstalling preserves registry data; it does not undo profiles intentionally
added while trying the baseline. Do not delete those records without approval.
