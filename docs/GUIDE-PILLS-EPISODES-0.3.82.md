# Guide pill seams, overflow arrows, and episode labels

Issues: `AerioTV-Roku-lrj`, `AerioTV-Roku-5tv`, `AerioTV-Roku-z9y`.

The owner spotted a dark vertical line **inside** the focused All Channels
pill, at the join between the cyan center and its rounded right cap. On the
3820RW2, the separately rasterized center and quarter-circle mask touched
without overlap; focus scaling exposed a one-pixel background seam.
`AerioSurface.cornerOverlap` now lets **only the guide's group pills** overlap
their cap masks and center by two pixels. Other rounded surfaces retain their
prior geometry. The local before/after developer captures changed the seam
pixel at x=570, y=115 from a dark `(0, 51, 75)` to cyan `(25, 196, 216)`.
The focused pill retains its white perimeter and unchanged text/row spacing.

The group strip now shows bold, readable arrows **outside** the pills. At the
first five of 35 groups, only `>` is shown; in a middle window, `<` and `>`;
at the last five, only `<`. The numeric count remains above the strip, without
the previous misleading unconditional arrows. The indicators do not add focus
stops or change Left/Right selection. Native captures confirmed all three
windows and the first-to-last navigation on the target Roku.

In subtitle-rich Preview, an EPG episode code precedes a valid subtitle on
the same secondary line, for example `S2E9  Welcome to the Dealbreaker`.
If an episode has no subtitle, its code occupies that secondary line alone.
For a narrow tile or compact/Basic layout without a secondary line, the code
prefixes the title instead. The LIVE/NEW/time row no longer receives the
episode code. The selected-program header follows the same rule; the episode
display preference still controls whether a code appears. Native guide
captures checked both an episode subtitle and an episode-only news listing,
including tiles with flags. No provider data or server settings were changed.
With the revised candidate on the TV, the owner replied **“Much better.”**
That is visual feedback on this candidate, not publication of a new ZIP.

`npm run verify` covers the package, model and compiler checks. Unit cases
exercise cap geometry, group-window arrow boundaries, episode/subtitle
composition and compact fallback. The captures remain ignored under `out/`.
This is a **development candidate after the published v0.3.82 tag**: the
v0.3.82 GitHub ZIP does not contain these changes. The candidate is on the
Roku for the owner's visual review. After seeing the updated guide, the owner
explicitly chose to **leave this development candidate installed** rather
than restore the older published ZIP. It is not a new v0.3.82 release asset.
