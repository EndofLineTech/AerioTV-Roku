# Xtream channel logos — developer candidate, 2026-11-11

Bead: `AerioTV-Roku-7cd`.

The previous live Xtream adapter discarded `stream_icon`; every normalized
channel had an empty `logoId`. Guide/Channels/banner therefore had no artwork
source. This is separate from the older Dispatcharr later-row issue `o7b`.

The adapter now keeps a validated, **volatile** `logoUrl`, separate from the
numeric Dispatcharr proxy ID. Only bounded absolute HTTP(S) URLs without userinfo,
fragments, whitespace/control characters or backslashes are accepted. Query bytes
are preserved exactly; the app never inserts Xtream credentials into image URLs.
URLs are not written to saved connections or metadata-cache payloads. Files use
sanitized channel identities, not URLs or query tokens, in their names.

Guide, Channels and player banner reuse `LogoCacheTask`: at most two transfers,
2 MiB per image, a twenty-second batch budget, PNG/JPEG/WebP signature checks,
temporary files and cooperative cancellation/cleanup. Guide/Channels retain their
existing bounded caches; the banner retains only its current remote image. Account
changes release the browser model/URL map/cache and banner task/file. Dispatcharr's
authenticated numeric-ID proxy remains unchanged.

Remote artwork transfers use a generic agent and **no provider API key,
Authorization, cookies or provider-specific User-Agent**. An explicitly empty
Referer suppresses Roku's native automatic redirect referrer: the first native
negative test caught a non-empty referrer on a redirect before this suppression.
The verified rerun observes none. No TLS verification is disabled.

## Evidence and limits

- `npm run verify` passes on the owner working tree (0.3.100) and an isolated
  committed-source snapshot plus this fix (0.3.97), without the owner's unrelated
  cache/version edits. URL/header/cache-key/model regressions pass.
- Native loopback probe uses the real downloader, GuideView, ChannelBrowser and
  PlayerInfo. It verifies direct + redirected PNG, unchanged authenticated proxy,
  and rejection of a non-image, a 2-MiB-plus-one-byte body and HTTP 404. First six
  and later six visible guide logos, eight browser logos and the banner decode
  from actual `tmp:` downloads. Packaged catch-up icons and hidden Posters do
  **not** count. Browser release is exercised before the banner phase.
- Native image requests carry no provider auth, private agent or non-empty
  Referer. Synthetic query bytes arrive intact. Evidence:
  `out/channel-logo-native-results.json`.
- The normal five-check full-app pairing smoke passes with the updated candidate.
  The broader discovery cleanup smoke still intermittently misses receipt/cancel
  removal despite recorded goodbye/socket-stop stages; it is **not claimed green**
  and remains tracked under `AerioTV-Roku-e3e.2.9.1`. Fresh Bonjour browse/TXT/IPv4
  resolution and active QR were checked separately at final handoff.
- Real owner Xtream logos require sending the playlist again after reinstall.
  No real provider credentials/images were used in the synthetic probe and no
  saved connection was added, replaced or deleted by these tests. M3U `tvg-logo`
  and Xtream VOD artwork are not part of this fix.

Reproduce the isolated native check (macOS, developer environment supplied):

```sh
npm run verify
python3 scripts/build-channel-logo-probe.py
node scripts/test-channel-logo-native.mjs out/channel-logo-probe.zip \
  out/pairing-tests/discovery/aeriotv-roku-v0.3.100-pairing-test.zip
```

The probe creates no application scene/registry, binds its fixture to loopback
only, redirects metadata storage to private `tmp:` and restores a checksum-pinned
developer app in `finally`. Shipping guards reject its probe marker; an automated
isolation test covers that guard. Never sign or distribute the probe as the app.

## Updated full app

`out/pairing-tests/xtream-logos/aeriotv-roku-v0.3.100-pairing-test.zip`

SHA256: `16d9055585eefc12b2720e71188c0c5fc4d38dea00d9f7c60df2530883a88f66`.

This retains working phone discovery and the visible, security-unqualified
device-key entropy warning. It is not a signed Beta/Store package; default
production setup still fails closed. The previous discovery candidate is preserved
in its separate directory. See [PAIRING-TEST-BUILD.md](PAIRING-TEST-BUILD.md).
