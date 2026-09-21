# v0.3.34 testing preview

`v0.3.34` is a sideloaded Roku testing prerelease. It is not a Roku Streaming
Store release.

## EPG mapping diagnostics

- Guide mapping diagnostics now distinguish an oversized metadata response from
  Roku memory pressure during the metadata download.
- Oversized-response diagnostics report only a fixed threshold bucket, such as
  `at-least-8-mib`; they do not record response content, exact byte counts,
  server URLs, channel identifiers, or credentials.
- The v0.3.33 direct guide-ID fallback remains: available guide data can load
  when the optional EPG-link mapping request cannot complete.

## Testing scope

- Install `aeriotv-roku-v0.3.34.zip` through Roku Developer Mode. Do not install
  GitHub's generated source archive.
- On an affected account, choose Guide, press `*`, and select Refresh guide.
  Then open Diagnostics and capture the sanitized `mapping` event.
- Physical remote-map, affected-account guide, picture/audio, accessibility,
  resource, and endurance acceptance remain open.

ZIP SHA-256: `34495555111782807fb7ee1885939eef50d4029ac9e0f9daba37917b0724f809`
