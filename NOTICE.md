# Attribution

This development Roku port is based on the design and behavior of AerioTV:
https://github.com/jonzey231/AerioTV

Upstream copyright: Copyright (C) 2026 Logan Jones and contributors.
Upstream license: GNU GPL version 3 or later.
Reference commit: 8d5818456e0f4421d93b8ff120ad878d63331091.

The initial port uses theme colors and provider-contract knowledge from the
upstream Swift sources. SwiftUI, MPVKit, FFmpeg, Google Cast SDK, Apple fonts,
and upstream screenshots are not included in this development channel. Roku
supplies its native system fonts and player.

Launcher and splash artwork is adapted from the upstream Apple TV App Store
icon at the reference commit above, under GPL-3.0-or-later. The original image,
provenance and reproducible conversion script are included in the source tree
(`images/upstream/` and `scripts/generate-branding.py`). The Roku adaptation
resizes without distorting/cropping the wordmark and pads to Roku's image sizes.

The AerioTV name identifies the port's upstream project. This is an independent
development preview, not an official release by the upstream author.

Optional TMDB artwork fallback uses the TMDB API but is not endorsed or certified
by TMDB. The bundled TMDB logo is TMDB's mark, used under its attribution/branding
guidance, separately from the application code license. Source and conversion
information are in images/README.md. https://www.themoviedb.org/about/logos-attribution
