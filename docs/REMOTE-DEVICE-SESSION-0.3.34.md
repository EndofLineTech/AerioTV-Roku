# Remote device session - 0.3.34

Date: 2026-09-21. This is controlled package install and launch evidence only, not
physical remote, guide-data, picture/audio, accessibility, or endurance acceptance.

## Target

- Roku Streaming Stick 4K, model `3820RW2`.
- Roku OS `15.3.4`, build `2402`, 1080p.
- Device uptime before installation: 236477 seconds.

## Results

1. `npm run release:prepare` passed BrightScript suites, package-tool tests,
   compiler validation, package inspection, and release ZIP generation.
2. `aeriotv-roku-v0.3.34.zip` passed `SHA256SUMS` verification and installed
   successfully through Developer Mode. Native console emitted the AerioTV
   launcher marker.
3. ECP `/query/active-app` reported AerioTV Roku Preview, version `0.3.34`.
4. Post-launch uptime was 236482 seconds. The increasing value does not indicate a
   device restart during the observed interval.

## Limits

- ECP screenshot is unavailable on this target and remote key injection remains
  restricted. No policy or configuration was changed.
- Physical confirmation of the affected-account guide diagnostic category,
  remote-map acceptance, Audio Guide/visual review, and sustained
  resource/stability testing remain open.
