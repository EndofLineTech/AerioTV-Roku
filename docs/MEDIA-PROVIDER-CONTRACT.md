# Media/provider contracts — development 0.3.15

The current provider is Dispatcharr **0.31.0**. These are normalized boundaries
for the Roku implementation, not a claim that Xtream/M3U adapters already exist.
Source inspection is pinned to the upstream `v0.31.0` tag.

## Identity and clocks

`MediaSessionModel.brs` separates:

- account and playback-request identity;
- `live`, `delayed`, `catchup`, `vod`, or explicitly unknown mode;
- broadcast UTC (`programStart`) from native media position/duration in seconds;
- verified seek bounds from mere duration, with unknown/unavailable states;
- pause, stop, and live-edge status.

Pausing does not invent a rewind window or convert schedule time into media time.
Retuning replaces identity; stopping removes position/bounds. Live playback and
the separate on-demand player use the shared model. Archive title/start identity
stays pinned rather than following the current broadcast schedule.

## Provider operations

| Operation | Dispatcharr contract | Client boundary |
| --- | --- | --- |
| Identity/capabilities | `/api/accounts/users/me/` | Fresh identity checked before catalog/cache restoration and session creation |
| Channel/group/program | Existing summary, groups, grid and program APIs | Existing normalized guide models; no replacement of accepted live behavior |
| Movies/series | `/api/vod/movies/`, `/api/vod/series/` | One requested page of 20; supported search/name/category/year/ordering parameters |
| Episodes | `/api/vod/episodes/?series=ID` | Paged, ordered by season/episode; does not fetch the entire episode catalog |
| Categories | `/api/vod/categories/?category_type=...` | Handles paginated or bounded unpaged responses; renders 20 at a time |
| Details | Item endpoint, then bounded `provider-info` where needed | Normalized facts/container only; raw provider accounts/credentials never reach the render thread |
| VOD media | `/proxy/vod/{movie|episode}/{uuid}/{session}` | Same-origin constructed URL; Auto provider selection; retain the last own transport session for same-account/same-item reopen |
| Catch-up creation | `POST /api/catchup/sessions/` | Channel UUID, UTC start, integer duration **minutes**; one mutation attempt |
| Catch-up position | `POST .../{id}/position/` | Position **seconds** and paused state; telemetry/TTL, not a seek command |
| Catch-up cleanup | `DELETE .../{id}/` | Only the session returned to this client, under its original account credentials |

Movie/episode IDs and UUIDs are distinct. Saved identity includes media kind and
UUID inside the existing account preference scope. A fresh detail request validates
the selected item before playback. Source/provider URLs and raw relation payloads
are not durable client metadata.

## Bounds and cancellation

- VOD requests: 1-MiB pre-parse cap, 15-second individual request budget and
  30-second Task budget. HTTP staging limitations are described separately in
  `HTTP-RELIABILITY.md`; these are not hard network-byte quotas.
- Only 20 catalog rows enter the reusable 20-tile view. Catalog size does not
  determine render-node count. Unpaged category/episode-enrichment responses still
  face the byte cap; oversized enrichment falls back to available facts/manual
  container choice.
- Cache normalized catalog pages under the existing global 8-MiB / 64-file policy.
  Fresh authorization and a permission fingerprint precede cache reads. Five-minute
  freshness is checked on access; Refresh explicitly bypasses that page's cache.
  There is no periodic whole-library download.
- Task observers are detached and cancellation requested on replacement/exit.
  Old Tasks suppress publication. Playback/curation actions carry account scope;
  late events from another connection are rejected.
- Catch-up creation checks cancellation before mutation. A cancelled successful
  creation is revoked. Invalid returned playback URLs are rejected and the minted
  session is cleaned up when its identifier is valid. Unknown-result timeouts rely
  on the server's unused-session expiry; no blind POST retry is made.
- Session mutation waits are bounded to 15 seconds. Back/retune performs best-effort
  owner-scoped deletion. Home/process death closes the native media connection;
  server grace/TTL cleanup applies, without a claim that a DELETE always runs.

## Storage and permissions

The existing account preference store retains at most **20 VOD state entries**
(progress, watchlist, hidden/watched flags), plus small movie/series browse
bookmarks. Its existing **24-KB overall budget** still applies. No catalog or
playback URL is put in the registry. Failed VOD-state writes retain previous
preferences and report the failure.

Progress is sampled at meaningful intervals and on clean close. Only playing or
paused samples are committed; a buffering seek target is not progress. Completion
is native EOF or 95%; Resume requires at least 30 seconds and sufficient remaining
duration. Play from beginning resets progress. Continue Watching groups retained
episodes by series and excludes hidden/watched entries.

Saved shelves are reauthorized before display. Permission fingerprints suppress
entries after permission changes until a fresh detail interaction revalidates them.
Hidden series also hide retained episodes; Reset hidden list provides a way to
remove those local exclusions. Missing titles can still be reported by a detail
request; full background catalog-deletion reconciliation is not implemented.

VOD enable/disable is local to the connected server/account, exposed from Guide
options. The backend's movie/series permissions remain authoritative. This is not
an editor for Dispatcharr's provider-account configuration.

## Intentional transport distinction

Live retains verified MPEG-TS and its accepted recovery/remote contract. Finite
VOD uses its supplied container (Matroska and MP4 are separate readers), native
transport controls, and no live-ended reconnect loop. Unknown containers require
an explicit MP4/Matroska choice instead of silently assuming an extension.

Catch-up MPEG-TS opened successfully but reported unknown duration and did not
sustain a requested seek. It therefore has pause/resume and return-to-guide/live
selection, with trickplay disabled. No 60-minute rewind or universal Restart
Program capability is implied. See `MEDIA-VALIDATION-0.3.15.md` and `34y.15`.
