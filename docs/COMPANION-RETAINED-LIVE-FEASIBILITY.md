# Roku companion and retained live feasibility

Source-only checkpoint for `AerioTV-Roku-e3e.9` and `AerioTV-Roku-e3e.16`,
based on Roku `d678797` and local pinned upstream sources. No new device,
phone, network or provider tests. No feature or shipping decision.

## e3e.9 — A native socket path exists; companion parity is unproven

- **Proven substrate:** [`PhoneSetupTask.brs`](../components/PhoneSetupTask.brs)
  owns an ephemeral `roStreamSocket` listener in a Task; [`PhoneSetupMdnsSocket.brs`](../source/PhoneSetupMdnsSocket.brs)
  uses `roDataGramSocket` for IPv4 mDNS. The [setup probe record](PAIRING-TEST-BUILD.md#bonjour-discovery-checks--2026-11-11)
  shows a real Mac Bonjour browse and resolution followed by HTTP to the
  discovered Roku. Receipt, cancellation and expiry removed the setup advert;
  the Mac `NWConnection` attempt did not establish a connection. This updates
  the substrate assessment in [Cross-device scope](CROSS-DEVICE-SCOPE.md#i02--companion-feasibility),
  not the companion result. `_aeriotv-setup._tcp` is a separate, one-shot
  credential-transfer service. ECP/SSDP is OS control, not this peer transport.
- **Pinned wire:** Apple [`AerioCastController.swift` at `fe7ad4c`](https://github.com/jonzey231/AerioTV/blob/fe7ad4c1968a193efb7a55d68b2b3bd32d03b17a/App/AerioCastController.swift#L2208-L2910)
  browses `_aeriotv._tcp`, uses TXT `id` (instance-name fallback), and opens
  `ws://<resolved host>:<port>/remote`. The [host](https://github.com/jonzey231/AerioTV/blob/fe7ad4c1968a193efb7a55d68b2b3bd32d03b17a/App/AerioCastController.swift#L6378-L6916)
  advertises `v=1` and stable `id`; sends JSON `hello`; accepts `auth` with a
  six-digit TV code or remembered token; answers `authOk`/`authFail`. Only
  authenticated peers get controls and `cmd: state` / roughly 1 Hz `position`
  feedback. The inspected hello can expose `nowPlaying` before auth; Roku
  should omit it. Do not advertise `multiview` support. The local webOS
  crosswalk (`docs/webos-capability-options.md` in the sibling repo) names
  [Android `CompanionProtocol.kt` at `de9389f`](https://github.com/jonzey231/AerioTV-Android/blob/de9389f2661d3e2b142c10f5b9595213468c1bfb/app/src/main/java/com/aeriotv/android/core/cast/companion/CompanionProtocol.kt),
  but the Android companion sender source was not available locally. Android
  recognition remains unverified.
- **Single-stream candidate:** `{"cmd":"setChannel","channelId":"disp:<uuid>"}`.
  Send identity, not media bytes, credentials or a URL; resolve against the
  current unlocked Roku profile's authorized Dispatcharr lineup, recheck the
  session immediately before dispatch ([profile/session helpers](../source/TaskSupport.brs)),
  then use the normal TS (or verified HLS) player. No Xtream/M3U identifier
  mapping is established. iOS currently sends
  `setChannel` on `authOk` and stops local playback without waiting for the TV
  to tune; it only adopts nonempty channel IDs from feedback. If failed tunes,
  reconnect or idle/Stop cannot be represented correctly, require an upstream
  sender change for tune confirmation/state clearing rather than claiming
  transparent handoff. `Disconnect` leaves the TV playing; `stop` ends playback.
- **Recommended next gate, if authorized:** an isolated foreground Task using
  raw TCP for the WebSocket server, with a separate mDNS advert. No Roku server
  WebSocket/TLS API was established by this review. Native TCP/UDP support does
  not imply valid WebSocket framing, Store approval, or secure transport. The
  pinned client sends bearer material over plaintext `ws://`; a paired session
  is not confidential or authenticated to the phone against LAN interception.
  Require security/Store review for a trusted-LAN-only v1, or agree a protected
  protocol with upstream first (sender dependency). Setup's entropy disposition
  is not approval for companion token generation, storage or lifetime.

**Later acceptance:** Pin Roku model/OS and real iOS/Android app builds; prove
visible discovery, address/port resolution and WebSocket upgrade from both
peers on LAN, including rename, IP change, foreground/Home/sleep/screensaver
and teardown (TTL-zero plus closed socket; stale adverts cannot control).
Use host fixtures and the native probe for fragmented TCP/WS messages, valid
masking/control frames and ping/close, malformed/oversized input, rejected
browser Origin, idle and slow peers, and pre-auth rejection. Start with at most
one pending and one authenticated socket; record fixed frame, queue, timeout
and global pairing-attempt caps plus memory/latency under load before raising
limits. Verify explicit TV pairing, wrong-code rotation, remembered reconnect,
revocation of both stored token and active socket, and no old commands/feedback
after profile/account change or lock. Test allowed, missing and denied UUIDs,
existing playback, play/pause/toggle, Stop vs Disconnect, local remote changes
and real picture/sound with truthful current state on the phone. Verify failed
tune/reconnect behavior before relying on the sender to relinquish playback.

## e3e.16 — Keep the cap at zero inactive ingests

- **What parity actually means:** upstream [LiveChannelRetention at `fe7ad4c`](https://github.com/jonzey231/AerioTV/blob/fe7ad4c1968a193efb7a55d68b2b3bd32d03b17a/App/TSHLSRemuxer.swift#L4692-L4890)
  hands a running TS remux ingest and its rewind window back on retune; direct
  HLS instead keeps a muted `AVPlayer` running without its layer. No displayed
  second picture does not mean no reader/decoder. Upstream defaults to two
  channels **including active** and caps at five; these are not Roku budgets.
- **What Roku has:** [`startPlayback`/`stopPlayback`](../components/AerioScene.brs)
  stop the live Video and relinquish owned HLS on replacement/Stop.
  [`openLiveRewind`](../components/MediaNavigation.brs) stops live before
  opening provider catch-up, bounded by the current tune epoch and one hour.
  A new tune starts a new range; recent-channel metadata does not keep media.
  The [native TS hour test](REWIND-ARCHITECTURE.md#native-hour-experiment)
  recorded ~19% app memory and a failed 3,600-second reverse seek on one
  3820RW2 / OS 15.3.4. At 1 Mbps an hour requires ~450 MB before overhead
  versus ~271–289 MB available in that run. [Prior evaluation](RECENT-CHANNEL-REWIND-EVALUATION.md)
  measured single-reader cleanup, not capacity alongside another viewer.
- **Server boundary:** Dispatcharr 0.31 TS/fMP4 expose no historical seek
  offset into the live proxy buffer. In the separate local [HLS reference
  `e8ee959`](https://github.com/Dispatcharr/Dispatcharr/tree/e8ee959f5c21e5c68f4382815e768c84d6755309/apps/proxy/live_proxy/output/hls),
  `manager.py` defaults to ten 4-second segments, `views.py` serves a shared
  per-channel/format rolling playlist and `client_manager.py` calls an HLS
  client ghost after three missed segment intervals by default (not a wall-clock
  deletion guarantee). A token owns a client, **not** a private history window;
  keeping or polling it does not preserve arbitrary elapsed content. Its
  owner-only DELETE stops that client, not the shared channel. The Roku
  [README](../README.md#live-playback-transport) records entry HTTP 410 on the tested HLS
  server path, not a proven live-HLS baseline. Provider catch-up is a separate
  authorized archive request, not an inactive live ingest.

**Later acceptance:** Require an independently supported, decoder-free history
path before opening any second client. Specify source, time/byte/bitrate limits
and provider quota first; no extra service, hidden downloader, second Video,
or shared server configuration change. Start with one active and **at most one**
inactive on an isolated fixture, comparing against a zero-inactive baseline.
Use timecoded content: A → B → A must actually play A from while B was active;
check eviction with a third tune, aged-out seek, Go Live and tune-to-picture/audio
latency. Measure peak and sustained app memory/available KB, bytes and bitrate,
decoder count, server client IDs, upstream provider slots and history coverage
at baseline, cap and longest proposed duration. Check cleanup on Stop, Back,
Home/exit or power loss, EOF/error, outage, delayed completion, and profile/account
switch. Keep an independent baseline viewer playing and confirm only test clients
are released; measure server reaper time when explicit cleanup cannot run. Record
per-source results (Dispatcharr TS, verified HLS, archive-eligible/ineligible,
direct HLS/TS where applicable); no source inherits another's result. If no
supported path produces history across the switch within measured caps, leave
retention unsupported and keep the existing provider-rewind behavior distinct.
