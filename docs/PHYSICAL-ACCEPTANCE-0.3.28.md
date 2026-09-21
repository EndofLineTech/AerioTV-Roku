# Consolidated physical acceptance — 0.3.28

Reviewed 2026-09-21 after the PO reported completion of
`PHYSICAL-TESTING-REMAINING.txt`. All **50 entries are marked PASS**, with **0 FAIL,
0 SKIP and 0 unmarked entries**. The submitted worksheet is preserved verbatim.

| Results | Count | Acceptance supplied |
| --- | ---: | --- |
| TS01-TS15 | 15 | Restart, content/audio, position/pause, configured skips, held preview/commit/cancel, Go Live, failure/EOF, sustained playback, delayed information, Settings and regression cleanup |
| RW01-RW05 | 5 | Approved provider-backed rewind: entry, since-tune/hour bounds, aged-out positions, Go Live/retune/cancellation and historical metadata/unavailability |
| V01-V07 | 7 | Exact DS9 episode retest, resume/reset, completion, English preference/preservation, asynchronous description focus and honest fallback |
| A01-A02 | 2 | Previously skipped authorized-lineup/cache and VOD saved-state account isolation |
| L01-L11 | 11 | Codec/scaling/caption cases, AAC discovery/retry/selection/continuity and isolated Roku outage |
| X01-X10 | 10 | Legacy connection, masking, secret clearing, restrictions/mapping, transport, reference capture, last-favorite and failed-window refresh checks |

## Timeshift closure

TS and RW results supply the physical acceptance that was holding epic `34y`
open. All its child work was already complete. Close the epic for the explicitly
approved scope: completed catch-up, conditional Restart, provider-backed history
up to an hour since tuning, supported controls and playhead information.

This acceptance retains the recorded architecture decision: no universal local
one-hour buffer and no inactive recent-channel ingests. Provider archive
availability still applies. See `REWIND-ARCHITECTURE.md` and
`RECENT-CHANNEL-REWIND-EVALUATION.md`.

## Other acceptance updates

- V01 supersedes the earlier DS9 physical E06 failure as a successful physical
  retest of the delivered fix. The original failed worksheet stays unchanged.
- V02/V03 and A01/A02 supply the formerly skipped resume/reset, completion and
  account-specific checks. L11 supplies the previously skipped controlled outage.
- TS11-TS14 supply physical acceptance of the categorized Settings hub; they do
  not complete all remaining preferences/customization work in epic `b17`.
- V04-V07 accept delivered English selection, focus and fallback handling.
  **Missing-synopsis completeness remains open in `l4j.18`**, as V07 explicitly
  states. These passes do not claim VOD TMDB synopsis enrichment was implemented.
- The provider-specific VOD405 issue is not declared repaired by successful
  playback on a working rendition. The broader VOD epic remains open.

## Evidence precision

The worksheet targets installed0.3.28 /7178153, but its actual-build/date/device
fields, numeric timings, codec sample names and screenshot filenames remain blank.
Record the PO's PASS marks as submitted; do not invent those details or claim
receipt of screenshot artifacts. This is an acceptance/documentation update, with
no new code change, device test, installation or public release.
