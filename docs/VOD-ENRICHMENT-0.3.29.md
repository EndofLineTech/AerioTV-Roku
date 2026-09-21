# VOD enrichment and saved-library reconciliation — 0.3.29

Development increment after the published 0.3.28 testing prerelease. This is not
a new public release. Work is tracked under
`AerioTV-Roku-l4j`; the epic still requires Product Owner review.

## Changes

- Rich movie, series and episode details: artwork/fallback, provider facts,
  optional English TMDB overview, rating/runtime, cast/crew and attribution.
  Play/Resume remains the first action; enrichment is asynchronous and does not
  recreate the focused action list. Long synopses have bounded, paginated views.
- Account-specific **Settings > General > Optional TMDB VOD enrichment** toggle,
  off by default. Configure the existing device TMDB API key through **Guide
  options > Guide settings > Optional TMDB artwork fallback > Test and save**.
  The configured key is runtime registry data, not part of the package.
- Cast/crew, person filmography and related-title navigation. Playable results
  must match the current permitted Dispatcharr catalog and exclude hidden titles.
  Ambiguous title/year matches are omitted. TMDB failure leaves provider details
  usable; missing provider/TMDB metadata is still possible.
- Visible Movies, TV Shows, Continue, Watchlist, Hidden and Categories tabs.
  Guide search now offers permitted movie and TV-show scopes alongside program
  title/description search. VOD searches execute on submission, not each keypress.
- Fresh authorization and exact item-identity verification for saved shelves.
  Missing titles leave removable Watchlist/Hidden placeholders and disappear
  from Continue Watching. Denied entries are suppressed. Temporary failures
  retain previously authorized state with a retry indication. Reconciliation
  merges availability into current account state without overwriting progress
  or resurrecting entries removed during a request.
- Resume eligibility uses the saved native duration, rather than potentially
  incorrect provider runtime units. Playback still checks the real rendition's
  duration and explains an unavailable saved position.

## Bounds and authentication

Catalog pages and UI tiles remain bounded at 20. Saved state remains limited to
20 entries inside the existing account preference budget. Shelf requests have a
30-second total deadline, three-second per-request timeout and 1 MiB reads.
No full-catalog scan or new runtime service is introduced.

TMDB tasks use a 30-second deadline, five-second requests and 1 MiB reads. Details
reuse the existing bounded account/authorization/metadata-identity cache.
Discovery has a four-level return stack; people are capped at 30, filmography at
200 combined credits, and catalog matching at ten suggestions per page. Budget
exhaustion is displayed with a Refresh instruction; these are partial discovery
results, not an exhaustive filmography index.

Dispatcharr requests and same-origin artwork use `X-API-Key`. TMDB requests clear
that key before leaving the server origin. TMDB image Posters use a separate
uncredentialed HTTP agent and validated image paths. No provider playback URLs
or account credentials are included in this document or native fixture output.

## Recorded native evidence

Target: Streaming Stick 4K 3820RW2, Roku OS 15.3.4, Dispatcharr 0.31.0. Native
fixtures used production Tasks, detail actions, source selection and player.
These are scripted device checks, not physical-remote acceptance.

| Check | Observation |
| --- | --- |
| The Matrix detail | English overview 181 characters, 22 people, TMDB attribution, first-action focus preserved |
| Cast/person/related | 20 people on first page; ten permitted person matches; ten related matches; Back restored people page |
| Deep Space Nine series | English overview 244 characters, 11 people, attribution |
| Episode detail | 20 episodes loaded; selected episode overview 486 characters, ten people, artwork ready |
| Saved Watchlist | Valid episode plus synthetic missing movie: two entries, one unavailable placeholder, no task error |
| Continue Watching | Same fixture: one valid entry, zero missing entries, no task error |
| Resume through rich detail | Source 19 Matroska selected through UI; Resume offered; request 120 seconds, observed 119.077, native duration 8,293 seconds |
| Global movie search | Guide request opened library KeyboardDialog; library exposed six tabs |

Rich-detail screenshots were inspected locally; fixture screenshots remain in
ignored `out/`. Early playback probe attempts failed with network/MP4 demux
errors; later explicit Matroska runs succeeded. Those failures are not a claim
that every source rendition works. The fixture snapshot now waits for the
detail Task as well as metadata Tasks to avoid reading an old open dialog.

## Playback-speed feasibility

The target's native Video has a `playbackSpeed` field and no `playbackRate` field.
Measured on the working Matrix Matroska rendition:

- Normal playback: 13.013 media seconds over 12.997 elapsed seconds.
- Immediately after pause/set 1.5/resume: 37.204 media seconds over 12 seconds.
- Subsequent steady 1.5 interval: 19.686 media seconds over 12.997 elapsed seconds.
- Last rendered audio/video timestamps in that steady interval: 188.954/188.980
  seconds (26 ms difference).

The steady rate is genuinely faster playback, but the transition unexpectedly
jumps forward. Sample timestamps are not a listening test. **No playback-speed
selector ships in this increment; normal playback remains the adaptation.**
`l4j.13` retains the transition investigation and Product Owner review. Native
seek/trickplay must not be described as continuous playback-speed support.

## Verification and remaining acceptance

Automated coverage adds TMDB model/task and saved-shelf task suites to the
existing regression runner (47 suites). Tests cover opt-out, auth changes,
changed UUIDs, credential separation, hidden recommendations, missing/denied
shelf entries, temporary failures, cancellation and preservation of saved state.
Use `npm test`, `npm run check`, and `npm run build`.

Final normal 0.3.29 validation: all 47 suites, compiler check, build and
`git diff --check` passed. The package contains 124 entries and excludes native
fixtures, tests and tooling. Normal installation succeeded and loaded the
authorized 1,122-channel lineup in 1,858 ms; probe startup hooks were removed.

Native fixtures are retained in `tests/native/VodEnrichmentProbe.brs` and
`tests/native/VodProbeHelpers.brs`; neither is included in the normal package.
To reproduce, temporarily import the Scene fixture/call its installer and
import/export the helper functions in VodView. Optional manifest fixture values
are `vod_enrichment_kind`, `vod_enrichment_query`, `vod_enrichment_tmdb`; defaults
are movie/The Matrix/603. Series verification uses series/Deep Space Nine/580.
Remove all fixture imports, exports, installer calls and manifest keys afterward.
Supply developer credentials through the native runner's environment.

On 2026-09-21 the PO reported "Not filling it out, all pass." This accepts all
12 physical checks N01-N12 in `PHYSICAL-VOD-0.3.29.txt`. Unprovided setup details,
timings and screenshots have not been inferred. This acceptance does not resolve
alphabet navigation or the playback-speed transition investigation.

Physical checks for this increment are in `PHYSICAL-VOD-0.3.29.txt`; the existing
50-PASS 0.3.28 worksheet is preserved. Alphabet navigation remains in `l4j.9`:
Dispatcharr supports paginated title/year/recent ordering, but no prefix filter
or rating ordering. No invented backend filter or whole-library client sort is
advertised. Provider 6's upstream 405 remains the separate `l4j.16` follow-up.
