# AerioTV source artwork

`aeriotv-tvos-icon.png` is the Apple TV App Store icon back layer from
`jonzey231/AerioTV`, pinned at
`8d5818456e0f4421d93b8ff120ad878d63331091`:

```text
SupportingFiles/Assets.xcassets/App Icon & Top Shelf Image.brandassets/
App Icon - App Store.imagestack/Back.imagestacklayer/Content.imageset/
icon-lg-back-2x.png
```

The Front, Middle and Back PNGs at that revision are identical Git blobs
(`87ecec5c042366797947490efd0830ad07c6536d`), so no parallax-layer compositing
is required for Roku's flat launcher image.

Copyright (C) 2026 Logan Jones and contributors. GPL-3.0-or-later, under the
[upstream license](https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/LICENSE).
The AerioTV name/artwork identifies the upstream project; this Roku testing port
is independently maintained and does not imply upstream endorsement.

Generated Roku PNGs are committed under `images/`. To regenerate them, run
`python3 scripts/generate-branding.py` with Pillow installed (generated with
Pillow 11.3.0). Normal application builds use the committed PNGs and do not need
Python/Pillow. This source directory is not included in the sideload ZIP.
