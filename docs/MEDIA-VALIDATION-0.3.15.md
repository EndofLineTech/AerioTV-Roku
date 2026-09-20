# 0.3.15 media and diagnostics evidence

Development work across `mxz`, `34y`, and `l4j`; **not epic acceptance**.
Target: Streaming Stick 4K 3820RW2, OS 15.3.4, Dispatcharr 0.31.0.
Measurements below were collected on 2026-09-20 UTC. The server lineup/catalog
changed during the session; counts are observations rather than constants.

## Delivered surfaces

- Guide options → **Movies / TV Shows**, gated by refreshed capabilities and the
  local connection's VOD toggle.
- A bounded 20-tile library, paging, submitted server search, category filtering,
  title/newest/year sorting, details, and season/episode-ordered browsing.
- Native on-demand playback distinct from live TV; source container selection,
  sanitized error/Retry UI, bounded buffering, and saved progress/curation.
- Continue Watching, Watchlist and Hidden titles; watched/unwatched actions;
  account-scoped browse bookmarks and local VOD enable/disable.
- Completed-program archive action in program details under the same advertised
  retention/permission gate as its archive badge; separate session, pinned title,
  pause/resume, owner cleanup, no silent live fallback.
- Guide options → **Diagnostics**: session-only events, at most 80 / 32 KiB,
  one-hour expiry, paging, clear, sanitized JSON export to developer console.
  This uses the existing navigation rather than waiting for the future Settings
  hub; the obsolete placement dependency on `b17.2` was removed.

## Native transport results

### Movie

An initial MP4-reader attempt failed with `-5 / MP4: no playable tracks`. The
provider-info contract identified **Matroska**. Using that reader for the sampled
*The Matrix (1999)* copy reached `playing`, duration **8,178 seconds**. A seek to
60 seconds buffered, then resumed and reached **68.111 seconds** after pause/resume.

The production integration subsequently reached **80.624 seconds** after a seek
and persisted a resume value of **80**. That does **not** establish working resume:
an immediate new-session resume returned HTTP 500. A request pinned to the metadata
provider also returned HTTP 500, so pinning is **not proven causal**. A later seek
buffered until the 45-second deadline. These failures are tracked in `l4j.14`.
Auto remains the default; same-title transport reuse and post-start resume seeking
are implemented, but successful native resume is still an acceptance gap.

The integration fixture observed **84 fixed library child nodes** and a peak
app-memory sample of **17%** in a run that included a failed resume. It is not an
endurance result or a provider-session-count proof. Test progress was restored
after the fixture.

### Episode

A *Breaking Bad* provider-info response supplied an episode and Matroska container.
Opening it failed before playback with **-3 / CurlUrlReader: read zero**. This is
tracked in `l4j.15`; it does not prove a general codec problem or working episode
playback. No repeated provider experiments were used to manufacture a pass.

### Completed archive

The native fixture found **266 channels advertising catch-up**. The first sampled
archive session returned **201**, but its media URL returned **404**; deletion
returned **204**. The next sample, an ESPN-matching channel, returned **201**,
opened as MPEG-TS and reported `playing`. Native duration was **-1**.

Setting seek to 60 briefly reported 60, but playback then reported **16.516**,
not a committed 60-second playhead. Pause/resume worked, ending at **22.522** before
Stop. Session deletion again returned **204**. Archive seek is therefore disabled
and tracked by `34y.15`, which blocks `34y.5`. In-progress restart, retained rewind
and their Product Owner decisions remain separate gates.

The fixture requested a five-minute sample starting two hours earlier. This
establishes transport/session feasibility, not complete program alignment across
every provider. Real guide-selection/picture/audio acceptance remains pending.

## Native library/diagnostics UI smoke

`tests/native/LibrarySmoke.brs` called actual component handlers:

- Movies page 1: **20 / 147,794**; Right then Down selected index **6**.
- Next page: page **2**, **20** rows, focus reset to index 0.
- Category browser: **20 / 1,344**.
- Selecting the first category loaded **20 / 1,184** matching titles.
- Library menu and diagnostics Dialog nodes were created; diagnostics had five
  buttons. Export callback ran and Clear left zero prior events in that sample.

The first UI attempt exposed a real native `Dialog.wasClosed` signal with an
invalid payload, causing a boolean type mismatch. Handlers now treat it as a
signal and validate sender identity; the corrected UI smoke passed. The same fix
was applied to playback-failure dismissal and its regression test.

A later details smoke found that arrays read from a native SceneGraph field are
not necessarily resizable: appending to `Dialog.buttons` silently failed. Button
and action arrays are now built together in a pure model and assigned once.
The corrected repeat observed **20 / 120,296** movies (the catalog changed),
restored index **6**, moved to **12**, opened a **five-button details dialog**, and
returned with the library **in the focus chain**. Paging, categories (**1,344**),
the selected category (**1,168** titles), the **11-button library menu**, diagnostics
export and clear all completed without runtime errors. The changed initial index
also exercised the persisted browse bookmark. Failed fixture attempts are not
counted as successful UI evidence.

This is scripted handler/field evidence, not physical remote or visual acceptance.
Later permission-fingerprint/bookmark/toggle hardening has automated and build
coverage; it is explicitly included in the consolidated physical worksheet.

## Automated checks and outstanding scope

**37 suites**, compiler validation and build checks pass. Added checks cover
mode/clock separation, bounded catalog normalization, URL ownership, cache-safe
metadata, progress thresholds/caps/permission changes, session cancellation and
revocation, diagnostic redaction/expiry/caps, and error-followed-by-finished and
uncommitted-seek regressions. Off-device tests are not a Roku emulator.

No production probe/autoplay hooks remain. Installable transport fixtures are
under `tests/media-probe`; native app fixtures remain under `tests/native` and are
excluded from the normal package.

Outstanding work is still tracked, including physical checks, VOD range/resume and
episode reliability, complete deletion reconciliation, provider/alphabet controls,
TMDB/person discovery, explicit provider versions/links, playback-speed evidence,
and the gated restart/rewind work. No epic is closed by this checkpoint.
