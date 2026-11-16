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

On an authenticated adult Dispatcharr account, open **Settings → Profiles
(baseline)**. Add another account using its own username/password, then choose
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
- No new PIN creation or Child setup/selection is enabled by the baseline flag.
  Unsupported protected/legacy/recently removed additions refuse safely.
- The polished top-bar switcher, complete onboarding/removal and broader
  physical-remote/accessibility/certification acceptance remain unfinished.
- This uses the existing application registry. Do not clear data, reset keys or
  change the server merely to test it.

## Current device evidence

The baseline ZIP was installed and its installed MD5 matched the built ZIP.
The active developer app reports **AerioTV Profiles Baseline**. The current
saved owner connection opens as Xtream with empty session login fields, so no
authenticated Dispatcharr Profiles-menu acceptance is claimed from that state.
Connection settings were not altered.

Focused host tests and native fake-registry Add/switch-storage policies pass:
`out/mrr-baseline-focused-fixed-tests.log` and
`out/mrr-baseline-policy-qualified-native.log`. These prove policy/storage
boundaries, not a complete two-account UI/network journey.

The synthetic full-app journey currently cannot receive the Roku's HTTP
callbacks through the host's VPN route; no network configuration was changed.
The separate native Move attempt hit the already tracked initial ECP Right
timeout. Both remain unverified rather than counted as passes. Full acceptance
continues in Beads.

Installed baseline ZIP SHA256:
`2d3f1bca659887223a5fbd1ef0a63355dd29f7c555c3b4402b6e5035941004b6`.
The network journey is tracked in `AerioTV-Roku-bou2`; safe retry cleanup after a
failed Add commit is deferred in `AerioTV-Roku-letr`.

## Rollback on the authorized development Roku

Reinstall the preserved owner build
`out/pairing-tests/pill-ui/aeriotv-roku-v0.3.100-pairing-test.zip`.
SHA256: `91f8b8b1f3c2f45e625588e198b8f0a66af963ea285d49e1a27483461afb8734`.
Reinstalling preserves registry data; it does not undo profiles intentionally
added while trying the baseline. Do not delete those records without approval.
