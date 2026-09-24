# Direct live connections (0.3.76 development candidate)

The viewer may select a session-only Dispatcharr API connection, a direct URL
M3U connection with optional XMLTV URL, or a direct Xtream connection. The
existing Dispatcharr connection remains the full-featured DVR/VOD/catch-up
path; direct feeds offer live TV and local preferences. Connection records
contain no password or raw playlist. Direct M3U URLs with userinfo/query
secrets are rejected. Xtream credentials are entered for the active session
and are not persisted; the XMLTV and playback URLs derived from them are
volatile. See [credential policy](CONNECTION-CREDENTIAL-POLICY.md).

The supplied same-server M3U/EPG exports were checked read-only; they were
not imported back into the server. On the Streaming Stick 4K, build 0.3.75
loaded the direct M3U lineup and an XMLTV-backed guide, then opened native
MPEG-TS playback. Roku ECP reported active TS playback with advancing position;
Back returned to the guide and Home released the stream. An initial tune
hit an uninitialized mini-player flag; it was corrected and the second tune
had no captured runtime error. Developer screenshots omit the video plane,
so actual picture/audio remain a physical-check item.

The uncompressed XMLTV export was about 61 MB. A Task-thread native probe
downloaded it to temporary storage and read fixed-size slices. The current
three-hour window indexed 1,751 programmes across 953 M3U channels in 17
seconds; subsequent samples varied as the server lineup/guide changed. The
normal app loads and caches per-window normalized programme data, not the raw
feed. Multiple adjacent windows still require their own bounded transfer;
load latency, cancellation, resource use, gzip variants, and signed feed URLs
remain verification work. No private screenshots, URLs or media names are
committed.

An isolated native probe confirmed raw `.xml.gz` magic is rejected before text
parsing; transparent HTTP `Content-Encoding: gzip` is enabled through Roku's
transfer API, but the supplied XMLTV fixture is uncompressed.

On the 0.3.76 native candidate, the same-server Xtream endpoint accepted an
authorized session-only login, loaded its live categories/channels, displayed
an XMLTV-backed grid, and opened a native TS stream. Roku ECP reported the
player active with position advancing and no captured Scene runtime error.
Home closed the media stream; relaunch retained only the Xtream server slot,
with both username and password fields empty. These are scripted device checks,
not physical picture/audio confirmation. Xtream credentials and any returned
password-bearing URLs remain out of the committed evidence.

Switching from the signed-in Xtream view to the saved M3U slot restored its
own playlist/guide URL without copying any Xtream credential or prior guide
rows. The M3U guide then repopulated on demand. Xtream uses the server's
compact channel numbering; M3U preserves its own `tvg-chno` values. The two
surfaces intentionally have distinct account/cache identities.
