# v0.3.36 testing preview

This sideloaded testing prerelease combines the metadata response-limit restoration
and VOD category filtering fixes. It is not a Roku Streaming Store release.

## Changes

- Restores the default HTTP response ceiling to **16,000,000 bytes (16 MB)**,
  matching v0.3.8, rather than the later 8 MiB limit. File-backed transfers,
  cancellation, memory-pressure protection, and task-specific limits remain.
- Oversized default-limit diagnostics report `response-too-large at-least-16-mb`;
  memory-pressure diagnostics remain distinct.
- Movies and Shows category lists require an enabled category relationship on an
  active provider with VOD enabled. Filtering occurs before display pagination
  and respects the selected provider. Provider metadata is not exposed in the
  category results.

## Correction to v0.3.35 notes

Dispatcharr 0.31.0's EPG mapping endpoint ignores `page` and `page_size`.
Restoring those query parameters in v0.3.35 did not split the response into pages.
This release restores the earlier response limit instead; it does not introduce
server-side pagination or guarantee that every catalog fits the device budget.

## Verification and remaining testing

- Automated tests cover the restored default and per-task limits, diagnostic
  labels, and VOD category filtering with five providers and ten enabled movie
  categories, disabled/inactive providers, series separation, and provider scope.
- Affected-account guide recovery and VOD category visibility still require
  physical confirmation. Remote-map, accessibility, and endurance acceptance
  also remain open.

Install **aeriotv-roku-v0.3.36.zip** from the release Assets (keep it zipped).
Do not install GitHub's generated source archive.

After installation:

1. Guide → `*` → **Refresh guide**: check whether programs populate and inspect
   Diagnostics if they do not.
2. Open Movies and Shows category lists: confirm only enabled categories from
   VOD-enabled providers appear, then open a category with known content.

ZIP SHA-256: `309f3b780ba001bc985d6b93583e9be37f0d64af25747f668e7e00ffdb0d873b`
