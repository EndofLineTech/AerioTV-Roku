# Native voice-keyboard diagnosis — November 17, 2026

Scope: `AerioTV-Roku-mrr.19`. The owner directed native voice-keyboard PIN entry
under certification criterion 4.12, not an assumed Directions exemption.
No account, network, firmware, privacy or remote-pairing setting was changed.

## Observed device state

Read-only ECP and native `roDeviceInfo` report:

- Streaming Stick 4K, ECP model `3820RW2` / native model `3820X2`.
- Roku OS **16.0.4**, build **853**.
- Native account country **US**, app country **US**, locale **en_US**.
- `hasFeature("voice_remote") = true`; hands-free remote feature is false.
- ECP `voice-search-enabled = true`.

A paired remote and enabled voice search do not establish that the physical
remote is currently active or that keyboard dictation is operational.

## Isolation result

`scripts/test-voice-keyboard-native.py` installs a minimal diagnostic containing
no AerioTV application code, registry access, requests, socket listeners, PIN
records or component-name overrides. Screen display precedes dialog creation.
Only one keyboard is present at a time; each is removed before the next.
It records native defaults before any enable request, then after visible focus,
then after explicitly requesting `voiceEnabled = true`.

| Native control | Masked | After focused display | After explicit enable |
| --- | --- | --- | --- |
| `StandardKeyboardDialog`, ordinary text | No | false | false |
| `StandardKeyboardDialog`, password domain | Yes | false | false |
| `StandardPinPadDialog` | Yes | false | false |
| Raw `DynamicKeyboard` | No | false | false |

Every internal text node identifies as `VoiceTextEditBox`; each displayed
keyboard reports focus. Password/numeric entry types update correctly.

Two completed runs reproduce the result:

- `out/mrr19-minimal-voice-qualified-native.log` / `.json`.
- `out/mrr19-voice-manifest-native.log` / `.json`, additionally setting the
  documented `supports_voice_roinput=1` attribute in the private diagnostic
  manifest. It makes no difference to the observed keyboard field.

Both reports have `diagnostic_completed=true`, `restored=true` and
`settings_changed=false`. Completion means the diagnosis ran, **not** that voice
input passed. Both checksum-restored the exact fixture-free installed baseline.
The first diagnostic compile attempt failed on use of BrightScript's reserved
`Box` name as a variable; it also restored the baseline. A new compiler-backed
unit test catches that fixture error before native installation.

## What this establishes—and what it does not

The observed false field is reproducible without the Directions verifier,
masking, AerioTV startup/dialog ownership or another voice textbox. Adding the
voice-control manifest attribute does not resolve it. It is not evidence of an
AerioTV-specific Directions entry defect.

The **underlying trigger remains unresolved**. Current evidence cannot choose
between active physical-remote state, platform dictation/service availability
or firmware behavior. Do not call any of those a confirmed cause, reset the
device, change region/network settings or assume a microphone permission exists.
The owner was unavailable for the proposed live physical-remote check.

The next discriminating observation is a blank native keyboard while the owner
uses the paired physical remote: wake it with an arrow, check the microphone
indicator, then test a harmless non-secret utterance. Compare that with native
voice search if necessary. Record actual field/dictation behavior rather than
equating ECP text injection with speech. This observation is not an instruction
to bypass the PIN verifier or a project-wide stop-work condition.

The earlier private Directions candidate's text-entry/hash verification remains
valid; its false voice field and lack of spoken-entry evidence are separate.
No public certification, spoken-input acceptance or release is claimed.

The shared production controllers now also have an explicit developer-only
[native PIN keyboard route](PROFILE-NATIVE-PIN-KEYBOARD.md), rather than relying
on the earlier fixture-only UI replacement. Integration pass, observed
`voiceEnabled` and actual spoken input are recorded separately. This does not
change or explain the isolated device-wide false field above.

## Reproduce

With the existing authorized developer environment:

```sh
python3 -m unittest scripts.voice_keyboard_probe_test
python3 scripts/test-voice-keyboard-native.py \
  --restore out/profiles-mrr19/aeriotv-roku-v0.3.100-profiles-voice-baseline.zip \
  --report out/mrr19-minimal-voice-native.json
```

Add `--voice-controls` for the private manifest comparison. The runner refuses
installation if the restore ZIP does not match the currently installed app.

References checked November 17, 2026:
[criterion 4.12](https://developer.roku.com/dev/docs/certification),
[device capability methods](https://developer.roku.com/dev/docs/ifdeviceinfo),
[native voice text field](https://developer.roku.com/dev/docs/voice-text-edit-box),
[dynamic keyboard](https://developer.roku.com/dev/docs/dynamic-keyboard),
[manifest voice-control attributes](https://developer.roku.com/dev/docs/channel-manifest).
