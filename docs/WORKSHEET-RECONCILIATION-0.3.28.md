# Worksheet reconciliation — 0.3.28

Reviewed 2026-09-21 for `AerioTV-Roku-25t`. **One fillable output:**
`PHYSICAL-TESTING-REMAINING.txt` (50 entries). This document is an evidence index,
not another results sheet or issue tracker. Beads remains authoritative.

## Rules used

- Read all21 current text worksheets in full, including inline caveats and notes,
  plus the checkbox sections and acceptance history in `DEVICE-VALIDATION.md`.
- Later matching physical PASS or explicit PO acceptance can retire an older blank
  or failed check. A closed implementation bead/native probe alone cannot do so.
- Preserve independent SKIPs, known failures awaiting physical retest and unmarked
  new behavior. No source result or empty date/summary field was filled by inference.
- Retire removed controls instead of sending the tester to obsolete star/inset
  experiments. Use current0.3.28 routes and the approved provider-backed rewind scope.
- Generic passes do not establish every specific codec, transport, permission
  fixture or conditional transition. Carry those narrow gaps as conditional checks.
- Retain the latest explicitly requested regressions, but identify them as new-build
  regressions rather than claiming the earlier feature was never tested.

## Complete text-worksheet inventory

All paths are under `docs/`; all21 originals remain unchanged by this consolidation.
The former0.3.27 template was already renamed/expanded into0.3.28 in7178153;
its checks are present in that successor rather than a missing separate worksheet.

| Source | Disposition / output |
| --- | --- |
| `MANUAL-TEST-RESULTS-0.2.12.txt` | Most failures/blocked menus superseded by F30, R1, R3 and P17 passes. Codec1.04 -> L01; scale-caption7.06/8.08 -> L02; named widescreen matrix -> L03. Audio/subtitle selection7.01/7.03 is covered by F30 E06; hidden captions by R3-REMAINING C07. Connection14.xx broadly covered by F30 O/P17 H; retain narrower later account/cache cases A01/A02. |
| `RETEST-0.2.13.txt` | Blank menu/focus/mini tests covered by F30 B02/B04-B12/D01-D05 and P17 B/C. Fullscreen-star expectation retired. |
| `FINAL-TEST-RESULTS-0.3.0.txt` | Preserve its passes. Star failures retired; source freeze, logos, hidden picture, sleep and group-order/layout caveats resolved by later marked R1/R3 results. A03 -> L04. A07's second-viewer audio-mode case -> L10 (mode persistence has later P17 I02 PASS). C03 held release -> physical0.3.8 C01-C07 PASS. |
| `RETEST-0.3.1.txt` | Source recovery B01-B09, logos C01-C03, sleep E01-E06, smoke J and other marked passes stand. Hidden D/layout G/H failures/skips resolved by R3/R3-REMAINING; star expectations retired. |
| `RETEST-0.3.2.txt` | Blank non-star cases covered by R3, R3-REMAINING and subsequent marked P17 checks. Removed star behavior is not a pending test. |
| `RETEST-0.3.3.txt` | All15 PASS retained; no duplicate layout pass requested solely because older sheets are blank. |
| `RETEST-0.3.3-REMAINING.txt` | Marked non-star passes retained. A01/A02/A06 star failure/skip retired. Its channel2101 observation is not converted into startup-recovery proof; later physical0.3.8 D checks provide that proof. |
| `STAR-DIAGNOSTIC-0.3.4.txt` | Retired diagnostic UI/cases; not pending on0.3.28. |
| `STAR-DIAGNOSTIC-0.3.5.txt` | Retired diagnostic UI/cases and navigation latch exercise; not pending. |
| `RETEST-0.3.6.txt` | Startup A01-A10 and held-player D01-D03 superseded by physical0.3.8 C/D passes. Star B/C retired. |
| `RETEST-0.3.7.txt` | Startup B and held-release E covered by physical0.3.8 C/D. Star C/D retired. AAC A01-A03 gate/start broadly covered by P17 I02 PASS; A04/A05/A10 -> L05/L06/L07. A06/A08/A09 explicit Automatic/Direct failure selections -> L08/L09; P17 I02 covers failure presentation/Cancel but does not separately record selecting both alternatives. |
| `PHYSICAL-ACCEPTANCE-0.3.8.txt` | All C01-C07/D01-D11 PASS retained. Star A/B failures/skips superseded by the PO control decision, not repaired or reclassified PASS. |
| `FULLSCREEN-STAR-0.3.9.txt` | Retired. Subsequent PO failure feedback is also recorded in DEVICE-VALIDATION; no missing diagnostic form must be completed. |
| `HOLD-STAR-0.3.10.txt` | Retired after PO rejected hold-star and chose hold OK. |
| `RETEST-0.3.11.txt` | Blank hold-OK checks covered by P17 B01-B11/C01-C05; no repeat required. |
| `PHYSICAL-VALIDATION-CURRENT.txt` | This is the completed0.3.17 historical sheet despite its filename:103 PASS,1 FAIL,5 SKIP. E06 DS9 -> V01; E09 -> V02; E30 -> V03; A08 -> A01; E13 -> A02; D03 -> L11. Missing/French synopsis notes -> V04-V07. Header-navigation note has subsequent explicit PO acceptance. |
| `RETEST-0.3.19.txt` | N01-N06 top navigation accepted explicitly by PO (b17.2 comment177); do not treat the blank form as no testing. New Settings/capability integration is still covered by TS11-TS14. L01-L04 -> V04-V07; PO rejected description completeness (l4j.18 comment178). |
| `RETEST-0.3.20.txt` | All GOL01-GOL04 covered by the marked0.3.21 GOL01-GOL04 PASS. Current restart/rewind changes retain their own TS07/RW04 coverage. |
| `RETEST-0.3.21.txt` | All13 PASS retained. CU01 icon criticism resolved by explicit0.3.25 PO acceptance in5rm. CU07's old no-Restart expectation is superseded by delivered current-program Restart; use TS01. |
| `RETEST-0.3.26.txt` | Eight blank RS checks merged into TS01-TS03/TS07-TS09 plus the current transport cases. No separate pass required. |
| `RETEST-0.3.28.txt` | All20 blank TS/RW IDs retained, with current paths and consolidated source references. |

Aliases in the fillable sheet: P17 is PHYSICAL-VALIDATION-CURRENT; Rxx is
RETEST-0.3.xx; F30 is FINAL-TEST-RESULTS-0.3.0; M212 is MANUAL-TEST-RESULTS-0.2.12.

## Legacy Markdown checklist disposition

`DEVICE-VALIDATION.md` contains both historical narrative and a never-fully-marked
checklist. Blanket copying its blanks would recreate work already physically passed.

| Checklist area | Reconciliation |
| --- | --- |
| First smoke | Navigation, guide, current/past/future actions and filter focus covered by M21213.xx/F30 guide sections. Distinct connection actions covered by accepted setup/Forget flows. Valid dashboard-password sign-in -> X01; codec inventory -> L01. |
| Authentication/storage | Ordinary errors/cancellation/Remember/account preferences/Forget covered by F30 O01-O08 and P17 H01-H09. Exact connection-keyboard mask/Save/Cancel/Back -> X02; server-URL credential clearing -> X03; named complex profile-union/hidden/adult fixtures -> X04. Password persistence/registry contents require engineering inspection, not a remote-only PASS. |
| Guide correctness | Ordinary sorting, date/DST, boundaries, groups/search/details/focus and refresh have F30/R3/P17 passes. Detailed effective overrides/shared TVG/dummy mapping variants -> X05; last-favorite removal transition -> X09; failed-window explicit Refresh -> X10. Byte/cache correctness and controlled invalid payloads are engineering evidence. |
| Playback compatibility | Auth/output-profile ordinary paths, cleanup, controls and real live rollover have M2122.08/F30 E/O/physical0.3.8/P17 passes. TLS -> X06; known redirect -> X07; codec variety -> L01. Error-code/redaction workflow is covered by P17 G04 and the reported/resolved live-reader failure. |
| Performance/visual | Existing readability/soak passes stand (F30 O06-O09, P17 J04). Explicit screenshot-set request -> X08. Instrumented timing, memory, response limits and row/cache counts are engineering measurements, not omitted manual tests to fabricate. |
| Later time shifting | Completed archives accepted by P17 F and R21 GOL. New restart/controls/rewind -> TS/RW. Native retained-hour investigation completed with a negative result and explicit PO provider-backed decision; no obsolete local-buffer acceptance checkbox is requested. |

Supplemental notes inspected: `MEDIA-VALIDATION-0.3.15.md` (later P17 covers its
delivered library/media/diagnostic cases), guide/reliability reconciliation docs,
and `CATCHUP-ICON-0.3.23.md` (its later visual request is accepted in5rm). Native-only
DS9 repair remains a physical retest; closing l4j.17 did not overwrite P17 E06 FAIL.

## Specific ambiguities kept explicit

- P17 E27 PASS records VOD persistence and near-position resume after relaunch.
  P17 E09 is independently SKIP and uniquely asks Play from beginning to reset
  progress. V02 retains that full cycle; it does not erase E27's pass.
- P17 D10 PASS covers sustained/natural buffering. D03's controlled Roku-only
  outage remains a different skipped scenario, L11.
- F30 E06/P17 I03 accept ordinary track/caption behavior. Caption geometry across
  scale modes and a specifically named21:9 sample lack equally specific results.
- Broad account restriction passes do not mark the later account-cache/VOD-state
  SKIPs or every named profile/EPG override fixture as performed.
- Blank dates, codec names, timing fields and photos accompanying a marked PASS do
  not invalidate it. X08 is retained only because the old checklist explicitly
  requested a screenshot reference set, not because every PASS lacks a photo.
- Missing VOD synopses are still an implementation/provider-data gap. V04-V07 are
  labelled accordingly;0.3.28 does not have a new VOD TMDB synopsis fix to accept.

## Engineering-only / unavailable-feature scope

No physical result boxes ask the PO to prove cache byte caps/checksums, HTTP header
parsing, memory allocation limits, password-storage internals or fault-injected
payload bounds. Those remain their existing automated/native/quality records.
No new manual procedure is invented for undelivered DVR, multiview, inline trailers,
universal local rewind or inactive recent-channel buffering. The narrower approved
provider-backed history is tested in RW01-RW05.
