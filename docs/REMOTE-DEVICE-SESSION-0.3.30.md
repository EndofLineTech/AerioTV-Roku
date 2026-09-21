# Remote device session - 0.3.30

Date: 2026-09-21. This is remote launch/stability evidence only, not physical
remote, picture/audio, playback, or accessibility acceptance.

## Target

- Roku Streaming Stick 4K, model `3820RW2`.
- Roku OS `15.3.4`, build `2402`, 1080p.
- Device uptime before the session was 213,961 seconds.

## Results

1. `npm run verify` passed all model/controller suites, package-tool test,
   compiler validation, build, and ZIP inspection.
2. The normal `0.3.30` ZIP installed successfully through Developer Mode. Native
   console emitted the Roku launcher marker for AerioTV and no selected compile or
   runtime error before launch.
3. ECP `/query/active-app` reported the Developer Mode app as AerioTV Roku Preview,
   version `0.3.30`.
4. A passive 30-second developer-console observation emitted no selected native
   error, syntax-error, or launcher marker after installation.
5. Post-launch uptime was 214,583 seconds; the follow-up sample was 214,608
   seconds. The increasing uptime does not indicate a device restart during the
   observed interval.

## Limits

- ECP screenshot returned HTTP 404 on this device; no screenshot was captured and
  no policy/configuration was changed to obtain one.
- This device's ECP input policy does not permit remote key injection. No setup,
  guide, playback, focus, Audio Guide, picture, audio, or caption behavior was
  exercised remotely.
- The short passive observation is not the `rgs.6` sustained resource/endurance
  measurement or the `rgs.13` soak acceptance. Use the uptime procedure in
  `NATIVE-DEVICE-WORKFLOW.md` when a longer controlled run is available.
