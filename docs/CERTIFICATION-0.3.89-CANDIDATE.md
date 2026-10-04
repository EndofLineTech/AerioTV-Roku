# Roku certification candidate 0.3.89

This is a local certification candidate based on `release/v0.3.88` plus the
first-run dialog-beacon correction in `46d5f92`. It is not a published release
or a Store-approved package. The source ZIP is
`out/release/aeriotv-roku-v0.3.89.zip` (SHA-256
`2008a597ee95c5d2dbc5e0856bc46b1a55956712652fc5ed23e2ff3a55a995e1`).
`npm run release:prepare` passed model, tooling, compiler and package checks;
the verified ZIP has 195 files. The existing legal notices remain under
`images/`, not at the package root.

The Roku Packager's existing Dev ID matched the recorded prior signing identity,
and its installed-source MD5 matched this ZIP before signing. Its same-identity
signed package is `out/release/P5372541c3ab16a9cbb9aab6951064c3b.pkg`
(SHA-256 `3fe87fc866972fd694c3c8e8e6982013aa9511a69cd96d0d49d0ba5a6ea08c89`).
Both files pass `out/release/SHA256SUMS`. The package is encrypted and has not
been independently run as a Store-installed app. Roku's official local
`sca-cmd` 14.15.1 reported zero findings on the ZIP; metadata detected
launch/dialog beacons, `getUserData` and deep-link support. That local scan is
not a Developer Dashboard rescan.

## Device checks

On the Roku 3820RW2 / OS 15.3.4, the development ZIP installed and opened the
authorized 36-channel guide. A fresh first-run test of the same code before the
version increment verified `AppDialogInitiate` at Welcome and
`AppDialogComplete` followed by `AppLaunchComplete` after successful sign-in.
For this 0.3.89 ZIP, a cold saved-key launch emitted the same dialog/launch
sequence and reached the guide. A previously cancelled connection stayed on
setup without prematurely completing launch. Console evidence was reduced to
beacon names; private screenshots remain under ignored `out/`.

With the current account's authorized lineup on 0.3.89, an opaque `liveFeed`
content ID launched through both warm ECP input and cold ECP launch. In each
case the native media-player query reached `play`, `error=false`, `container=ts`.
This establishes the tested live route and device state, not perceived picture
or sound, permanent content IDs, or VOD deep-link compliance. Invalid-input
fallback was checked on earlier certification candidates.

Roku's email-sharing prompt was exercised with the owner's consent. The
account-name editor opened after the consent choice, and a saved-key reconnect
returned to the authorized guide without using the Roku email as the provider
username. The separate refusal/manual-password path also reached that guide
on the prior local build. No email, credential or provider URL is in this file.

## Certification gates

- Upload the signed candidate through the owner Developer Dashboard and run
  Static Analysis and App Behavior Analysis. Check findings #4 (launch), #13
  (root notice), and #15 (pre-home dialog) against actual portal results; a
  development ZIP or local package check is not a Store rescan.
- Ask Roku Developer Support how deep-link samples and supported `mediaType`
  requirements apply to a bring-your-own-source client with private,
  account-specific live/VOD catalogs and no Roku Search feed or app-published
  content IDs. Do not submit invented IDs, source URLs, or reviewer secrets.
  The single-live-feed exception does not apply to this multi-channel app.
- Confirm Developer Dashboard minimum firmware and account/monetization settings
  with the owner; these are portal settings, not manifest defaults.

Beads `AerioTV-Roku-ty6`, `grq`, `0vl`, `e19`, `856`, and `1is` retain individual
acceptance state. A local device PASS does not close a portal finding.
