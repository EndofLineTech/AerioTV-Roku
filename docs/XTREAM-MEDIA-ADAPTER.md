# Xtream media adapter (development, scripted Roku evidence)

The existing Movies / TV Shows library now accepts a session-only Xtream
connection. It requests `get_vod_categories` or `get_series_categories` first;
selecting a category requests **only** `get_vod_streams&category_id=...` or
`get_series&category_id=...`. The Task caps each response at 4 MiB, category
lists at 1,600 entries, and a selected category at 600 titles. Its 20-item
pages and title search are local to that category. An oversized response
fails visibly rather than requesting the complete catalog. Series details and
episodes come from `get_series_info&series_id=...`; movie details use
`get_vod_info&vod_id=...`. A single oversized series detail also fails closed.

The adapter normalizes movie, series, season-zero and episode identities in
the connection's own account scope. XC responses and remote artwork URLs are
not copied into saved state. Credentials remain in memory for the active
connection, are cleared from each completed Task, and are used to construct
same-server `/movie/` or `/series/` playback URLs only when a title is played.
The live connection checks the account's movie and series category endpoints
before showing either library tab; missing, denied or oversized category
responses leave that tab disabled without blocking live TV. Its existing XMLTV
URL is also a volatile credential-bearing URL and is never saved to the roster.
Native VOD uses the existing on-demand player for recognized MP4, MKV or TS
containers. The separate Dispatcharr source-picker, provider info Tasks, DVR,
and saved-library shelves are not invoked from the XC library. The XC account
timezone and advertised per-channel archive days are normalized. XC
archive controls use the completed-programme XC path only on UTC servers with
advertised retention. The Roku reopens a remaining minute-window URL to seek,
preserving pause and allowing Go Live to return to the current channel. The
pinned Dispatcharr 0.31 source supports XC path and query timeshift routes;
the Roku probe verified the path redirect and native TS playback. In-progress
programme restart is deliberately disabled until proved.

Model/Task tests and `npm run verify` exercise bounds, ID validation, shape
normalization, credential-redacted outputs and the build. After the Product
Owner re-supplied the session-only Xtream credentials, read-only requests
against the live 0.31 server returned an active account, 841 movie categories,
648 series categories, a 467-movie first category (~256 KB), and a 7-series
first category (~15 KB). One movie detail (~1.5 KB) and one series detail
(~91 KB, 30 episodes) succeeded. All sampled category IDs and first-category
title IDs/names passed the adapter's bounds; the sampled series had supported
season keys and MKV episodes. These are backend contract checks, **not** Roku
execution or proof that every category fits the budget. No catalog payload,
private URL, credentials or title was retained in the repository.

After developer access was provided, a disposable, credential-bearing package
built solely under ignored `out/` exercised the existing VOD UI and native
on-demand Video on the 3820RW2 / Roku OS 15.3.4. It loaded the movie categories
(841; 20 visible), selected a category (467 titles; 20 visible), opened one
movie detail, and played its MKV in the shared player with a positive, advancing
native position. A separate series pass loaded 648 categories, 7 titles in the
selected category, 30 episodes (20 visible), a series detail and an episode
detail; its MKV likewise reported `playing` with advancing position. The probe
did not exercise every category, container or provider rendition. It bypassed
registry writes and the normal connection picker; this is a scripted VOD UI and
transport check, not full physical-remote acceptance. The normal verified build
was reinstalled afterward, and the credential-bearing probe ZIP was deleted.
The reproducible builder and template are
`scripts/build-xtream-vod-probe.py` and `tests/native/XtreamVodProbe.brs`, neither
of which contains credentials.

The later XC archive probe used a completed, advertised provider programme:
TS state was playing with advancing position, a 120-second reopen seek played
again, pause survived another seek, and Go Live returned to a playing live
stream. The subsequent normal package reinstall succeeded; the ignored
credential-bearing archive ZIP was deleted. Restricted-account fixtures,
provider-specific error/redirect variants, unusual Range/container cases,
and actual picture/audio remain separate acceptance limitations under the
appropriate story and `ah5.13`.
