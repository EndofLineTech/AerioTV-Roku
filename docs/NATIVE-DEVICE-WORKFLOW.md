# Native device acceptance workflow

This is the repeatable evidence path for the tested Roku target: Streaming Stick
4K (3820RW2), Roku OS 15.3.4, 1080p, and Dispatcharr 0.31.0. Automated tests and
the off-device BrightScript interpreter are useful regressions, not Roku UI,
remote, decoder, or network emulation.

## Build and package gate

From a clean checkout, install the pinned development dependencies and run:

```sh
npm ci
npm run verify
```

`verify` runs all model/controller tests, the compiler check, builds the ZIP, and
checks the ZIP root/version. It rejects tests, tooling, lockfiles, environment
files, and Beads data in the package. It does not prove that no application source
contains a secret; review changed source and keep credentials in the environment.

`npm run release:prepare` runs the same gate, creates
`out/release/aeriotv-roku-v<version>.zip`, and writes `SHA256SUMS`. It does not
publish a release.

## Release identification and rollback

The npm version, manifest version, archive filename, and checksum must all refer
to the same build. A sideload release is eligible for review only after the package
gate, controlled install/launch evidence, and its applicable physical worksheet
are recorded. Do not treat model tests, a successful install, or a screenshot as a
substitute for remote and audiovisual acceptance.

To roll back a sideload build, upload a previously verified versioned ZIP through
the Developer Mode installer. Roku replaces its single development-slot app; no
server configuration changes or device-policy changes are part of rollback. Record
the version being restored and use the same redacted evidence procedure.

## Controlled developer install

Supply credentials only through the shell environment. Do not put them in a
command history, worksheet, commit, screenshot, or console excerpt.

```sh
export ROKU_HOST='<device IP>'
export ROKU_DEV_PASSWORD='<developer password>'
python3 scripts/run-native-probe.py out/aeriotv-roku.zip \
  --marker 'Running dev' --prefix '[aeriotv'
```

The installer reports only install status, selected marker/prefix lines, and
compiler/runtime errors. It replaces the single Roku Developer Mode application.
It redacts HTTP URLs and the supplied developer password from output. A successful
install/launch is scripted-device evidence only; it is not remote or audiovisual
acceptance.

## Screenshot evidence

With `ROKU_HOST` still set, use:

```sh
python3 scripts/capture-roku-screenshot.py --output out/native-screenshot.jpg
```

The script makes the documented read-only ECP screenshot request. A `401` or `403`
means the Roku policy forbids it. Do not change the policy merely to collect
evidence. Use a physical camera instead, remove any credentials/URLs from the
image, and retain only redacted evidence outside Git. `out/` is ignored.

## Stability sampling

Capture the whitelisted model, OS, UI resolution, and uptime before installation,
after launch, and after a sustained browse/playback run:

```sh
python3 scripts/roku_device_info.py
```

The collector deliberately omits serial numbers, device IDs, MAC addresses, and
network data. A lower later uptime indicates a device restart; it does not by
itself establish an application cause. Pair the three outputs with redacted native
console errors and the real test duration. This is the `rgs.13` stability evidence
path and complements, but does not replace, physical remote acceptance.

## Physical remote fallback

ECP keypress may return `403` on the tested device. Do not enable or alter remote
control policy to make automation work. Use the supplied Roku physical remote and
record PASS, FAIL, or SKIP with the actual model, OS, build, media label, and
sanitized symptom.

- Current outstanding acceptance: `docs/PHYSICAL-TESTING-CURRENT.txt`.
- Completed historical Live TV/VOD evidence: `docs/PHYSICAL-VALIDATION-CURRENT.txt`
  and `docs/WORKSHEET-RECONCILIATION-0.3.28.md`.
- Required baseline path: setup/reconnect, populated guide, tune a known-working
  channel, verify now/next, exercise player Options, then Back/minimize and
  return to the guide.

For every fresh physical pass, distinguish what was seen on the TV (focus,
picture, sound, native remote behavior) from console/script observations. Never
copy provider URLs, account/API keys, passwords, or full diagnostic payloads into
the worksheet.
