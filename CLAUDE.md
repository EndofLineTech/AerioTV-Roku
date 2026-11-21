# Claude Code Instructions

`AGENTS.md` is the single source of truth for this repository's agent rules
(Beads tracking, `AerioTV-Roku-mrr` epic continuity, signed Beta packages and
the mandatory push workflow). It is imported here so the two cannot drift:

@AGENTS.md

## Claude-specific working rules

- The main checkout may contain the owner's uncommitted edits and untracked
  research files. Do not reset, discard, stage or publish them. Build, test and
  commit in a separate clean worktree based on current `origin/dev`, and install
  dependencies there from `package-lock.json`.
- `npm run verify` is the full gate before pushing code. It historically takes
  20+ minutes; run it in the background and treat a short tool timeout as
  "not run", never as a pass or failure.
- Roku device access is serialized. Follow `docs/NATIVE-DEVICE-WORKFLOW.md`:
  confirm the exact installed restore image, foreground and Home before a
  sideload, and restore the release image and verify Home afterwards.
- Never put credentials, API keys, PINs or content identifiers in Git, Beads,
  probe ZIPs, command-line arguments, screenshots or retained evidence. Ask the
  owner once for a missing credential and continue with independent work.
- Packaged or synthetic media proves on-device behavior only, not live provider
  integration. Report each acceptance criterion as passed, failed, blocked or
  not run, and keep a bead open until its own criteria are met.
