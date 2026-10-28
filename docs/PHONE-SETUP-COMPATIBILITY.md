# Phone-assisted setup: wire-v1 compatibility

Research and implementation slice, 2026-10-28. Bead: `AerioTV-Roku-e3e.2`.
This is not an enabled sign-in feature or a successful phone-to-Roku transfer.

**Correction after release-note research and native retesting:** Roku OS 15.2
added `setTag`/`getTag`. With those APIs, AES-256-GCM passes our nonempty-payload
authentication tests on OS 15.3.4. The earlier no-tag-interface tests below
were incomplete API usage, not evidence that Roku lacks GCM support.

## Contract and platform evidence

The [pinned upstream contract][contract] requires X25519, HKDF-SHA256 and
AES-256-GCM (12-byte nonce, 16-byte tag, no AAD), plus secure random code/key
generation. The receiver advertises `_aeriotv-setup._tcp`, displays an offline
QR and fingerprint, and accepts one encrypted payload during a ten-minute
session. Three failed decryptions rotate the code **and** key. The companion
remote service is separate. Android has a sender; Apple sender/receiver are
marked planned in this revision.

| Primitive | Official Roku evidence | Remaining proof |
| --- | --- | --- |
| HTTP listener | [roStreamSocket][tcp] documents bind/listen/accept | Real LAN HTTP lifecycle, bounded input and cancellation |
| DNS-SD | [roDataGramSocket][udp] provides UDP; this alone is not an mDNS responder | Multicast discovery/advertisement and mobile interop |
| HKDF-SHA256 | [roHMAC][hmac] supplies the underlying HMAC | Native RFC-vector execution, then protocol-specific derivation |
| AES-256-GCM | Native `aes-256-gcm` with explicit tag handling passes three nonempty host vectors | Empty payload fails; production adapter and phone interop remain |
| Authentication tag | [OS 15.2 release notes][release-notes] announce `setTag`/`getTag`, omitted from the interface reference | Native tag generation and modified-input rejection verified below |
| X25519 | No suitable documented primitive established by this investigation | Supported implementation and RFC 7748/interoperability vectors |
| Random key/code | [GetRandomUUID][device] documents UUID v4, not a cryptographic random-byte contract | Establish an appropriate entropy source; do not substitute `Rnd()` |
| QR | No implementation added | Offline encoding and real phone scan |

A successful `Setup` return for a cipher name is **not** proof of correct GCM
decryption or authentication. CBC/128-bit GCM cannot replace upstream's cipher
without a coordinated protocol change. A software X25519/GCM implementation
would need independent vectors, tamper tests and native performance evidence.

## Implemented foundation

`source/PhoneSetupModel.brs` validates version, envelope size/shape, strict
standard or URL-safe base64, raw field lengths, and Origin refusal. It returns
canonical encoded fields for a future crypto adapter. It does not decrypt or
apply credentials. The future HTTP reader must cap **bytes while receiving**;
this model's string-length guard does not replace that transport budget.

The pure session model records no secrets. It rejects expired, used, cancelled
and stale-generation attempts, rechecks expiry after asynchronous processing,
and closes the old generation on the third failed decrypt. A serialized
receiver must own transitions; `accepted` may only be supplied after both AEAD
authentication and plaintext payload validation. `expired` is an internal
session result for shutting down the waiting UI, not a new upstream wire error.

Unit tests cover these boundaries, including cancellation, replay, late results,
code rotation and malformed payloads that must not spend a code attempt.

## Synthetic native probe

```sh
python3 -m unittest scripts/phone_setup_probe_test.py
python3 scripts/build-phone-setup-probe.py
```

The standalone `out/phone-setup-probe.zip` contains only the synthetic Main,
model and simple results scene. It does not read the normal app's registry,
contact a provider, advertise a setup session or accept credentials. It checks
RFC 4231 HMAC, RFC 5869 HKDF and NIST AES-256 block vectors; records cipher
setup return codes; and binds/closes an ephemeral **loopback-only** TCP socket.
ECB here is only a primitive known-answer test, not a proposed transfer mode.

With developer credentials configured, use the existing controlled installer:

```sh
python3 scripts/run-native-probe.py out/phone-setup-probe.zip \
  --marker '[setup-probe] complete' --prefix '[setup-probe]'
```

This replaces Roku's single development slot. Restore the owner's exact normal
app ZIP afterward. The probe prints only synthetic result labels and model/OS,
not keys, LAN addresses or user data. It neither proves full TCP request handling
nor phone interoperability.

### Native results — 2026-10-28

Ran on Streaming Stick 4K (ECP model 3820RW2; `GetModel()` 3820X2), OS 15.3.4.
HMAC RFC 4231, HKDF RFC 5869, AES-256 block, loopback bind/listen and envelope
shape checks passed. `aes-256-gcm` Setup returned 0; `aes-gcm-128` and
`aes-gcm-256` returned -1 on this device.

The zero-key/nonce AES-256-GCM fixture was independently checked with Node
crypto. Native encryption returned 16 bytes rather than ciphertext plus the
16-byte tag. Native Process decryption returned invalid for ciphertext alone,
ciphertext plus the correct tag, and ciphertext plus a modified tag. Thus this
tested API path does **not** establish usable authenticated GCM decryption;
rejection of a modified tag alone is insufficient when the valid case fails.
X25519, secure entropy, DNS-SD/QR and Android interoperability remain unproven.

Python networking failed locally while Node console capture and curl digest
installation worked. Drain buffered console output and restart through Home
before capturing a run: the console can replay a prior probe's completion.
The normal 0.3.100 candidate was restored and ECP confirmed AerioTV active.
Restored ZIP SHA256:
`eb09f4b9705262d11efba05a7b27281ff6272f2b22ff0f003805d9e20224a610`.

### Reproducible authenticated-decryption matrix

`scripts/phone-setup-vectors.mjs` generates 27 fixtures with Node crypto and
checks their expected acceptance using authenticated host decryption. Four
positive fixtures use nonzero keys/nonces and plaintext lengths 0, 1, 16 and 37.
The 23 negative fixtures change keys, nonces, ciphertext or tags, or omit/truncate
tags. The host explicitly requires 16-byte tags, as the upstream contract does.

`tests/native/PhoneSetupMatrix.brs` runs each fixture through two candidate paths:
`Process(ciphertext || tag)` and `Update(ciphertext)`, `Update(tag)`, `Final()`.
Only a successful final result with exact plaintext counts as positive acceptance.
Early Update output never counts as authenticated. These tests cover the two
specified input arrangements, not hypothetical undocumented tag-control methods.

```sh
python3 -m unittest scripts/phone_setup_probe_test.py
python3 scripts/build-phone-setup-probe.py
# Supply device credentials in the environment. Pass the normal app to restore.
node scripts/validate-phone-setup-native.mjs out/native-parity-normal.zip
```

The runner discards buffered console data before launching a fresh probe, checks
fixture completeness and verdict types, writes synthetic per-case evidence to
`out/phone-setup-native-results.json`, and restores the normal ZIP in `finally`.
Exit 0 means at least one tested path passed the whole contract; exit 2 means
the complete matrix ran but neither path passed; errors indicate a failed run.

Actual target results (2026-10-28, same OS/device as above):

| Check | Process | Update/Final |
| --- | --- | --- |
| Valid authenticated plaintext accepted | **0/4** | **0/4** |
| Invalid fixtures rejected at finalization | 23/23 | 23/23 |
| Whole contract | **FAIL** | **FAIL** |

Encryption controls matched host ciphertext for all three nonempty plaintexts,
but none returned the appended tag; empty plaintext returned invalid. Streaming
decryption produced the correct pre-final plaintext for the three nonempty valid
fixtures **and their changed-tag counterparts**, then Final returned invalid.
Thus the raw cipher operation works for these vectors, but these tested paths
cannot complete authenticated decryption. Rejecting all inputs is not an AEAD
success. The runner deliberately exits 2 for this result. AerioTV 0.3.100 was
restored after the run. Resolving the tag interface (or implementing and validating
a compatible adapter) remains the next crypto work under `AerioTV-Roku-e3e.2`.

### Explicit tag API: supported for nonempty payloads

The [Roku OS 15.2 release notes][release-notes] explicitly announce `setTag` and
`getTag` for AES-GCM. The component/interface reference pages omit their
signatures. GitHub code search returned no examples combining `roEVPCipher`
with `setTag`; the authoritative lead was the release note, not search absence.

Native calls verified on this Roku:

```brightscript
cipher.setup(false, "aes-256-gcm", keyHex, nonceHex, 0)
cipher.setTag(tagBytes) ' roByteArray, separate from ciphertext
plain = cipher.update(ciphertextBytes)
tail = cipher.final() ' Must succeed before accepting any plaintext
```

For encryption, `cipher.getTag()` returns an `roByteArray` separately after
processing. Its 16 bytes matched the host oracle for all three nonempty vectors.

The new `settag-stream` path accepted **3/3 nonempty valid payloads** (1, 16,
37 bytes). It rejected all 15 full-length-tag negative fixtures at finalization;
the test adapter rejected the eight absent/truncated-tag fixtures before calling
crypto, enforcing the wire contract. The empty valid payload still returned an
invalid final result, so the full matrix retains exit 2 and reports the narrower
`nonemptyCompatible` result separately. An empty plaintext is not a valid setup
JSON payload, but this API edge case remains recorded rather than hidden.

**Conclusion:** the earlier failure resulted from not supplying the tag via
`setTag`; it was not proof of a Roku GCM limitation. AES-256-GCM support is now
demonstrated for the tested nonempty payloads. Production adapter integration,
X25519, cryptographic entropy and end-to-end phone interoperability remain work.

[release-notes]: https://developer.roku.com/dev/docs/release-notes#roku-os-152
[contract]: https://github.com/jonzey231/AerioTV/blob/fe7ad4c1968a193efb7a55d68b2b3bd32d03b17a/docs/DeviceSetupHandoff.md
[tcp]: https://developer.roku.com/dev/docs/rostreamsocket
[udp]: https://developer.roku.com/dev/docs/rodatagramsocket
[hmac]: https://developer.roku.com/dev/docs/rohmac
[cipher]: https://developer.roku.com/dev/docs/roevpcipher
[cipher-interface]: https://developer.roku.com/dev/docs/ifevpcipher
[device]: https://developer.roku.com/dev/docs/ifdeviceinfo
