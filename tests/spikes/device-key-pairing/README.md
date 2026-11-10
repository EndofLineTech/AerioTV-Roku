# Device-key pairing experiment

**Experimental branch only. Not an approved shipping random source. Never send
real credentials to this probe.** The normal app's entropy provider is unchanged.

This tests whether an OS-15.3 BrightScript receiver can perform wire-v1 setup
using fresh material conditioned by the device-key encryption API, rather than
preselected fixture TV keys. It does not infer CSPRNG strength from passing tests.

## Run

Run commands from the repository root with `ROKU_HOST` and `ROKU_DEV_PASSWORD`
supplied through the environment. `ROKU_RESTORE_ZIP` may point to the verified
normal 0.3.100 ZIP; its SHA256 is checked before these experiment runners install:
`eb09f4b9705262d11efba05a7b27281ff6272f2b22ff0f003805d9e20224a610`.
The scripts restore that ZIP in `finally`. Do not run two device suites together.

```sh
python3 tests/spikes/device-key-pairing/build-capability.py
node tests/spikes/device-key-pairing/test-capability.mjs
python3 tests/spikes/device-key-pairing/build-receiver.py
node tests/spikes/device-key-pairing/test-receiver.mjs
node tests/spikes/device-key-pairing/test-receiver.mjs --expiry-only

# Confirm production source still refuses setup, without experimental material:
python3 scripts/build-setup-receiver-probe.py --production-entropy
node tests/spikes/device-key-pairing/test-receiver.mjs --production-entropy

# Synthetic X25519 vectors now take the native byte-array hex-encoding path:
python3 scripts/build-phone-setup-probe.py --x25519
node tests/spikes/device-key-pairing/test-x25519-native.mjs
```

The screenshot decoder requires Swift/macOS. Images containing pairing QR codes
are deleted immediately after decoding; links, codes, private keys and device
encryption outputs are never printed. Results under `out/` contain only aggregate
measurements and verdicts. Native fixture-matrix values are synthetic, not live
private material. Temporary paths follow this machine's approved OpenCode temp
directory; adapt that constant on another host.

## Measured results

- Device/channel/model scopes: 96/96 encrypt/decrypt round trips; eight distinct
  outputs per eight repetitions of identical plaintext; 48/48 tampered outputs
  rejected. Output length is input length +32 on the tested OS15.3.4 device.
- Another 256/256 device encryptions succeeded, without repeats, in1132ms.
- Nine distinct generated receiver public keys decoded from actual on-screen QR
  and checked against the active fingerprint. Fresh host-generated phone X25519
  keys and nonces were used for every envelope, not the static sender vectors.
- All six synthetic payload shapes accepted, with replies in6847–7197ms.
- Origin, malformed envelope and invalid UTF8 rejected. Three wrong codes rotate
  the key on the same listener; old material rejected and new material accepted.
- Successful receipt closes the listener and refuses replay. Back during X25519
  cancels without publishing a payload. The real ten-minute expiry test passes
  without acceleration or keepalives, including closure under screensaver pause.

This found and reproduced a production bug: native `ToHexString()` produces
uppercase private-key hex, but the internal X25519 decoder accepted lowercase
only. That fix and its regression checks belong on `dev`; this entropy experiment
does not. Fixed-key receiver tests had bypassed the generation/encoding path.

## Source and limitations

`ExperimentalEntropy.brs` hashes a locally verified `roDeviceCrypto.Encrypt()`
result for a domain-separated constant using the device key. It rejects missing
objects, invalid/short encryption results, failed decrypt round trips, invalid
digest results and consecutive identical digest results. It contains no fallback.
The existing material generator performs key clamping and unbiased code draws.

These tests establish functional behavior, not entropy provenance or minimum key
strength. They are not deployed-provider acceptance, profile/Sync import, a real
iPhone/Android sender test, a signed Beta/Store package, or a security approval.
No firmware update, new runtime, GitLab authentication or external post is needed
to run them. Shipping `source/PhoneSetupEntropy.brs` remains fail-closed.
