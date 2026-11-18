# AerioTV Roku 0.3.102 — phone setup Beta

## Change notes

- Enabled direct encrypted phone-to-Roku setup in the normal Beta build; no
  developer pairing build or replacement entropy provider is needed.
- Import a Dispatcharr playlist and its supplied profiles using each account's
  own verified credentials. Fresh imports preserve valid sender profile UUIDs;
  existing local default-profile UUIDs remain stable.
- Keep imported numeric/Directions PIN protection and Child restrictions.
- Ask separately about Profiles Sync; receiving a phone payload never opts in.
- Treat an empty optional default-proof map as absent and authenticate normally;
  a nonempty invalid proof still fails closed.

## Included profile and UI/UX improvements

The bullets above describe the new v0.3.102 delta. The delivered Beta also
contains the earlier profile and UI work; a phone-only changelog understates
the cumulative release.

- Profile picker, quick switching, avatars, reordering and optional
  “Who is watching?” at launch; separate own-account permissions, favorites,
  appearance and supported player preferences.
- Native numeric/Directions PIN entry and supported voice input, protected adult
  management, and safer switch/cancel/credential-recovery/address-change flows.
- Better-centered navigation text and labels, balanced icon gutters and compact
  icon-free library tabs that leave more room for large text.
- Consistent rounded pill controls for navigation, channel-browser groups, search
  actions and compact VOD selectors; fixed cap seams/artifacts and native-dialog
  inflation.
- Bounded multiline/ellipsized category/provider/source labels, shorter headings
  and spacing that avoids library-tab collisions.
- Correct appearance repainting for scene backgrounds/DVR colors, readable
  light-mode guide subtitles/DVR captions and mapped channel-browser surfaces.
- Cleared stale programme subtitles/layout when entering an empty channel group;
  shared remote hints in the search footer.
- Detail-first EPG mapping for smaller lineups and larger bounded logo/metadata
  caches, as already included in v0.3.101.

These are inherited fixes, not newly implemented in v0.3.102. See
[UI audit fixes](UI-AUDIT-FIXES.md): all 409 captures across 146 starting cases
were inspected in isolated production renderers, including normal/large text,
light appearance, empty groups, search, browser groups, VOD selectors and DVR
captions. This evidence is not a universal claim about live overlays, every
account/device, or resolution of the remaining affected-account guide/logo
issues. Native keyboard appearance remains system-owned.

## Evidence and boundaries

The normal receiver/provider, encryption, profile verification/import, PIN and
switch controllers remain byte-for-byte intact in the isolated full-app test.
Only disposable local storage/cache and the test driver differ. Account requests
go to the approved **live Dispatcharr** test service, never a laptop HTTP
fixture. The laptop listener used in earlier failed runs was unreachable through
the VPN; those timeouts are not evidence of a production app defect.

`out/phone-normal-apple-live-child-qualified.json` records the unmodified pinned
Apple encoder's normal-receiver QR/encrypted transfer, wrong-code/replay refusal,
live account verification, preserved playlist/profile IDs and own keys, numeric
default PIN, Directions Child PIN, Child selection and explicit Sync decline.
All 18 native device-provider/failure checks pass. Disposable storage is cleaned
and the exact immutable v0.3.101 ZIP is restored after the test.

`out/phone-normal-android-live-child-qualified.json` independently passes the
same live flow with the unmodified Android encoder.
`out/phone-normal-apple-live-adult-qualified.json` passes default→adult using
the two approved test accounts; the Android adult variant passes separately in
`out/phone-normal-android-live-adult-qualified.json`. All four runs clean up
and restore the exact baseline. These are separate imports, not a fabricated
three-account default/adult/Child batch.

`out/phone-normal-beta102-source-equivalence.json` additionally checks **every
shipping file** against all four saved native probe ZIPs, reversing only the
disposable registry/cache redirect and appended driver. All shipping bytes match;
ZIP timestamps/compression are not mistaken for source changes.

Apple/Android protocol sources are hash-verified against their pinned commits;
provenance is in `out/phone-normal-peer-encoders.json`. These encoder tests are
**not physical phone UI acceptance**.

The repeatable native command uses developer credentials from the environment:

```sh
python3 scripts/test-phone-setup-normal-native.py \
  --source out/release/aeriotv-roku-v0.3.102.zip \
  --restore out/release/aeriotv-roku-v0.3.101.zip \
  --peer apple --secondary-role child \
  --peer-directory /private/path/to/rebuilt-pinned-encoders \
  --dispatcharr-credentials /private/path/to/approved-live-test-accounts.json
```

Repeat with `--peer android` and/or `--secondary-role user`. The installed ZIP
must match `--restore` before replacement. `--diagnostic` is troubleshooting
only and always refuses to count as normal-byte acceptance.

Bonjour multicast does not cross the test VPN. Current QR/direct-endpoint
acceptance does not claim current same-LAN discovery acceptance. Physical
iPhone discovery and physical Android testing remain Beta-user checks.

The device-key source is functionally qualified with fail-closed validation and
bounded repeat refusal. It does not claim an undocumented vendor CSPRNG guarantee;
the owner explicitly made that assurance question non-blocking. No UUID/Rnd,
fixed-key or network entropy fallback was added.

## Scope and release status

This supersedes v0.3.101's *unavailable normal phone receiver* limitation, not its
other limitations. Existing/imported PINs are supported; new PIN/Device Admin
creation remains outside this phase. Only Profiles Sync is supported.

The nine open original P1s and Dashboard minimum-firmware issue listed in
[v0.3.101 notes](BETA-CANDIDATE-0.3.101.md) are not closed by this work. The owner's
Beta risk approval is not Store-submission or cloud-certification acceptance.
v0.3.101's signed package and checksums must remain unchanged.

## Signed Beta handoff

Full `npm run release:prepare` passes in
`out/phone-normal-beta102-release-prepare.log`. Its 380-file versioned ZIP matches
every shipping-file fingerprint from all four qualified live native runs.

Upload **`out/release/aeriotv-roku-v0.3.102.pkg`** to the Beta Dashboard.

| Artifact | SHA-256 |
| --- | --- |
| `aeriotv-roku-v0.3.102.pkg` | `27b0f8fc9b6544f0c2bb26dee36de09aeaaf3168c222465efe1677c87f8e6930` |
| `aeriotv-roku-v0.3.102.zip` | `68ad35da6a076259aacf413be181dcce64af3db08d790d5d6d0d5af08f5ffaab` |

The exact versioned ZIP was installed and its Packager MD5 verified before
signing with the existing Dev ID `2c759fbb3556070e7eee7276265ae55566f427c7`.
No key generation/rekey or credential change occurred. The original opaque Roku
export is preserved; `npm run beta:package` created the versioned copy.
`SHA256SUMS-v0.3.102` verifies both files. The immutable v0.3.101 `.pkg` and ZIP
still pass their original versioned checksums.

The exact v0.3.102 signing source remains installed on the Roku. Nothing was
submitted to the Dashboard or Store. Discord-ready change notes are in
`docs/DISCORD-0.3.102.txt` (two posts, each under 2,000 characters); they have not been posted
to a Discord channel by this session.

## Developer Mode distribution

The owner subsequently authorized a public GitHub development prerelease for
self-installation:
[v0.3.102](https://github.com/EndofLineTech/AerioTV-Roku/releases/tag/v0.3.102).
Its assets are the **same verified ZIP** above and a ZIP-only
`aeriotv-roku-v0.3.102.zip.sha256`, not a rebuilt candidate or the signed package.
See [development release notes](DEV-RELEASE-0.3.102.md) for sideloading steps,
the one-development-app-slot warning and known limitations.

Discord copy now uses native `#`/`##` headings. Post #2 includes the repository,
development release link and owner-supplied Beta channel code **`GQMQGQL`**.
This authorizes development-ZIP distribution, not Store submission, a Dashboard
change or a new certification acceptance claim.

## Source and static analysis

Compared with the immutable v0.3.101 source ZIP, only `manifest`,
`source/PhoneSetupEntropy.brs`, `source/PhoneSetupProfileImport.brs` and
`components/PhoneSetupProfileVerifyTask.brs` differ. The existing guide/cache
bytes remain unchanged; unrelated working-tree research/probes are excluded.

Official Roku Static Analysis 16.0.1 completes with no errors and the same
previously reproduced DES false positive at `source/DescriptionModel.brs:6`
(French word `des`). `out/beta102-sca-full.json` contains that one warning.
AES-256-GCM is unchanged. No cipher or harmless translation string was edited
to hide a scanner finding. Dashboard metadata/cloud certification is separate.

The readiness check found no open P0 and no open PR targeting `dev`. No CI
security workflow is configured; local compiler/package/tests and official
Roku analysis supply this candidate's gates. Existing P1 scope is retained in
Beads, not silently closed or converted into certification acceptance. All native
and release-preparation verification finished before signing.

`npm audit` reports zero critical/high and two moderate development-tool entries
(`brs` and its `uuid` dependency, GHSA-w5hq-g745-h8pq), already tracked in
`AerioTV-Roku-tcn`. Neither npm dependencies nor tooling are shipped in the Roku
ZIP. This is a disclosed existing tooling finding, not a claim of a clean audit.
