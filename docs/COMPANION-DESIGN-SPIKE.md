# Phone companion design spike (e3e.9 / e3e.10)

Design for owner review, 2026-11-23. No code. Builds on the source-only
findings in [Companion feasibility](COMPANION-RETAINED-LIVE-FEASIBILITY.md#e3e9--a-native-socket-path-exists-companion-parity-is-unproven)
and the shipped phone-setup receiver ([pairing build](PAIRING-TEST-BUILD.md)).
Multiview and composite casting are out of scope.

## 1. What the phone apps expect (pinned wire)

From Apple `AerioCastController.swift` at `fe7ad4c` (Android sender source was
not available locally; its recognition is **unverified** and is a dependency):

| Step | Wire |
| --- | --- |
| Discovery | mDNS `_aeriotv._tcp`, TXT `v=1`, stable `id` (instance-name fallback) |
| Transport | `ws://<resolved host>:<port>/remote`, JSON text frames, no TLS |
| Hello | TV sends `hello` on connect |
| Auth | phone sends `auth` with the six-digit TV code **or** a remembered token; TV replies `authOk` (with token) or `authFail` |
| Commands | `setChannel` (`channelId: "disp:<uuid>"`), play / pause / toggle, `stop`, disconnect |
| Feedback | `cmd: state` on change, `position` about 1 Hz, only to authenticated peers |

Behaviors to respect: `Disconnect` leaves the TV playing; `stop` ends playback.
iOS sends `setChannel` right after `authOk` and stops its own playback without
waiting for the TV to confirm the tune.

## 2. Proposed Roku architecture

```
AerioScene (render thread)          CompanionTask (Task thread)
  Settings: Phone remote On/Off  ->   roStreamSocket listener (ephemeral port)
  pairing code overlay           <-   HTTP Upgrade -> RFC 6455 framing
  startPlayback / stop / pause   <-   validated command fields
  playback state, position       ->   state / position frames
                                      mDNS advert (_aeriotv._tcp) via roDataGramSocket
```

- **Separate service.** A new `CompanionTask`, never sharing state, port or
  advert with the one-shot `_aeriotv-setup._tcp` receiver.
- **Opt-in, foreground only.** Default **Off** (Settings → Phone remote). The
  listener and advert run only while AerioTV is running with the setting on;
  Roku has no background service, so Home/exit ends companion control. On
  teardown, send a TTL-zero goodbye and close every socket.
- **WebSocket by hand.** No Roku server WebSocket or TLS API was found. The
  handshake needs `Sec-WebSocket-Accept = base64(SHA-1(key + GUID))`
  (`roEVPDigest` SHA-1 and `roByteArray.toBase64String`). Frames: masked
  client text frames only; reject binary, unmasked, over-cap or fragmented
  frames beyond a small reassembly cap; answer ping; honor close.
- **Hard caps (start values, measure before raising):** one pending plus one
  authenticated socket; 16 KB per message; 8 queued outbound frames (drop
  `position` first); handshake 5 s, auth 30 s, idle 60 s with ping; reject a
  browser `Origin`.
- **Command path.** The Task only parses and validates. It writes a bounded
  command into a Scene field tagged with the current user session (the same
  `userViewEvent`/`userEventCurrent` guard used elsewhere). The Scene rechecks
  profile, lock and permissions immediately before acting.

## 3. Pairing and security

- **Code:** the TV shows a six-digit code only when the user opens "Pair a
  phone". Code rotates after each wrong attempt; five failures per minute lock
  pairing for one minute. Nothing about playback (no `nowPlaying`) is sent
  before `authOk`.
- **Token:** issued on success, 128 bits, from the same device-key-conditioned
  source as phone setup. That source works natively but carries **no vendor
  entropy guarantee** (e3e.2.5 closed as non-blocking). The owner should
  confirm this disposition also covers long-lived companion tokens.
- **Storage:** only a hash of each token, bound to the phone `id`, the
  connection and the Roku profile, with a 30-day idle expiry. Settings lists
  paired phones; **Forget** revokes the stored token **and** closes its live
  socket. Profile switch, profile lock and account change close sessions; a
  token never crosses profiles.
- **Transport risk:** the pinned client sends the code and token over
  plaintext `ws://`. Anyone on the LAN can sniff a token and replay it, and
  the phone cannot authenticate the TV. Two options:
  - **A. Trusted-LAN v1:** ship plaintext with an explicit disclosure,
    opt-in default Off, short expiry, revocation, and control limited to
    tune/pause/stop of channels the active profile can already watch.
  - **B. Protected protocol:** agree with upstream to wrap each message in the
    existing setup crypto (X25519 key agreement, HKDF, AES-GCM, keyed by the
    pairing code). This needs sender changes on iOS and Android.
  - **Recommendation:** B as the target. A only if the owner accepts the LAN
    risk for a beta, and only after Store/security review.

## 4. Single-stream handoff

- `setChannel` with `disp:<uuid>` is resolved against the **current unlocked
  profile's authorized Dispatcharr lineup**, then played through the normal
  TS (or verified HLS) path. URLs, credentials and media bytes never travel
  from the phone. Xtream/M3U identifiers are unsupported in v1 (no mapping).
- Replies: `state` with `playing` and the channel, or an error state for
  unknown, denied or failed tunes. Because iOS hands off before confirmation,
  a failed tune leaves nothing playing; request an upstream `tuneResult`
  acknowledgement (sender dependency) before claiming seamless handoff.
- The local remote stays authoritative. Its changes are reported to the phone;
  the phone cannot override a PIN, a locked profile or a Child restriction.
- Stop vs Disconnect follow the upstream semantics above.

## 5. Decisions for the owner

1. Security path: **B** (upstream protected protocol) or **A** (plaintext,
   trusted-LAN beta with disclosure)?
2. Does the e3e.2.5 entropy disposition extend to long-lived companion tokens?
3. Default: Phone remote **Off** until enabled in Settings (proposed)?
4. Scope of v1 commands: tune, play/pause, stop only (proposed), or also
   channel up/down and volume?
5. Who contacts upstream for the sender changes (tune acknowledgement, optional
   protected envelope, Android recognition)?

## 6. Plan if approved

| Phase | Work | Evidence |
| --- | --- | --- |
| 1 | Host-tested pure modules: HTTP upgrade, frame codec, command validator, pairing state machine | Fixtures: fragmented/masked/oversized frames, bad Origin, replay, lockout |
| 2 | Native probe: Task listener plus advert on an isolated registry | Mac Bonjour browse and a WebSocket client; caps; teardown; Home/screensaver |
| 3 | Scene integration behind the default-Off setting | Tune/pause/stop, allowed/missing/denied UUIDs, profile switch and lock revocation |
| 4 | Real phones | iOS and Android discovery, pair, reconnect, revoke; Stop vs Disconnect; truthful state |

Main risks: hand-written WebSocket correctness and memory on low-end Roku
models; Store review of a LAN listener; upstream availability for sender
changes; Android recognition is unknown until its sender source is reviewed.
