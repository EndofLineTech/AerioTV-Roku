# Reliability acceptance reconciliation — mxz

Reconciled 2026-09-20 following the PO instruction: **“ihp needs to close. Finish
mxz. Work on34y.”** The marked `PHYSICAL-VALIDATION-CURRENT.txt` is the PO's0.3.17
evidence, not a template to overwrite with inferred results.

## Child coverage

| Bead | Delivery/evidence | PO coverage / outcome |
| --- | --- | --- |
| mxz.1 Storage strategy | `METADATA-CACHE-STRATEGY.md`; native tmp/cachefs/registry measurements | Previously closed; bounded/discardable cache policy |
| mxz.2 Incremental startup | `METADATA-CACHE-IMPLEMENTATION.md` | A01-A07,A09-A13 PASS; early tuning/refresh/cancellation accepted |
| mxz.3 Bounded coverage/restore | Same implementation/evidence; three resident windows, global8MiB/64 files | A02,A05,A07,A10-A13 PASS |
| mxz.4 HTTP refusal/rate/retry budgets | `HTTP-RELIABILITY.md`; actual HTTP-boundary tests/native failure checks | D13,H01,H02,H06 PASS; exact header parsing remains automated evidence |
| mxz.5 Live recovery | `LIVE-RECOVERY.md`; bounded startup and midstream budgets | D01,D02,D04-D13 PASS; covers pause, stalls, refusal, retune/exit and other viewer |
| mxz.6 Retry/loading/focus | Same implementation; native Dialog callback and error lifecycle tests | D01,D04,D05,D07,D11 PASS; focusable Retry/return and release safety |
| mxz.7 Resource/Task cleanup | Native client samples in `LIVE-RECOVERY.md`; cooperative cancellation and identity guards | D07,D08,D12,H02-H04,H07-H09,J01-J04 PASS |
| mxz.8 Bounded ingestion | `HTTP-RELIABILITY.md`; staging/parse limits and memory guard | Automated/native evidence plus H02,H04,H09,J04; no manual byte-cap claim |
| mxz.9 Diagnostics | `MEDIA-VALIDATION-0.3.15.md` and diagnostics model/handler checks | G01-G06 PASS |
| mxz.10 Unpaged mappings | Scoped normalized cache, independent hydration, explicit response limit | Native cold/warm evidence and A01,A09,A12 PASS |

The three previously unfinished reliability records (.5,.6,.7) were waiting for
physical acceptance. The submitted worksheet now supplies it; they are not new
implementation tasks to repeat.

## Contract clarification

The old mxz.5 acceptance sentence saying “Back cancels retries” predates the
accepted Back-to-mini player contract. Ordinary Back minimizes an ongoing live
session; **explicit Stop, Home/exit, retune and account changes** cancel that session's
recovery. The code, `PLAYER-CONTRACT.md`, and PO D06/D07/D12 agree. The bead's
wording is aligned with that accepted contract rather than changing playback.

## Limits retained with acceptance

- D03 (a deliberately controlled Roku-only outage) is SKIP. It is not converted
  to PASS. D10 (sustained buffering/recovery) and the other failure/cancellation
  checks are independently marked PASS.
- A08/E13 alternate-account exercises are SKIP; H03/H05/H07-H09 are marked PASS.
  Those marks are recorded individually, not extrapolated into unperformed cases.
- Native client counts briefly overlapped during rapid reopen (1/2/3/1/0 in the
  prior sample). The first baseline was unavailable, so that sample did not prove
  absence of other clients. PO D08/J03 now supplies the separate physical
  other-viewer continuity acceptance. No additional numerical PO counts are invented.
- Cachefs persistence through OS eviction/reboot is not guaranteed. HTTP staging
  limits are not an absolute network quota; native POST buffering remains a platform
  limitation. These were documented parts of the accepted implementation.
- J04 is the PO's20-30-minute soak PASS, not an indefinite endurance guarantee.
- Provider VOD405 failures and missing descriptions remain in their respective VOD
  records. They are not erased by closing this live reliability/cache epic.

All mxz child scope now has implementation and recorded verification. The PO's
reviewed worksheet and direction to finish this epic provide the closure basis.
The separate quality/release epic retains its broader compatibility/endurance work.
