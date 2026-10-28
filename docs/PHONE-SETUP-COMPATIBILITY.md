# Phone-assisted setup: wire-v1 compatibility

Research and implementation slice, 2026-10-28. Bead: `AerioTV-Roku-e3e.2`.
This is not an enabled sign-in feature or a successful phone-to-Roku transfer.

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
| AES-256-GCM | [roEVPCipher][cipher] lists **aes-gcm-128** since OS 15.2; AES-256 ECB/CBC also exist | 256-bit authenticated GCM is not established |
| Authentication tag | [ifEVPCipher][cipher-interface] documents Setup/Process/Update/Final, no tag setter/verifier | Never accept plaintext without verifying the AEAD tag |
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
nor phone interoperability. The native run is pending: `ROKU_HOST` and
`ROKU_DEV_PASSWORD` were unavailable in the implementation session.

[contract]: https://github.com/jonzey231/AerioTV/blob/fe7ad4c1968a193efb7a55d68b2b3bd32d03b17a/docs/DeviceSetupHandoff.md
[tcp]: https://developer.roku.com/dev/docs/rostreamsocket
[udp]: https://developer.roku.com/dev/docs/rodatagramsocket
[hmac]: https://developer.roku.com/dev/docs/rohmac
[cipher]: https://developer.roku.com/dev/docs/roevpcipher
[cipher-interface]: https://developer.roku.com/dev/docs/ifevpcipher
[device]: https://developer.roku.com/dev/docs/ifdeviceinfo
