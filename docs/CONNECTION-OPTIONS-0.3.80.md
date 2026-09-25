# Connection profiles and request identity (0.3.80 candidate)

The Dispatcharr setup screen now lists a channel profile. With an authenticated
API key, the viewer can request only the server profiles permitted for that
account. The selected ID stays in the non-secret connection roster. At each
connection or lineup refresh, the Task checks membership against the freshly
authorized summary; a missing/removed profile or failed membership request
stops the connection instead of silently showing the full lineup. An empty
permitted profile remains empty. Guide cache scopes distinguish profile IDs;
account reminders/history for a different profile are retained rather than
pruned as deleted channels. Source: Dispatcharr 0.31 `ChannelProfileViewSet` and
`ChannelProfileSerializer`, which return permitted profiles with enabled
channel IDs for an authenticated account.

Manage saved connections > Request identity and header settings offers a
bounded ASCII User-Agent override for each connection, plus Dispatcharr API
key header choices: X-API-Key only (the safe default), an explicit compatible
dual-header option, and Authorization: ApiKey only. On the target Roku, the
supplied API key returned HTTP 400 with dual or Authorization-only headers but
loaded the 921-channel guide using X-API-Key alone. Python read-only probes
returned 200 for the alternate headers. A 0.3.80 connection Task that sees
HTTP 400 on a verified alternate-mode GET attempts **one** X-API-Key retry to
the same configured origin, then records the working mode if successful. No
mutation or cross-origin fallback is made. On the 0.3.80 native candidate,
Authorization-only was rejected, the single X-API-Key fallback opened the
921-channel guide, and the connection manager then showed X-API-Key as the
saved mode. The test key remained session-only; Roku Home ended the session.
Dispatcharr 0.31 uses Bearer for a
short-lived **JWT**, not for its API keys; the UI does not offer a misleading
Bearer API-key mode. API Tasks, Guide/Player/VOD/DVR artwork and direct-feed
downloads receive the configured agent/header choice. The media proxy may
forward Authorization to upstream sources; playback and on-demand sessions
retain X-API-Key where needed, even if API calls use Authorization: ApiKey.

`ChannelProfileModel.test.brs` checks empty/missing/malformed memberships and
that filtering cannot expand the server-authorized summary.
`ConnectionAuthTask.test.brs` checks failed membership loads do not publish an
unfiltered lineup. `DispatcharrModel.test.brs` checks header selection and
User-Agent injection bounds. On native 0.3.77, a direct M3U slot's custom
User-Agent saved and survived relaunch, then was restored to the default
through the connection manager. Direct guide loading still succeeded. With an
authorized session-only API key, the native profile picker listed seven
permitted profiles. The server-authorized default displayed 921 channels;
selecting another permitted profile narrowed the same account to 163 and
restored its own guide, without adding channels outside the authorized
summary. Returning to the default cleared the selected profile in the roster
across a Home/relaunch. No key or private screenshot is included here.

## PO connection-scope closure — 2026-09-25

The PO closed the `ah5` epic and all its children for the current Roku scope.
This is an explicit acceptance of bounded delivered paths and a retirement of
unfinished criteria, **not** a physical PASS for every connection. Named
connections, permitted Dispatcharr profiles, header selection, direct M3U and
Xtream flows, plain XMLTV, and explicit re-login have engineering evidence.
Local/WAN reachability switching was not delivered; raw `.xml.gz` is rejected;
real revoked/rotated-key and final per-path remote/picture/sound checks were
not recorded. `docs/PHYSICAL-RELEASE-0.3.80.txt` remains unmarked for those
paths. The separately discovered, non-reproduced roster-loss investigation
`AerioTV-Roku-itx` is **not** a child of `ah5` and remains open.
