# v0.3.35 testing preview

`v0.3.35` is a sideloaded Roku testing prerelease. It is not a Roku Streaming
Store release.

## Guide mapping repair

- Restores the paged EPG-link request used by `v0.3.8`: 500 assignments per
  request instead of one unbounded metadata response.
- Explicit channel assignments again receive the provider's authoritative mapped
  guide key. The direct-ID fallback remains only for channels where it is valid.
- Completed oversized transfers now retain the sanitized fixed threshold bucket
  for Diagnostics, such as `at-least-8-mib`.

## Testing scope

- Install `aeriotv-roku-v0.3.35.zip` through Roku Developer Mode. Do not install
  GitHub's generated source archive.
- On the affected account, choose Guide, press `*`, and select Refresh guide.
  Confirm whether programs appear, then inspect the sanitized Diagnostics events.
- Physical remote-map, picture/audio, accessibility, resource, and endurance
  acceptance remain open.

ZIP SHA-256: `d175a2f83a47c42fe94c13ae447ad1a6bb79b724926d5893358852ae5affadf9`
