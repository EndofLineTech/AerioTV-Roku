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

Final package/checksum and remaining native variants are recorded below only
after verification; this document alone is not a signed-package handoff.

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
Beads, not silently closed or converted into certification acceptance. Signing
waits for all in-flight native and release-preparation verification to finish.

`npm audit` reports zero critical/high and two moderate development-tool entries
(`brs` and its `uuid` dependency, GHSA-w5hq-g745-h8pq), already tracked in
`AerioTV-Roku-tcn`. Neither npm dependencies nor tooling are shipped in the Roku
ZIP. This is a disclosed existing tooling finding, not a claim of a clean audit.
