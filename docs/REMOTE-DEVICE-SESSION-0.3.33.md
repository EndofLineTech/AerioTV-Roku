# Remote device session - 0.3.33

Date: 2026-09-21. This is controlled package install and launch evidence only, not
physical remote, guide-data, picture/audio, accessibility, or endurance acceptance.

## Target

- Roku Streaming Stick 4K, model `3820RW2`.
- Roku OS `15.3.4`, build `2402`, 1080p.
- Device uptime before installation: 235787 seconds.

## Results

1. `npm run release:prepare` passed all BrightScript suites, package-tool tests,
   compiler validation, package inspection, and release ZIP generation.
2. `aeriotv-roku-v0.3.33.zip` installed successfully through Developer Mode. Native
   console emitted the AerioTV launcher marker.
3. ECP `/query/active-app` reported AerioTV Roku Preview, version `0.3.33`.
4. Post-launch uptime was 235792 seconds. The increasing value does not indicate a
   device restart during the observed interval.

## Limits

- ECP screenshot is unavailable on this target and remote key injection remains
  restricted. No policy or configuration was changed.
- Physical remote-map acceptance, affected-account guide fallback validation,
  Audio Guide/visual review, and sustained resource/stability testing remain open.
