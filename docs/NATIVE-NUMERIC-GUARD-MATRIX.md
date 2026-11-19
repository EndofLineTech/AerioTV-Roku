# Numeric guard qualification (AerioTV-Roku-9sq)

This developer-only channel exercises unchanged production model code with
local data. It has no app scene, provider client, network listener, credential
or Roku registry access. It does not establish a production regression simply
by showing that an AA literal reports `roInteger`. Do not widen validation
based on a synthetic mismatch.

| Entry point | Contract tested | Current caller and what the probe reproduces |
| --- | --- | --- |
| `httpFailure(..., "too-large", bytes, cap)` | Byte bucket requires recognized integer values, a response over budget, and a cap of at least 1 MiB. No numeric strings, booleans, null, LongInteger, Float or Double. | `DispatcharrHttp` passes direct `len(response.body)` or `response.bytes`, and the default or an `m.maxResponseBytes` override. `HttpTransport` puts `roFileSystem.stat().size` or `roByteArray.count()` in that response AA. The probe uses those native APIs on local data and replays the AA/cap shapes. Mapping detail's 65,536-byte cap deliberately has no bucket. A missing bucket is lost diagnostics, not an accepted oversized download. |
| `metadataCacheState` | Schema is integer `1`; `fetched` must be a positive, nonfuture integer. With an integer clock, `fetched = now` is fresh and `fetched = now + 1` misses. Valid scope, kind, payload and byte budget are controls. The noninteger rows vary one field at a time. | `metadataCacheWrite` serializes `metadataCacheEnvelope`; `metadataCacheRead` parses that text before passing its entry to the model. The probe uses that writer/reader codec round trip with both a small exact timestamp and a realistic epoch. An unpersisted AA is diagnostic only. The probe does not use the production cache directory, filesystem, checksum or provider refresh. |
| `normalizePreferenceStore`, `loadStrictPreferenceStore`, `loadPreferenceStore` | Integer schema `1` retains data; the non-strict model preserves a newer integer version, while the strict loader refuses it. Malformed strict stores are read-only, not empty writable defaults. An account favorite distinguishes retained data from a default with the same schema. | Current app startup/roster adoption use `loadPreferenceStore(..., true)`: `ParseJson(raw, "d")` through the strict loader, **then** the normalizer. Cleanup and other scoped transactions call the strict loader itself. Both are tested, plus an actual `savePreferenceStore` round trip, using an in-memory `settingsV1` stand-in and no decoder override. The non-precision load and raw AA are comparison paths, not evidence about startup. |
| `validatePhoneSetupEnvelope` | JSON body; `v` must be a recognized number equal to `1` (including valid decimal/exponent spellings); no numeric strings, booleans, null, fractional or wrong version. No direct AA/typed version enters this API. | `phoneSetupOpen` in `PhoneSetupCrypto` gives the validator the body string. The probe replays just that string with valid-length inert base64 fields. It does not run crypto or an HTTP receiver. |
| `validatePhoneSetupPayload` | `guideDays`, `catchupOffsetMinutes`, each `channelProfileIds` item, and profile `order` accept Integer/LongInteger and integral Float/Double, not fractions, strings or booleans. Null scalar fields default; a null array item fails. `guideDays` accepts `0` and `14`, but rejects `-1` and `15`. Inspect accepted value/default and real 400 error, not only the return type. | `PhoneSetupCrypto` supplies the result of `ParseJson` on verified plaintext. The probe constructs these same parsed shapes without decrypting anything, and compares boxed literals and typed assignments. This does not qualify sender/apply semantics or downstream ID/offset ranges. |

## Build and run

```sh
./node_modules/.bin/bsc --project tests/native/numeric-guard-probe.bsconfig.json
node --test scripts/numeric-guard-report.test.mjs
node scripts/test-numeric-guard-probe.mjs
```

Host checks have 210 rows (18 observations). The host interpreter does not implement the native
`ParseJson(..., "d")` precision flag or accept Double in `Fix()`; the affected
phone payload rows say `host-fix-unsupported`. The host preference round trip
uses the non-precision path and is labeled `comparison`, not `caller`. Host
results do not establish firmware boxing or native parser behavior.

Only the device owner should run this next command. It replaces the currently
sideloaded app; restore the prior developer ZIP afterward. Record the Roku
model and firmware/build separately. Do not include developer credentials
in the record.

```sh
python3 scripts/run-native-probe.py out/numeric-guard-probe.zip \
  --timeout 45 --prefix '[numeric-guard]' --marker '[numeric-guard] COMPLETE' \
  > out/numeric-guard-native.log
node scripts/test-numeric-guard-probe.mjs out/numeric-guard-native.log
```

The checker requires the exact inventory and a consistent terminal record:
231 native rows (14 observations) or 210 host rows. It checks type slots,
expectations and lanes independently of the probe, and reports `caller` and
`caller-shape` mismatch counts separately. It checks evidence integrity, not
product approval. Review every mismatch:

- `caller` failures reproduce inputs at the named model boundary. For
  `caller-shape` failures, check the exact input types and source in production
  before proposing a narrowly scoped fix. If an HTTP bucket is lost, do not
  conflate it with a transport size-limit bypass.
- `synthetic` AA/typed or malformed `wire` rows are not proof of ordinary
  rejection. Do not make Float/Double or LongInteger acceptable to a strict
  Integer guard just because a valid-looking value was rejected.
- Only the designated parser rows (and, on host, eight known `Fix()` skips)
  can be observations. The checker ties their accepted outcomes to the
  reported types; runtime/fixture errors are never observations. `ParseJson`
  may map whole decimal/exponent tokens to either integer or floating types.

The shipping build's allowlist excludes this probe and its verifier separately
rejects probe source paths.
