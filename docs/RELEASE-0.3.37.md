# v0.3.37 testing preview

This sideloaded prerelease delivers the physically accepted Player and Guide
remote-map repairs. Download **aeriotv-roku-v0.3.37.zip** from the release Assets,
keep it zipped, and install through Roku Developer Mode. GitHub's generated source
archive is not the installable application.

## Remote control fixes

- All four Player directions execute the offered actions. Left/Right can perform
  held channel switching; Up/Down can execute non-channel actions.
- Guide Left short actions run on release, independently of the hold assignment.
  Disabled hold actions consume repeats/releases without triggering short actions.
- Player Hold OK set to Do nothing no longer retriggers short OK on native repeats.
- Saving or resetting a map takes effect immediately in the Guide; failed writes
  restore the prior effective map.
- Compact on-screen hints match the selected actions and contextual controls.
- Open groups opens the visible picker in Modal layout, or the group navigator
  in Pills/Sidebar. Back recovery and Roku-owned Home/fullscreen `*` are preserved.

## Acceptance

- Physical remote-map worksheet **RM01–RM10: all PASS** on the installed development
  candidate containing these repairs. Automated controller tests cover the offered
  actions, hold/release guards, paging bounds, hints, and persistence rollback.
- Existing **S01–S06 PASS** results were reconciled with the implemented settings
  stories. Blank detailed measurement fields have not been filled by inference.
- Includes the **16,000,000-byte response limit** restoration and **enabled VOD
  category filtering** from v0.3.36, both confirmed working by the affected user.

## Scope

This remains a testing prerelease, not a Roku Streaming Store release or completion
of the broader quality/accessibility roadmap. New-release notifications remain a
backlog feature; updates continue to require manual sideloading.

ZIP SHA-256: `d52cefbd0a44b51253415699dc798ab3066215be45ba2c2270e0360e095fc4ab`
