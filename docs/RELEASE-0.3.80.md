# v0.3.80 — Roku testing prerelease

This GitHub **prerelease** is a Developer Mode sideload ZIP for testing on the
Streaming Stick 4K 3820RW2 / Roku OS 15.3.4 against Dispatcharr 0.31.0. It is
not a Roku Streaming Store release, proof of full Apple/Android parity, or a
physical-remote/audio acceptance result for the current build. The Product Owner
authorized publishing with the known P1 issues below still open.

Download **`aeriotv-roku-v0.3.80.zip`** from the release Assets and install the
ZIP without extracting it. GitHub's automatically generated source archives
are not installable Roku packages. `SHA256SUMS` provides the expected checksum.

## Since v0.3.37

- Account-scoped, named Dispatcharr connections (at most four roster slots),
  optional authorized channel profile, explicit API-key header choice and
  re-login on rejected credentials. Direct URL M3U/XMLTV and session-only
  Xtream live, VOD and advertised completed archive routes have bounded tasks
  and scoped credentials. The default Dispatcharr guide is preserved.
- Dispatcharr **server** DVR UI: schedule/manage authorized recordings and
  series rules, browse recorded/scheduled items and play completed/supported
  growing media with guarded native resume. No local recording service is
  introduced.
- Source-informed styling: pills, colored guide badges, rounded controls,
  poster-led VOD, appearance/text preferences, compact Basic/Preview guide
  geometry, focus/remote hint refinements and a first-run welcome screen.
  Existing remote mapping and single-channel MPEG-TS playback paths remain.
- The current development documentation includes the [native multiview
  investigation](MULTIVIEW-NATIVE-RESEARCH.md); **no multiview player/control is
  included**. The target-model two-view platform lead does not constitute an
  AerioTV `roMultiDecode` SDK integration.

## Verification and acceptance boundary

- `npm run release:prepare` passed model/Task tests, package-tool tests,
  compiler, build and package inspection (184-file Roku ZIP). `npm audit
  --omit=dev --audit-level=high` reported zero production vulnerabilities.
- The **versioned release ZIP** installed and launched on the target 3820RW2 /
  OS 15.3.4; read-only ECP reported active development app version **0.3.80**.
  This confirms launch, not moving picture, sound, remote focus or speech.
- Prior physically marked results belong to their recorded earlier builds.
  The [v0.3.80 physical worksheet](PHYSICAL-RELEASE-0.3.80.txt) is blank;
  existing `docs/MORNING-EPIC-ACCEPTANCE.txt` F01–F06, V01–V05, D01–D06
  and the connection-path follow-up `ah5.13` are **not marked PASS for
  v0.3.80**. Record fresh target-TV observations after installation;
  conditional checks may be SKIP if no authorized fixture exists.

## Known limitations accepted for this testing prerelease

- **Basic guide (`AerioTV-Roku-ige`, P1):** source and model-test fixes for
  settings routing and compact geometry are present, but physical F02/F03
  (ten nonoverlapping Basic rows, immediate visibility switches and persistence)
  remain unmarked on the current build. Do not infer their visual acceptance.
- **Audio Guide (`AerioTV-Roku-zvi`, P1):** a prior physical listen heard Roku
  system menus but no custom guide speech. A logged speech call/ID does not
  prove spoken output. Keep this FAIL/pending until a fresh physical listen.
- **Direct XMLTV (`ah5.9`):** native file-backed bounded parsing works for
  tested plain XML. True raw `.xml.gz` and compressed-provider variants are not
  established; an oversized or unsupported feed fails within the existing
  resource bounds. Do not change shared feeds to manufacture a test.
- **Connections (`ah5.3`, `ah5.6`, `ah5.13`):** actual revoked/rotated account
  device cases, automatic local/WAN switching and final physical connection
  picture/sound/remote checks remain open. Session-only Xtream passwords are
  never remembered.
- **VOD (`l4j`):** provider/version playback depends on authorized working
  renditions. Missing English synopses, complete alphabet/rating navigation,
  conditional deleted/restricted saved titles and final physical checks remain
  open. The upstream provider-405 fault (`l4j.16`) is a separate server/provider
  issue; selecting another rendition does not fix that provider.
- **Playback speed and multiview:** no speed selector ships after an unexplained
  transition jump; no concurrent-stream layout ships while Roku `roMultiDecode`
  access and a two-stream hardware proof remain pending. Do not treat another
  service's two-view support as proof this app can already use the SDK.

No credentials, private stream URLs, media labels, raw server responses or
unredacted screenshots are part of this release or its public evidence. Track
remaining work in Beads; the Product Owner reviews epics separately.

ZIP SHA-256: `302aee79acaf1eb4285715abc3e3b470c5205ad05ecb2d65855523bdce531833`
