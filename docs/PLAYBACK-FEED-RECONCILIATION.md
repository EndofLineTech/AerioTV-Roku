# Live recovery, direct feeds, and owned HLS cleanup

## Evidence at `4733127` (development 0.3.103)

This source and local evidence review did not run Roku, contact providers, or
test a signed package. The existing exact-source full gate passed (190 host
suite markers and a verified 387-file ZIP). That gate is not device acceptance.
Beads remains the status register; the seven records below were still in
progress at this review. No observation from the ongoing native QA run is
included; use its completed report when available.

| Bead | Delivered or already qualified | Remaining evidence or scope decision |
| --- | --- | --- |
| `e3e.5.2` — received Guide options | Live native Dispatcharr imports of Guide Days `2` and `0` exercised ±2 and bounded ±30 days respectively, including later manual edits surviving reconnect. The received catch-up offset is saved per playlist; the shared playback path has live native qualification for completed Dispatcharr and UTC Xtream archives (`e3e.13`, `e3e.14`, `91wm`; details below). The independent Xtream XMLTV override is integrated (`94a8078`). Host checks cover saved import, reload and refresh; a native HTTP fixture used the production Task, matched programme data, followed a same-origin redirect without auth/cookies/Referer, failed without account-guide fallback on 503, and recovered on Retry. | The owner selected the override as the only remaining current-phase import feature and deferred automatic LAN failover; `localUrl` stays informational. The live Xtream archive tests used an explicitly seeded history-enabled XMLTV feed, **not** a phone-imported override. For live override qualification, use an authorized Xtream import with distinct programme data: verify persistence across relaunch (re-enter session-only credentials), Refresh, and reimport without the override to restore the account-guide route. Unsupported M3U offset remains disclosed. |
| `z2l` — cold playback launch timing | Cold Live and supported private Dispatcharr VOD track the exact attempt and replacement renderer, check progress/focus, and retain a bounded no-media fallback. The Radio Mode changes preserve the diagnostic check when the input target is the radio surface. A valid cold attempt now withholds `AppLaunchComplete` until its first outcome (focused advancing playback, or the usable fallback); ordinary launch, Welcome, unavailable links and warm input keep one completion. | On the exact candidate, attribute advancing playback to the requested reader across replacement/resume and exercise a real remote action. The beacon change is implemented; qualify it natively against the usable playback point, preserving one completion for ordinary launch/Welcome, safe protected cancellation/no-media fallback, and no second beacon for warm input. Dashboard/cloud evidence is separate. |
| `e19` — Roku input launch | `supports_input_launch=1`, `roInput`, account-checked live aliases, safe invalid/unsupported handling, and newer live/AAC/warm VOD arbitration are integrated. Older native runs cover malformed input and authorized cold/warm live, including the exact cloud-shaped `mediatype=live` spelling and fresh sign-in continuation. The later arbitration is host-qualified. | For current-build local acceptance, confirm authorized cold and warm Live with a competing saved mini/AAC tune, plus malformed, unsupported and unavailable input falling back safely. Reuse the historical results for their exact builds. Do not treat the known old alias rejection, an ECP HTTP 200, a skipped run or an earlier signed artifact as current Dashboard/cloud success; reviewer identity/sample and compatible rendition remain in `856`/`h99`. |
| `yud` — owned HLS disconnect | On the instrumented exact v0.3.102 release, authorized standard-user live HLS advanced on two channels; Stop and retune each produced one owner DELETE 204. Current automatic startup and midstream retry retire the prior token and wait for a fresh owned playlist; stale opens are fenced and cleaned with the captured owner in host tests. | Qualify the integrated retry/remint/error and stale/account boundaries with owner-scoped request observations and playback on a supported server. Record revision/support and TV-side picture/audio separately. The historical Home run observed no explicit close and the standard status endpoint returned 403: neither client count nor idle-reaper timing was established. Do not use admin/shared stops or promise close delivery on OS termination; the server reaper is the fallback. |
| `e3e.22` — auth and audio recovery | No automatic password re-login on API-key refusal; `mrr.14` supplies native controlled evidence for concurrent holds, 429 parks and a single eligible recheck. Bounded JSON GET retry, stock live retry budgets, current-reader Pause/Resume and stale-callback fences are distinct. Terminal native media HTTP 503 gets temporary-unavailability guidance. `e3e.11` observed advancing AAC on a declared Dispatcharr radio station; `e3e.12` used packaged AAC for foreground Radio Mode controls, not an affected provider HLS stream. | Reuse `mxz`/`ihp` for equivalent recovery, not as evidence of a new provider behavior. A channel-stopping 503 backoff in the native media reader, explicit HLS-to-TS/non-HLS transition, and affected audio-only HLS pacing/recovery are not established. Verify the affected response/format and bounded behavior where observable, or record a scoped Roku limitation; do not claim native Video receives HTTP Retry-After. |
| `w6g` — private Dispatcharr VOD links | Account-verified movie/episode/series direct play is integrated (`49917e3` and follow-ups). The resolver refreshes own identity, capabilities and details; it respects bookmark/series target selection and rejects stale, unrelated or unauthorized handoffs. Host evidence covers the route. Existing Profiles Beta VOD playback used the catalog UI, not deep links. | Use a separately approved populated Dispatcharr account to exercise each media type cold and warm, capture expected title/episode and bookmark position, and confirm direct play, Back/remote operation and a denied case without unrelated playback. Store/Search and stable reviewer samples or an explicit Roku-approved scope belong to `856`, not an inference from private IDs or playback. |
| `e3e.24` — direct providers | Custom User-Agent and bounded M3U/plain XMLTV, Xtream TS Live, bounded catalog and UTC completed archive have scoped evidence. Advertised HLS-only Xtream Live now selects `.m3u8`, while TS/both stay `.ts` (`5f9cf2b`); host routing is not native provider acceptance. Raw gzip M3U now rejects with plain-URL guidance; raw gzip XMLTV also rejects. | For support claims, qualify advertised HLS-only Live on a representative Roku/provider; separate that from catalog containers and other archive dialects. Distinguish actual HTTP Content-Encoding staging from raw gzip: native decoding for the former is unverified and raw inflation is unsupported (see [gzip boundary](DIRECT-FEED-GZIP.md)). No new LAN fallback or credential forwarding is in scope. |

For detailed local versus portal evidence see
[Roku certification prep](LOCAL-CERTIFICATION-EVIDENCE.md). The
[Profiles-only Beta acceptance](MRR-DELIVERY-STATUS.md) does not cover these
provider or certification claims. Of this batch, `e3e.5.2` can add bounded
evidence for the broader phone-provider track, and the launch/recovery work
can add platform evidence; none replaces the parent's separate peer Sync,
phone or certification criteria, or supplies explicit parent acceptance.

### Closed archive evidence relevant to `e3e.5.2`

- `e3e.13`: Live Roku playback on completed Dispatcharr and UTC Xtream
  programmes qualified the per-playlist offset. On `5601bbd`, Dispatcharr
  compared +120 seconds with zero on the same retained airing. Xtream used a
  seeded +2-minute offset that applied once across Play, Skip, Resume and
  Start Over. The sampled default Xtream XMLTV feed lacked retained airings;
  the test seeded a history-enabled XMLTV URL rather than importing it.
- `91wm`: On `7f2eb06` the native Connection editor changed −1 to +1 minute.
  Registry readback and full Roku relaunch retained +1 while a sibling playlist
  stayed at zero. A real Dispatcharr archive request was shifted by exactly
  +60 seconds, played, and closed the owned session with HTTP 204.
- `e3e.14`: Both providers passed live local Resume and Start Over for
  completed programmes. A 66-second bookmark survived full exit and cold
  relaunch (with Xtream reauthentication), reopened at provider minute 1:00
  and advanced. Start Over returned to 0:00 and cleared progress; Back restored
  the guide cell. Exact v0.3.102 restoration was verified. These results do
  not claim human picture/audio, an imported Xtream history feed, M3U or
  in-progress Restart/live rewind offset support, or cross-device Sync.

### App-side findings at `4733127` and follow-up

- `z2l`: Beacon order is a known implementation gap, not merely missing
  evidence. [`signalStartupComplete`](../components/AerioScene.brs) calls
  `completeStartupBeacons()` before `handlePendingLaunch()`. The current cold
  readiness outcome is diagnostic only. Native attribution is needed before
  wiring it to the beacon; a focused node alone is not remote operability.
- `e3e.22` / `yud` — **Historical finding, fixed and verified on the host;
  live qualification pending.** At `4733127`, HTTP 200 without a valid owned
  HLS receipt failed closed but displayed “HTTP 200” as an open failure.
  The [Scene](../components/HlsSessionLifecycle.brs) now reports that
  Dispatcharr did not provide a valid HLS session. Host checks verify fixed
  wording, no Video handoff or silent MPEG-TS fallback, and no fabricated
  token. This was a source-visible diagnostic gap, not an observed provider
  failure.
- `e3e.22` — **Historical finding, fixed and verified on the host; live
  qualification pending.** At `4733127`, a midstream `-2` could reconnect
  immediately even with explicit HTTP 503 text. The
  [midstream retry predicate](../components/LiveRecovery.brs) now routes `-2`
  with explicit 503 and channel-stopping or temporarily-unavailable detail to
  the existing wait guidance and manual Retry, with no immediate reconnect.
  Other timeout cases retain the existing bounded behavior. Host checks do
  not establish that a channel-stopping response yields that exact native
  code/text pair. No provider cause, Retry-After value, or automatic delay
  is inferred.

## Relay-observed native evidence (2026-11-22)

Roku 3820RW2 / OS 16.0.4, dev 0.3.103 private probe, approved standard
`roku` account, real H.264 720p/AAC live channel, explicit HLS transport. The
Roku reached Dispatcharr only through `scripts/hls_fault_proxy.py` on the Mac,
which logged redacted request classes and injected counted faults. No admin
endpoint, server setting or shared-channel stop was used. Cleanup and exact
v0.3.102 restore were verified after every run.

| Case | Relay sequence | Roku behavior |
| --- | --- | --- |
| Cold link, first mint 503 + `Retry-After: 3` (before fix) | `mint 503` | Failed at once; one `AppLaunchComplete` at the failure. |
| Same, with the busy-mint retry | `mint 503` → `mint 302` → playlists/segments | Waited, reminted the same attempt, advancing playback. |
| Midstream segment resets (×4) | `segment reset ×4` → `close 204` | Native reader error: one owner close, manual Retry (run 2). In run 3 the native reader absorbed the resets and kept advancing. |
| Midstream playlist 503 + `Retry-After: 2` | `playlist 503 ×2` → `close 204` | One owner close, manual Retry; the native reader does not expose Retry-After. |
| Retune, first mint 429 + `Retry-After: 4` | `mint 429` → `close 204` | Request gate parked the server; old session closed once; Guide shown, no remint. |
| Home while playing | none within 12 s | No close reaches the server; the inactive-client reaper is the fallback. |

Every error path closed only its own token, exactly once. Server-side client
counts remain admin-only and unobserved.

## Historical implementation detail (`4ee2ec8` baseline)

The host checks described below used synthetic Scene fields and `.test`
addresses. They did not start media transfers or issue provider requests.

## Live retry and pause (`e3e.22`)

- Startup retry and the single midstream reconnect retain their separate
  budgets. A midstream replacement does not get a fresh startup retry budget.
  An already paused reader is not treated as stalled. A Pause or Resume command
  issued while guarded picture recovery is waiting for its bridge now wins over
  the pause state captured before the command. Dedicated Resume (`playonly`)
  uses the same intent handling with or without the picture hidden; it can
  cancel a pending pause before Video acknowledges it.
- An API-key refusal does not trigger password re-login. The request broker
  parks on 429 and honors bounded Retry-After for requests it sees. An explicit
  Retry-After of at most 15 seconds on a 502/503 HLS session request is
  honored with up to two fresh session requests (see the relay evidence above). This is not
  a promise to observe Retry-After from the native Video reader. Native HTTP 503
  guidance says to wait, without guessing a connection limit or a retry delay.
  See [request policy](REQUEST-GATE.md) and [ordinary recovery](LIVE-RECOVERY.md).
- Existing radio fixtures verify provider-declared radio and exclude
  picture-stall recovery, including late classification before a restart. They
  do not establish audio-only HLS playback, segment pacing/remux parity, or
  automatic recovery for an unknown non-HLS redirect.

## Direct-feed boundary (`e3e.24`)

- A bounded M3U URL playlist uses direct HTTP(S) media. An explicit `.m3u8`
  **path** selects HLS (case-insensitive, including URLs with query strings).
  A matching string in a query parameter or host name no longer misclassifies a
  TS link. The existing custom User-Agent is retained without attaching a
  Dispatcharr credential to direct media.
- Existing fixtures cover M3U and windowed plain XMLTV, Xtream `.ts` live and
  the implemented catalog/archive dialects. `4ee2ec8` includes the independent
  Xtream XMLTV override (`94a8078`); the earlier crosswalk's pin predates it.
  See [direct feed evidence](DIRECT-FEED-FEASIBILITY.md) and
  [Xtream adapter](XTREAM-MEDIA-ADAPTER.md).
- These checks do not qualify raw gzip files, HLS-only Xtream, other dialects,
  or provider behavior with custom headers. HTTP transport decoding and raw
  `.xml.gz` are different; raw XMLTV gzip remains explicitly rejected. LAN/WAN
  failover remains deferred and the imported LAN URL is informational.

## Owned Dispatcharr live HLS (`yud`)

- Stop, retune, and terminal failure retire this client's captured token.
  Automatic startup or midstream retry now queues one bounded close for the
  previous token and separately mints from the original entry URL (including
  its selected audio profile). Video waits for the replacement capability.
  A replacement can ignore one immediate `finished` before Video reports
  progress; later finishes and startup errors still go through normal failure
  handling, and a reader that stays stopped still has a bounded watchdog.
  A late successful mint is closed with its captured owner and cannot replace
  the current reader. These are app-side assertions, not observations of new
  HTTP 204 responses. The request gate can still decline a close.
- Pause and minimize do not close the current session. A guarded picture
  recovery is a local decoder restart against the same owned capability,
  not a new tune. It cannot open a pending mint entry, even from an already
  open Options menu, and an owned bridge uses only the current profile's
  captured playlist and owner credentials. No shared-channel or other-client
  stop is sent.
- [Historical native evidence](UPLOAD-CANDIDATE-0.3.95.md) covers a compatible
  test server, native `playing`, and owner DELETE 204 on explicit retune/Stop.
  It does not qualify the new remint flow on-device, TV-side picture/audio,
  current deployed-server support, provider client counts, or signed release.
  Roku Home belongs to the OS. If the app is terminated or connectivity is lost,
  delivery of a close is not guaranteed; the compatible server's idle reaper
  remains the fallback. A queued close is not a zero-client or
  single-client-at-every-instant guarantee.
