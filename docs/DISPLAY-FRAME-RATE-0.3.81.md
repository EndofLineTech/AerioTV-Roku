# Roku 50 fps display-rate feasibility — v0.3.81

Tracking: `AerioTV-Roku-5cq`. Investigated 2026-09-26 on Roku Streaming Stick
4K `3820RW2`, Roku OS `15.3.4`, 1080p UI. This is a client/device capability
check, not a Dispatcharr profile change or a new playback feature.

## Platform contract

- tvOS [sets `AVDisplayManager.preferredDisplayCriteria`][tvos] and Android TV
  [requests the measured content rate with `Surface.setFrameRate`][android].
- Roku's [roDeviceInfo][device-info] attributes are documented as query-only.
  [`GetVideoMode()`][device-interface] identifies the video output mode: the
  published value table distinguishes `1080p50` (50 Hz), `1080p` (60 Hz),
  and `1080p60b10` (60 Hz, 10 bit). `GetDisplayMode()` describes the UI
  resolution, not the HDMI refresh rate. Roku's OS 15 reference also lists
  `isAutoAdjustRefreshRateEnabled()` as a read-only setting query, but invoking
  it in this device's sideloaded SceneGraph app raised native `&hf4` “Member
  function not found.” The first probe was stopped and the normal app restored;
  the subsequent probe does not call that unavailable getter. This is target
  evidence, not a claim that the method is absent on all Roku devices.
- Roku [support][roku-support] describes Auto-adjust display refresh rate as
  a **user-owned OS setting** in Settings → System → Advanced system settings →
  Advanced display settings. Disabled outputs at 60 Hz; enabled *may* match
  content and may cause a black HDMI resync. Roku explicitly notes that some
  apps/content do not support matching. No supported app-level setter analogous
  to Apple's display criteria or Android's Surface frame-rate request was found
  in the inspected [Video][video] and device interfaces. Do not invent one.
- A [Roku developer response][roku-forum] says that with Auto-adjust enabled,
  the OS *tries* to match content FPS; the available output rates may depend on
  HDMI EDID. The response discusses 24.000 versus 23.976 on an Ultra, not a
  guarantee of 24 or 50 Hz matching on this Streaming Stick, monitor, or app.

## Reproducible isolated test

`scripts/build-frame-rate-probe.py` injects the tiny `tests/native/FrameRateProbe`
Scene into a disposable ZIP under ignored `out/`, replacing only the development
slot until the verified normal application is reinstalled. The probe uses only
packaged synthetic media; it does not sign in, fetch a provider, change display
settings or write to Dispatcharr. `ffprobe` measured H.264/AAC 640×360 MP4
samples at exactly `50/1` (1,400 video frames / 28 s) and `60/1` (1,680 / 28 s),
plus MPEG-TS samples with the same rates and ~28 s duration. A separate MP4
control contained 24 fps video and the 60 fps comparison clip. The Video node
reached `playing` with error code 0 in each phase. Every five seconds the probe
logged `GetVideoMode()` and after 25 s switched from the first-rate clip to the
60 fps clip, then stopped at 50 s and sampled the idle mode for another 10 s.

| Auto-adjust user setting | Packaged sample | Before / during first rate / during 60 / after stop | Display-side observation |
| --- | --- | --- | --- |
| Disabled (original) | 50 → 60 fps MP4 | `1080p60b10` throughout | No independent HDMI measurement. |
| Temporarily Enabled by PO | 50 → 60 fps MP4 | `1080p60b10` at 0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60 s | PO observed no display resync. |
| Temporarily Enabled by PO | 50 → 60 fps MPEG-TS (`ts`, `live=true`) | `1080p60b10` at the same checkpoints | HDMI rate was not checked independently during this run. |
| Temporarily Enabled by PO | 24 → 60 fps MP4 control | `1080p60b10` before, during and after playback | PO observed no display resync. |

The UI stayed at `1080p`. The 24 fps control also failed to induce a mode
change, so this test cannot isolate a 50 fps-specific limitation. A Roku
Developer Mode screenshot would omit decoded video pixels and cannot establish
judder, motion quality or audio continuity.
No controlled 50 fps *authorized Dispatcharr live URL* and no external HDMI
mode analyzer were used; package-file TS is a transport-shaped probe, not an
end-to-end provider test. The observed constant device-reported mode proves
only that this target did not switch for these clips with the tested user
settings. It does not prove that all Roku applications or other stream formats
cannot switch.
The PO restored Auto-adjust to its original **Disabled** value after the trial.
The signed-off normal v0.3.81 development-slot ZIP was reinstalled after each
probe and launched successfully; no new setting or Video field was added to
the application.

## Second display — 2026-09-28, setting not yet confirmed

The PO connected the same 3820RW2 (OS 15.3.4 build 2402) to an **LG C3** TV
reported to support refresh-rate changes. Its HDMI signal-rate readout and current
Roku **Auto-adjust display refresh rate** setting have not yet been supplied;
do not carry over the previous monitor's Disabled setting as a fact about this
session. Roku reported `2160p60Dv` before, during and after each isolated run,
which is a different output mode from the first monitor's `1080p60b10`.

The original `out/frame-rate-50.mp4` and `out/frame-rate-50.ts` each contain
exactly 50 fps video; their 60 fps counterparts were reused. A new ignored
`out/frame-rate-25.mp4` was derived from the 50 fps synthetic clip, with 700
frames in 28 seconds at exactly 25 fps and the existing AAC audio retained.
The probe builder can now package 25 fps and write unique ZIPs under `out/` so
the earlier probe artifacts are preserved. The actual per-run mode evidence:

| Packaged media (25 s each) | Roku output before / during first rate / during 60 / after stop | Native media state |
| --- | --- | --- |
| 50 → 60 fps MP4 | `2160p60Dv` at 0, 5, …, 60 s | Both reached `playing`, error 0 |
| 25 → 60 fps MP4 | `2160p60Dv` at 0, 5, …, 60 s | Both reached `playing`, error 0 |
| 50 → 60 fps MPEG-TS (`live=true`) | `2160p60Dv` at 0, 5, …, 60 s | Both reached `playing`, error 0 |

This establishes no matching *in the as-yet-unconfirmed setting*, not that
the TV rejects 25/50 Hz or that Roku will fail with Auto-adjust explicitly
enabled. The original normal development package (SHA-256
`0ff78a7339f6ed5dab6940296a85d8ea1c1718274402f121ec0dca4425c6bc24`)
was reinstalled after the probes; ECP confirmed the normal developer app
active. No server settings, source profiles or TV/Roku display preferences
were changed by the probes. Next comparison requires the PO to confirm the
HDMI input-rate readout, turn Auto-adjust **On** personally, and
report the setting before a repeat run. Restore the previous setting afterward.

## Display capability remains unverified

The test display is an **InnoView INVPM502**. A [third-party product/manual
page][monitor-page] describes an 18.5-inch 2560×1440 monitor with a 120 Hz
refresh rate and HDMI input. It does **not** supply an HDMI input-timing table,
an EDID dump, or evidence that this HDMI connection advertises 24 or 50 Hz.
Panel maximum refresh rate is not the list of accepted HDMI input rates. The
page is not a manufacturer-verified timing specification; neither the page nor
the lack of an observed resync establishes that this monitor caused the Roku's
60 Hz output. Whether the Stick connects directly or through an HDMI
adapter/switch/AVR (which could affect the EDID seen by Roku) is also unknown.

To separate display negotiation from app/OS behavior, first capture the HDMI
input's **advertised modes** (for example, its EDID using a computer on the
same input and signal path) or repeat a known 24 fps title in a Roku app known
to trigger refresh matching on a display with an on-screen HDMI signal-rate
readout. Restore the user's original Auto-adjust **Disabled** setting after any
approved comparison. If available, repeat the same packaged 24/50 fps probes
on a second display with verified 24/50 Hz support. A positive mode switch
elsewhere would narrow the cause; a second negative result alone would not
identify which component prevented matching. A live 50 fps provider test still
requires an authorized sample and independent HDMI measurement.

## Decision boundary

**Recommended current adaptation:** Leave the Roku app's frame-rate routing
alone. Retain its tested MPEG-TS path and truthfully show measured/source FPS
in Stream Info; let the viewer own Roku's system Auto-adjust setting. The
publicly documented Roku surfaces examined here expose a read-only mode and
setting, not a supported application display-mode switch. Enabling a made-up
field, silently transrating a shared Dispatcharr channel, or claiming smooth
50 fps output from a `playing` state would not address the actual TV signal.

If a 50 fps provider example later shows a Roku-supported mode switch or a
documented app API becomes available, re-evaluate under an explicitly approved
sample: measure the same channel at 50/60 Hz via TV HDMI info (or analyzer),
play/retune/Back, A/V continuity and mode restoration, and compare the
user-owned Disabled versus Enabled setting without changing shared profiles.

[tvos]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/App/TSHLSRemuxer.swift#L2450-L2482
[android]: https://github.com/jonzey231/AerioTV-Android/blob/7bf4a2ddad9dd6d58152eee5b4eee08873c1da3b/app/src/main/java/com/aeriotv/android/feature/player/DisplayFrameRateMatcher.kt#L12-L46
[device-info]: https://developer.roku.com/dev/docs/rodeviceinfo
[device-interface]: https://developer.roku.com/dev/docs/ifdeviceinfo
[video]: https://developer.roku.com/dev/docs/video
[roku-support]: https://support.roku.com/article/115012823268
[roku-forum]: https://forum.developer.roku.com/t/24fps-integer-framerate-matching/11513
[monitor-page]: https://manuals.plus/asin/B0GKGBW8HT
