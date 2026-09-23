# Development 0.3.40 — controlled Roku check (2026-09-22)

Target: Streaming Stick 4K (3820RW2), Roku OS 15.3.4 build 2402, 1080p.
The exact local package `out/aeriotv-roku.zip` passed `npm run verify`
and the package gate before installation. Developer Mode installer returned
`Installed: True` and the native launcher marker for AerioTV Roku Preview.
Read-only ECP `/query/active-app` then reported version **0.3.40**.

An authenticated local capture (kept in ignored `out/`, not committed)
showed the normal Preview guide populated with channels and program cells,
without a black screen or visible error state. Device uptime advanced across
installation and capture without a restart. The first capture showed guide
loading; a later capture showed populated results. This establishes a native
launch and default-guide smoke check, **not** a Basic density, spoken Audio
Guide, or DVR acceptance result.

ECP `/keypress/Up` returned HTTP 403 under the existing device policy. No
device policy was changed. Physical-remote checks remain: toggle Basic and
Preview in Settings > Live TV, verify visibility controls and focus/long text;
enable Roku system Audio Guide and the app's General > Audio Guide choice,
then record actual spoken labels/order across guide, settings, player and VOD.
The DVR task is not wired to a UI action, so native create/cancel behavior and
server ownership after exit remain unverified.

No credentials, server address, screenshot or channel/media labels are stored
in this document.

## Follow-up after the owner enabled ECP remote control

The owner explicitly changed Roku's Control by mobile apps setting; a normal
HTTP ECP keypress now returns 200. A held-Up guide navigation reached the
first channel, but a focus animation then paused the native render thread in
the BrightScript debugger (`AerioSurface.brs:35`, runtime error `&h18`):
it compared a float scale with a vector2d array. This was an app error,
not an ECP failure. The animation was corrected, `npm run verify` passed,
and the verified 0.3.40 development ZIP was reinstalled. The installer
briefly replayed the *old* debugger error before the new launcher marker;
no new error was observed after the reinstall.

With ECP, focus moved from the guide to group pills and primary navigation,
then into Settings. Settings > Live TV > Guide density switched Preview to
Basic; a native capture showed 10 compact non-overlapping guide rows. Show
channel logos switched On to Off; a capture showed the logos hidden. Both
settings were restored (Preview and logos On), confirmed in the final guide
capture. The app's General > Audio Guide switch was turned On briefly:
settings/guide navigation completed with no native debugger error. It was
then restored to Off, confirmed in Settings. Actual spoken feedback was not
recorded, so Audio Guide acceptance remains open. ECP button delivery and
screen captures do not prove audio output or physical-remote behavior.
The owner subsequently confirmed that the physical remote is responsive again
after the corrected build was installed.
