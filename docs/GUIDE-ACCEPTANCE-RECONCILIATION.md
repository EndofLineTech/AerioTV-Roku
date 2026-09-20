# Guide acceptance evidence reconciliation

This is an evidence index, not a second task board. Beads remains authoritative.
The original 16 Guide implementation stories were reconciled against the
completed PO worksheets and existing code/model/native evidence. No new physical
tests or pixel-identical Apple TV comparisons are claimed.

Unless otherwise noted, test IDs refer to `FINAL-TEST-RESULTS-0.3.0.txt`.

| Story | Accepted evidence |
| --- | --- |
| 5tg.1 — group visibility/order/startup | G01-G06, G09-G11, O01-O03; original default-order caveat resolved by `RETEST-0.3.3-REMAINING.txt` G01-G05 |
| 5tg.2 — pills/sidebar | Original G07/G08 failures superseded by all 15 `RETEST-0.3.3.txt` passes; remaining group-options/modal checks E05/E07/E08 passed in the remaining worksheet |
| 5tg.3 — channel/favorite sort | H01-H04, H07, O01-O03; decimal/tie/reconciliation model coverage |
| 5tg.4 — collections | I01-I07, O01-O03 |
| 5tg.5 — Recently Watched group | H05-H07, C07-C08, O02; shared history/empty/removed-account model handling |
| 5tg.6 — rich EPG/lazy enrichment | J01-J06; optional-field/dummy/overlap model coverage and bounded detail cache |
| 5tg.7 — badges/episode facts | J07-J08, O01 |
| 5tg.8 — category colors | J09-J11, O01; category precedence model tests |
| 5tg.9 — artwork/TMDB | K01-K07; same-server trust boundary and bounded prefetch/detail/texture behavior |
| 5tg.10 — rich detail presentation | J01-J06, K01-K03; live action/focus restoration and source-inspired layout |
| 5tg.11 — program search | L03-L05; query/paging/cancellation model and Task-boundary coverage |
| 5tg.12 — paging/number entry | L06-L09; later held-guide navigation F01-F07 also passed |
| 5tg.13 — date/time jumping | M04-M05, F03-F04; documented source-inspired choices and guide screenshot/focus evidence |
| 5tg.14 — foreground reminders | N01-N07; explicit foreground-only delivery policy |
| 5tg.15 — history/future depth | M01-M03, M06, O01; three-window resident cache independent of requested horizon |
| 5tg.16 — refresh/cache maintenance | M07-M10; valid playback preserved, removed/unauthorized playing channel stopped explicitly |

## Dependency corrections

- Removed b17.2 as a blocker of 5tg.15 and 5tg.16: accepted controls already exist
  in guide options. A future categorized Settings hub is separate work.
- Removed mxz.2 as a blocker of 5tg.16: working refresh/clear controls do not
  require incremental startup. That performance story remains open.
- Other prerequisite stories were closed in dependency order using their own
  acceptance evidence.

All Guide child records are closed. The PO subsequently explicitly approved
closing the Guide epic, and it is now closed. Live TV's hold-OK acceptance remains
separately in ihp.37.

## What this does not close in mxz

These passes establish delivered Guide features. They do not establish persistent
EPG/catalog storage across process exit, a measured peak-memory strategy for VOD,
incremental first-render startup, pre-download response bounds, general network
retry policy, generic midstream reconnect, or a diagnostic viewer/export system.
Those retain their own scope in the playback reliability/caching epic.
