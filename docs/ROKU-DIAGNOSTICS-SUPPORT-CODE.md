# Roku support code for non-developer diagnostics

The owner selected an in-app, no-network support-code flow for
`AerioTV-Roku-e76`. Open **Guide options → Diagnostics → Show support code**
after an event occurs. The app temporarily covers the underlying guide/video
with an opaque background, displays a grouped code for 90 seconds, then
removes it on Back, account change, app exit or timeout. A photograph remains
readable afterward; the code is **not a secret, credential or authentication
mechanism**, and its checksum detects transcription mistakes, not forgery.

The code includes at most the last eight events **for the current connected
account**, from the existing session-only one-hour/80-event/32 KiB ring. It
contains stage, bounded numeric error code, age in whole minutes and a coarse
elapsed-time bucket. It never contains freeform error messages, channel/media
labels, account identity, server URLs or API keys. Grouped characters fit in
120 visible characters. The existing on-TV diagnostics viewer and explicit
developer-console JSON export remain; the console JSON now excludes internal
account-scope metadata.

An offline helper decodes a photographed or dictated code without network
access:

```text
python3 scripts/decode-roku-support-code.py D113-35O2-00AW-Y
```

This is an artificial `playback -3` example, not a capture from the owner's
server. A corrupt/unknown code is rejected. The decoder reveals only event
type, code, relative age and elapsed-time bucket; support can ask the owner
for more context if needed. No receiver, listener, hosted webpage, registry
write or cross-account export is involved.

Verification: `npm run verify` covers scope isolation, redaction, code size,
fixed BrightScript/Python parity and malformed-code rejection. A native
3820RW2 / OS 15.3.4 check confirmed the six-action Diagnostics dialog,
readable grouped code, an **opaque screen covering the guide**, Back
dismissal and the code disappearing after the 90-second timer. The published
v0.3.83 ZIP was reinstalled afterward; ECP again reported `0.3.83`.
No second account or 120% text-size run was performed on-device; account
isolation and payload bounds are model-tested, not claimed as a native
cross-account sign-off. Developer Mode captures remain private under ignored
`out/`. This is post-v0.3.83 development work, not part of that release ZIP.
