# Native PIN keyboard integration (`mrr.19`)

## Implementation boundary

The native Directions route now lives in the production shared PIN controllers,
not a fixture-only replacement. It remains an **explicit developer opt-in**:

```sh
python3 scripts/build-profiles-baseline.py --voice-pins \
  --output out/profiles-voice/aeriotv-roku-v0.3.100-profiles-baseline.zip
```

The builder adds `aeriotv_profiles_baseline=1` and
`aeriotv_profile_voice_pin_test=1`. Both are rejected by shipping verification
under every value. Native keyboard readiness is false in normal builds and
requires both developer flags. `--voice-pins` and the separately approved
`--directions` D-pad option are mutually exclusive. The ordinary developer
baseline does not silently enable either option.

This implements native entry plumbing, **not** public certification or observed
spoken entry. Requesting `voiceEnabled=true` cannot guarantee the OS enables
dictation. The device diagnosis and deferred physical-remote check remain in
[voice diagnostics](ROKU-VOICE-KEYBOARD-DIAGNOSTICS.md).

## Shared entry and security behavior

| Entry point | Native route |
| --- | --- |
| Restored/default launch and protection discovered before full connection | `beginProfilePinGate` uses `StandardKeyboardDialog` for Directions under native readiness; the cover, own-authentication ordering and launch cancellation remain owned by the existing continuation. |
| Chosen profile switch and newly imported protection during switch | The same controller retains captured target PIN material, switch nonce/session checks and covered continuation. No incoming requests are admitted by parsing alone. |
| Startup picker and own-profile sign-in | Existing startup/own-sign-in continuations use the same gate. Deep-link cancellation and task retirement scrub both native text aliases before detaching the old dialog. |
| Adult/Child management and protected exits | `beginAdultProfilePinGate` uses the same native keyboard for Directions. All-Directions households select this type, not stranded/no-PIN recovery. The grant remains management-purpose only, with no profile-unlock grant or holder names in the prompt. |
| Numbers | Existing six-slot `StandardPinPadDialog`, secure masking and native voice request remain unchanged. |

Directions input is password-domain, fully masked where the OS supports
`secureLastCharacter`, with a 64-character input bound and a hint describing
letters/words. Submissions accept:

- Four to six adjacent direction letters, case-insensitive, such as `udlr`.
- Four to six separate direction names/letters, separated by spaces or single
  commas, such as `Up Up Left Right` or `u, down, left, r`.

The parser does not guess ambiguous dictation aliases, concatenate words,
ignore arbitrary punctuation, or treat malformed text as a wrong PIN attempt.
The existing `userProfilePinNormalize` and stored verifier still enforce the
canonical 4–6-entry `UDLR` contract. Existing v2 raw-salt SHA-256 records, imported
PIN metadata, learned entry length and durable per-holder lockout are unchanged.
No PIN creation, salt creation, Device Admin creation or reset is enabled.

Both `dialog.text` and `dialog.textEditBox.text` are cleared on submission,
cancel, stale owned-context refusal and retirement. Keyboard text cannot be
recovered from a detached dialog through the other alias. Node identity and
existing slot/nonce/record/session checks remain mandatory. Missing voice does
not downgrade to an unprotected gate or silently switch to the D-pad.

## Evidence and preserved failures

Host controller and parser red/green evidence:
`out/mrr19-native-keyboard-controller-{red,green}.log`.
The focused suites cover native Directions launch/switch, wrong/malformed input,
both text aliases, all-Directions adult admission, management-only grants,
closure and numeric compatibility, alongside existing stale-context tests.
Builder and shipping-guard red/green evidence is recorded separately under
`out/mrr19-voice-{builder,package}-*.log`.

The first actual native letter-entry launch passes:
`out/mrr19-entry-launch-native.log` / `.json`. Actual native ECP letters enter
the secure keyboard before an owned submission; no provider request occurs
before entry/submit, the unchanged stored verifier grants access, then the
profile's own guide loads. The inspected `.keyboard.jpg` shows all four letters
masked. It records `voice_available_observed=false` and
`spoken_entry_verified=false`, independently of `entry_integration_passed=true`.
This was before the subsequent word-token conversion fix below; letter input
did not use the failing token-split path.

The first adult word-entry flow safely refused both word submissions:
`out/mrr19-entry-adult-native.log` and
`out/mrr19-entry-adult-initial-native.json`. Cleanup and exact baseline restore
passed. A focused native test then reproduced two failed word-parser assertions
in `out/mrr19-native-word-parser-red.log` / `.json`.

Cause: native
[`roRegex.Split`](https://developer.roku.com/docs/references/brightscript/interfaces/ifregex.md)
returns `roList`, while the existing verifier deliberately accepts only
`roArray`; the host interpreter returned an array and hid that mismatch.
The parser now copies tokens into an explicit array rather than relaxing the
verifier's type contract. The same focused native assertions pass in
`out/mrr19-native-word-parser-green.log` / `.json`, with exact restoration.
Both the original failure and the red/green remain preserved.

With that fix, the actual adult flow passes in
`out/mrr19-entry-adult-qualified-native.log` / `.json`: an all-Directions adult
set, masked native keyboard, wrong input refusal, verified management-only
grant, learned entry length, native rename and real Back cancellation.
No profile-unlock grant is installed.

The actual chosen switch also passes in `out/mrr19-entry-switch-native.log` /
`.json`: target native Directions keyboard and stored verification, own
authentication/roster before lineup, A/B/A, preserved default key/settings,
rejection rollback, real delayed-request Back rollback and stale events.
Both reports record `entry_integration_passed=true`, `cleaned=true`,
`restored=true`, `voice_available_observed=false` and
`spoken_entry_verified=false`. These are controller/HTTP integration tests using
synthetic credentials, not a successful physical microphone test.

`out/mrr19-entry-launch-cancel-native.log` / `.json` separately passes real ECP
Back from the native launch keyboard through the void `wasClosed` callback and
actual Main exit, with zero provider requests. The numeric path also passes its
current imported-PIN/real-30-second-lockout/correct-during-lock-refusal/unlock
regression in `out/mrr19-numeric-import-regression-native.log` / `.json`.
The previous canonical numeric report was preserved rather than replacing
historical evidence digests.

Eight focused host suites pass in
`out/mrr19-native-keyboard-final-focused-host.log`; subsequent owned-slot
retirement hardening has its own
`out/mrr19-native-keyboard-slot-retirement-{red,green}.log`. The latter proves
both aliases are scrubbed without verification when the owned keyboard's slot
has changed; it is not a native replay of that specific stale-slot case.
Probe/compiler/package checks pass, and the six native verdicts/digests are
recorded in `out/mrr19-native-keyboard-evidence-audit.json`.
Full `npm run verify` **passes** in
`out/mrr19-native-keyboard-full-verify.log`, including the 380-file normal
package. These focused results are not substituted for that full gate.

## Initial verified unsigned baseline handoff

`out/mrr19-native-keyboard-baseline-installed.json` verifies both variant
checksums, duplicate-free entry sets, compiled-content equality against the
full-gate package and byte equality for all 210 current BrightScript files.
It also verifies the exact previous-app checksum before replacement and the
new installed checksum afterward.

- **Initially installed ordinary baseline:**
  `out/profiles-mrr19/aeriotv-roku-v0.3.100-profiles-baseline.zip`
  SHA-256 `690479161796c3b98aeed5515bdcede413aa303a8f11e0353f71d3fa52522668`.
- **Initially separate, not installed, explicit native keyboard variant:**
  `out/profiles-mrr19/aeriotv-roku-v0.3.100-profiles-voice-baseline.zip`
  SHA-256 `df85ea1fd0bdbf70270c684f1f615365590bf9d03360ce46a536461442c36203`.

The inspected `out/mrr19-native-keyboard-baseline-ready.jpg` retains both test
profiles and Add. That ordinary baseline contains the new code but does **not**
enable native Directions or D-pad opt-ins. The subsequent owner-authorized
installation below supersedes it as the current restore artifact. Earlier ZIPs
remain preserved.
Neither variant is signed or released.

### Owner-authorized installation for actual-app testing

After clarifying that iOS/non-voice tests passed but voice had not been tested,
the owner explicitly requested enabling voice work in the actual app.
The fixture-free native keyboard variant above is **now installed**:

`out/profiles-mrr19/aeriotv-roku-v0.3.100-profiles-voice-baseline.zip`

SHA-256 `df85ea1fd0bdbf70270c684f1f615365590bf9d03360ce46a536461442c36203`.

`out/mrr19-owner-voice-baseline-installed.json` verifies the exact preceding
ordinary app before replacement, sidecar checksum, 380 duplicate-free entries,
identical compiled contents apart from manifest, absence of probe/fixture files,
successful launch and the installed checksum. The inspected
`out/mrr19-owner-voice-baseline-ready.jpg` retains both test profiles and Add.

This is the real shared application/controller route, not a standalone probe.
Use this **voice variant** as the exact restore ZIP for subsequent probes until
another installation is independently verified. The ordinary variant remains
available for rollback. The earlier ordinary-install record above is historical.
No PIN was created or changed by this deployment; existing/imported PINs remain
required. Actual speech acceptance is still pending owner testing.

## Acceptance limits

Native integration reports distinguish **entry integration**, observed voice
availability and **actual spoken-entry verification**. A false voice field does
not become a passing voice result, and ECP/callback text is never called speech.
The full `.19` public acceptance remains open until actual voice/access
qualification across the applicable gates. No vendor-outreach prerequisite or
Directions exemption is assumed.

All probes use disposable synthetic records and exact checksum restoration.
They do not change real server users, OS settings, pairing, networking, region
or firmware. The current baseline restore ZIP remains the version recorded in
[delivery status](MRR-DELIVERY-STATUS.md), not an older diagnostic's restore path.
