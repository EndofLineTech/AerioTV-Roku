# Completed-program archive acceptance — 34y

Prerequisite `ah5.4` is also reconciled: `CapabilityTask`/`CapabilityModel` provide
identity-checked snapshots, explicit unknown/denied values, periodic refresh and
channel catch-up-day facts. Their existing regression/native evidence is supplemented
by PO H01/H03/H05/H07/H08 and F01/F05 PASS. This closes that prerequisite, not the
broader accounts/provider epic; it does not convert A08/E13 SKIP into PASS.

The PO's marked0.3.17 worksheet records **F01-F10 PASS**, with related permissions,
cancellation and cleanup in H05/H07-H09 and J02/J03. Combined with the native
session/reader/seek evidence in `MEDIA-BLOCKER-FIXES-0.3.17.md`, this closes the
previously pending completed-program archive foundation:

| Story | Acceptance basis |
| --- | --- |
| 34y.2 Device feasibility | POST201, native `ts` playback, minute-window forward/back, DELETE204; physical F02/F03/F06/F07 and J02 |
| 34y.3 Session lifecycle | F02/F04/F09/F10, H05/H07-H09, J02/J03; identity/ownership/cancel regressions and native cleanup |
| 34y.4 Guide launch/gating | F01/F02/F04/F05: shared advertised-retention gate, exact archived identity, explicit Watch LIVE, focus restoration |
| 34y.5 Seek/position/expiry | F03/F06-F10: bounded minute offsets, pause preservation, cancelled/failed seeks and expiry explanation; native POST position / owner DELETE contract |

Retained boundaries: provider archives may be missing or delayed; the first-byte
handshake is60 seconds and active-session idle TTL10 minutes in inspected0.31
source. Native duration may remain unknown. This is server-window reopening, not
frame-accurate native TS scrubbing, and it never promises a locally retained hour.
Other-client continuity comes from the PO checks, not from an assumed zero-client
baseline in an earlier fixture.

This does **not** accept currently airing-program restart, a rolling rewind window,
retention across channels, or all of34y.13's delayed-mode/program-rollover scope.
Those remain separately tracked. The34y epic stays open.
