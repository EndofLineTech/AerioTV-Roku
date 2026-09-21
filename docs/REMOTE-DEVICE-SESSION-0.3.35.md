# Remote device session - 0.3.35

Date: 2026-09-21. This is controlled package install and launch evidence only, not
affected-account guide, physical remote, picture/audio, accessibility, or endurance
acceptance.

## Target

- Roku Streaming Stick 4K, model `3820RW2`.
- Roku OS `15.3.4`, build `2402`, 1080p.
- Device uptime before installation: 238180 seconds.

## Results

1. `npm run release:prepare` passed BrightScript suites, package-tool tests,
   compiler validation, package inspection, and release ZIP generation.
2. `aeriotv-roku-v0.3.35.zip` passed `SHA256SUMS` verification and installed
   successfully through Developer Mode. Native console emitted the AerioTV
   launcher marker.
3. ECP `/query/active-app` reported AerioTV Roku Preview, version `0.3.35`.
4. Post-launch uptime was 238184 seconds. The increasing value does not indicate a
   device restart during the observed interval.

## Limits

- ECP screenshot is unavailable on this target and remote key injection remains
  restricted. No policy or configuration was changed.
- The affected-account Guide refresh is the required validation for the restored
  paged mapping request. Physical remote-map, Audio Guide/visual review, and
  sustained resource/stability testing remain open.
