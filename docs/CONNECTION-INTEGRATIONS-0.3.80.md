# Connection integrations: engineering evidence on 0.3.80 development build

The existing Dispatcharr API, direct URL M3U/XMLTV, and session-only Xtream
connections share account-scoped guide and media views. These provider outputs
are exports of the same server; **do not re-import them into Dispatcharr**.
The normal Dispatcharr API guide remains the default. A Dispatcharr slot may
opt into an external XMLTV URL; this uses the feed's channel-number IDs,
skips server-specific programme detail lookups, invalidates that connection's
guide generation, and never sends its API key to the XMLTV endpoint. Removing
the URL restores the server guide. A URL change clears the old guide override.
The playlist and guide URLs are scoped to their selected connection; automatic
switching between two addresses for one server is the separate `ah5.6` story.

Direct M3U setup uses a URL instead of an Apple Files picker or a new runtime
service. A separate optional XMLTV URL and a bounded, credential-free origin
Referer can be configured for its playlist, guide and media requests. Existing
per-connection User-Agent applies to the same requests. The Referer cannot
contain a path, query, userinfo or control characters; changing the playlist
URL clears it. Provider passwords and signed feed/query URLs are not stored
in the roster; unsupported URLs fail validation explicitly. M3U does not
invent VOD or Dispatcharr DVR abilities.

On the Streaming Stick 4K / Roku OS 15.3.4, isolated read-only scene probes
loaded 921 live M3U entries in 31 groups and matched the first channel to a
current XMLTV programme. The probe with a non-secret origin Referer enabled
also passed. A second probe used the **same M3U-derived channel fixture** under
the opt-in `dispatcharr` guide override path and matched a programme. This
proves the native XMLTV Task and override routing. With a separate
session-only Dispatcharr API key, the native account/summary Task also verified
921 permitted channels in 31 groups. Its opt-in XMLTV override matched a
programme for the first channel; another isolated run with the override blank
matched the normal Dispatcharr API guide for the same account and lineup.
These were read-only server requests and ephemeral native scenes: the probe
did not change a saved connection or exercise physical setup focus.
Prior scripted native direct M3U live MPEG-TS had advancing player position;
physical picture/sound acceptance remains `ah5.13`.

The live Xtream account on that Roku loaded 921 channels, verified both VOD
category permissions, and kept its username/password in session memory only.
An intentionally rejected login produced re-login; a pre-cancelled Task
published no result and cleared its password. The source advertises 258
archive-capable channels with one to three days' retention, and its server
timezone is UTC. One authorized per-channel EPG query returned completed
programmes marked archived. Non-UTC timestamps fail closed on this adapter;
unadvertised or expired history cannot be requested.

Xtream movie, series, episode and supported archive media share the native
on-demand player. Disposable Roku probes loaded bounded VOD category/detail
pages and reported MKV playback with advancing position for a movie and an
episode. A completed advertised TS archive also reported advancing playback,
a 120-second whole-minute reopen seek, pause preserved across that seek, and
Go Live returned to an active live stream. The archive probe injected an
authorized channel/programme request into the real Scene and tested the same
seek/Go Live handlers; it did not verify physical remote focus or A/V. Current
programme restart remains disabled for direct Xtream until proven.

The probe builders/templates are `scripts/build-m3u-guide-probe.py`,
`scripts/build-xtream-vod-probe.py`, `scripts/build-xtream-archive-probe.py`,
and `tests/native/*Probe.brs`. They carry no credentials in source. Each
disposable ZIP was assembled only under ignored `out/`, replaced on the Roku
with the normal verified package, and deleted afterward. No server source,
profile or channel was edited. `npm run verify` covers model/Task regressions,
the compiler and package; see `docs/XTREAM-MEDIA-ADAPTER.md` for catalog bounds.

Not claimed: a second restricted Xtream account or every provider error,
redirect, container and range variant; unsupported signed/raw-gzip feed
variants (`ah5.9`); automatic alternate-origin selection (`ah5.6`); and
Product Owner physical picture/audio/remote verification on the final build
(`ah5.13`).
