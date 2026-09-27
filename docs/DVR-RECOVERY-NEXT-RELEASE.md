# Decision: defer the DVR recovery candidate from the next testing ZIP

The published v0.3.82 ZIP includes the PO-accepted intermittent near-end
Dispatcharr HLS reader limitation. Later `dev` commit `2ce34cc` introduced a
status-confirmed HLS-to-file recovery candidate. The owner asked whether it
belongs in the *next* testing release. **Decision: exclude that candidate from
the next ZIP until its completion race and real-server handoff are verified.**
This is a release-scope decision, not a rollback of published v0.3.82 or a
claim that the original `-3` has been fixed.

## Evidence and release risk

- Dispatcharr v0.31.0 remuxes HLS to MKV, keeps the HLS working directory for
  active viewers, removes it and **only then** saves final recording status
  (`docs/DVR-HLS-HANDOFF-0.3.82.md` has pinned source links). The final status
  may not be ready when an HLS reader first stalls near its last segment.
- OnDemandPlayer emits a single near-edge completion check after ten seconds
  of buffering (`m.handoffCheckRequested = true`). The Scene's status callback
  discards any result still marked `recording` and clears its pending handoff;
  no retry is scheduled. At 45 seconds of buffering, the player stops. The
  error callback checks once more only if Roku emits `error` rather than
  `stopped` or `finished`. This makes a premature status response a concrete
  missed-handoff path, not just an untested codec concern.
- The earlier credential-free Roku probe directly opened a known fixture MKV
  after an HLS stall; it bypassed the production status Task. A later mock
  Dispatcharr-shaped fixture exercised the actual Task request and returned
  a completed status, but its native observation was interrupted before the
  completed reader's `playing` state was captured. The first probe attempt
  exposed a **probe-only** missing script import, which was corrected. These
  runs do not prove the production handoff succeeded.
- The one approved real Dispatcharr recording finished normally without an
  HLS reader stall; the status-confirmed recovery branch was never reached.
  Its fixture approval was used and cleaned up. Another real fixture requires
  fresh owner approval.

The local HTTP fixture now supports read-only recording status, a finite-file
route and a bounded delayed-status case. Its HTTP protocol test verifies that
the playlist can redirect while status still reads `recording`, then later
reads `completed`. This exercises the timing hazard without modifying the
Dispatcharr server.

## Next testing-release composition

The versioned v0.3.82 tag is immutable. For a guide-and-controls-polish-only
next build, **start from `v0.3.82` and apply the verified post-tag guide commit
`257f901` plus the DVR icon-alignment commit `485cec9`**, then increment the
version, run the documented release gates and obtain release authorization.
Do not package the current `dev` tip unchanged: it includes the unverified
recovery candidate. Before that recovery enters a later testing ZIP, add a
bounded status recheck for the near-edge race, exercise the actual status Task
and finite-reader replay on the Roku, and verify against a separately approved
real-server fixture or explicitly obtain the PO's decision on the remaining
real-server evidence gap. Keep accepted v0.3.82 release assets unchanged.
