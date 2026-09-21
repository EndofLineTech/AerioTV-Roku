# Remote device session - 0.3.31

Date: 2026-09-21. This is controlled install and launch evidence only, not physical
remote, picture/audio, guide-data, playback, or accessibility acceptance.

## Target

- Roku Streaming Stick 4K, model `3820RW2`.
- Roku OS `15.3.4`, build `2402`, 1080p.
- Device uptime before installation: 231966 seconds.

## Results

1. `npm ci` and `npm run release:prepare` passed. The release ZIP passed its
   `SHA256SUMS` integrity check.
2. `aeriotv-roku-v0.3.31.zip` installed successfully through Developer Mode. Native
   console emitted the Roku launcher marker for AerioTV.
3. ECP `/query/active-app` reported AerioTV Roku Preview, version `0.3.31`.
4. The post-launch uptime was 231971 seconds. The increasing value does not indicate
   a device restart during the observed interval.

## Limits

- ECP screenshot returned HTTP 404 on this device in the prior remote session; no
  policy or configuration was changed to obtain one.
- This device's ECP input policy does not permit remote key injection. No setup,
  guide, playback, focus, Audio Guide, picture, audio, or caption behavior was
  exercised remotely.
- This short launch check is not the `rgs.6` sustained resource/endurance
  measurement or `rgs.13` soak acceptance. Use the uptime procedure in
  `NATIVE-DEVICE-WORKFLOW.md` during a longer controlled physical run.
