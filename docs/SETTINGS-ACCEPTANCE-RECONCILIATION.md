# Settings acceptance reconciliation

This reconciles the existing user-submitted **S01–S06 PASS** results in
`PHYSICAL-TESTING-CURRENT.txt` with the older issue notes that still referred to
NOT RUN checks in `PHYSICAL-SETTINGS-0.3.30.txt`. The current worksheet explicitly
supersedes that older worksheet. This is not a new physical test run.

| Story | User evidence | Supporting implementation/verification |
| --- | --- | --- |
| b17.4 — save-failure feedback | S06 PASS (conditional failure case) | Active-screen sanitized notice and rollback documented in SETTINGS-0.3.30.md; PreferenceModel covers quota/write/flush failures. Settings controller tests additionally cover remote-map failed-save rollback and publication. |
| b17.7 — startup/resume | S02–S03 PASS | Persisted account-scoped Guide/no-autoplay default and available-last-channel mini-player resume; existing startup/lifecycle coverage and native settings evidence. Earlier accepted connection/error evidence is recorded in LIVE-TV-QUALITY-EVIDENCE-0.3.30.md. |
| b17.8 — player fields/hints | S01–S02 PASS | Independent offered field toggles, persisted device settings, reflow, and no reopening of dismissed info. Effective remote-map hint behavior also accepted through RM02. |
| b17.9 — timeout/refresh | S04 PASS | 10/20/30-second request ceilings, 2/5/10-minute active-session refresh, and existing task deadlines/cancellation. Wiring and native fixture evidence are recorded in SETTINGS-0.3.30.md. |
| b17.10 — About/notices | S05 PASS | Manifest version, independent-port attribution, packaged license notices, and per-account What's New read state; native fixture rendered 183 notice lines. |

The user requested reconciliation and closure of satisfied stories before the
v0.3.37 testing release. These five stories are accepted on the recorded worksheet
and supporting evidence. The submission does not provide per-case timestamps,
screenshots, an injected storage-failure mechanism, or precise network timing
measurements; none are inferred. Conditional PASS marks remain user-reported
acceptance, not newly measured fault-injection results.

Remote-map acceptance is separately detailed in
`REMOTE-MAP-CONTROLLER-VERIFICATION.md`: RM01–RM10 all PASS on the installed local
development build, whose source was committed as `2684900`.

`b17.11` (new-release notifications) remains **open, backlog-only**. No update
checker or automatic updater is delivered by this reconciliation. The `b17` epic
remains open for that added story and eventual final epic review. This document
does not close the separate `rgs` resource/accessibility acceptance items.
