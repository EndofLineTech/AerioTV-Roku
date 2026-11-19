# Live recovery, direct feeds, and owned HLS cleanup

This reconciles `e3e.22`, `e3e.24`, and `yud` against committed `4ee2ec8`.
The new checks run on the host with synthetic Scene fields and `.test` addresses;
they do not start media transfers or issue provider requests.

## Live retry and pause (`e3e.22`)

- Startup retry and the single midstream reconnect retain their separate
  budgets. A midstream replacement does not get a fresh startup retry budget.
  An already paused reader is not treated as stalled. A Pause or Resume command
  issued while guarded picture recovery is waiting for its bridge now wins over
  the pause state captured before the command. Dedicated Resume (`playonly`)
  uses the same intent handling with or without the picture hidden; it can
  cancel a pending pause before Video acknowledges it.
- An API-key refusal does not trigger password re-login. The request broker
  parks on 429 and honors bounded Retry-After for requests it sees. This is not
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
