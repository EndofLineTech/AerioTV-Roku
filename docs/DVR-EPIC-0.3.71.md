# Dispatcharr DVR epic — development 0.3.71 evidence

Target: Roku Streaming Stick 4K `3820RW2`, Roku OS `15.3.4`, existing Dispatcharr
`0.31.0`. No credential, server URL, program/channel label or private screenshot
is included here. All captures remain in ignored `out/`.

## Delivered paths and evidence

- One-time scheduling: guide ProgramDetails and fullscreen player Options,
  permitted current/future programs,
  saved/per-recording 0/5/10/15/30-minute padding and a separate confirmation
  showing exact padded local times. One authorized disposable future program was
  submitted through `0.3.58` UI, found in Scheduled after app exit/relaunch,
  then cancelled and found absent after another relaunch. Source model preflights
  duplicates. Player Options opened the same guarded picker on `0.3.65` and its
  default Cancel returned to playback without a POST. Physical repeated-OK and
  server failure paths remain unverified. `0.3.71` keeps an already-submitted
  Task owned during a same-account channel refresh and asks for a DVR check if
  the lineup scope changes before the result arrives.
- DVR browsing: Now/Scheduled/Recent/Series Rules, account-checked Task loads,
  local title/channel search, date/title ordering, status/facts and optional
  authorized channel/poster logo. `0.3.65` showed an actual selected channel
  logo alongside the disposable schedule, compact non-scrolling text for an
  external item without artwork, and four navigable shelves. `0.3.66` refreshes
  the shelf after navigation and does not display a removed rule's old schedules
  while it awaits the next server list.
- Series rules: title exact/contains/search, optional description phrase,
  mapped EPG-channel scope, pinned/default channel, all/new and untagged-new
  choice. Read-only preview precedes create; server evaluates after save; the
  library supports identity-checked removal with explicit confirmation. With
  owner permission, one narrow test previewed zero matches, was created and
  listed as one rule, then removed; fresh post-exit list showed zero rules and
  zero scheduled items. A second authorized preview matched exactly two future
  episodes. After the rule was saved, Scheduled showed exactly two matching
  future items. Removing that exact rule removed the items server-side; an
  initial shelf briefly showed a stale list before refresh, then zero. A fresh
  app launch confirmed zero rules and zero schedules. No per-item cancellation
  request was sent during this rule cleanup. `0.3.66` refreshes on shelf switch;
  `0.3.67` additionally refuses an ambiguous sibling-source rule delete/upsert.
  `0.3.68` identifies the channel and start time on recording-action confirmations
  and the EPG channel on rule-removal confirmation.
  Broader previews of seven and nine matches were cancelled before any write.
- Playback: completed MKV via the server `/file/` Range route, in-progress HLS
  via the server `/hls/index.m3u8` route when advertised, with account-scoped
  resume and explicit play-from-beginning. Native decoder logs on `0.3.60`
  and `0.3.61` reported `playing` on completed recordings, including a short
  newly created disposable capture. After commercial processing, the same
  capture reported `playing` again. A second disposable capture on `0.3.65`
  reached native `reader=hls` and `playing`, `paused`, then `playing` while
  recording. After Stop the partial MKV reached `playing` from beginning.
  The Product Owner confirmed physical picture **and** sound for both growing
  and stopped/completed playback during the `0.3.65` test; this is an owner
  observation, distinct from decoder logs. On `0.3.69` a completed recording
  saved position and requested resume after app exit/relaunch. Native `0.3.70`
  reported a saved seek to second 67, then a playing position of second 67.
  During a third disposable recording, growing HLS stayed in native `playing`
  through the scheduled end; the Product Owner reported that picture and sound
  continued normally until Back was pressed. A fresh server list then showed
  that capture completed. Injected Range/seek failures remain model-tested.
- Management: state-checked cancel/stop/delete, guarded confirmations, scope
  and account protection. One owner-approved disposable future schedule was
  cancelled; the first disposable short capture completed and was permanently
  deleted after verification. A second single-use short capture was GET-verified
  by its newly created ID, displayed Recording Now, stopped while active with
  server confirmation, played as a partial recording, and only then was deleted
  with server confirmation. A fresh launch showed no Now/Scheduled items and
  Recent returned to the pre-test single external completed recording. Existing
  completed recordings were not deleted or processed.
- Comskip: the just-created disposable completed recording was queued once;
  after processing, a native server refresh showed `completed` with commercial
  segments removed. The file reached native `playing` after processing, though
  its physical picture/sound were not watched during that run. On a third,
  separately authorized disposable capture the server instead reported
  **completed; no commercials detected**. Its post-Comskip file reached native
  `playing`; the Product Owner physically confirmed picture and sound. This
  verifies playable output for both an actual server-cut result (decoder state)
  and a no-commercials result (physical), but does not claim that a person
  visually compared the cut segments. UI distinguishes queue acceptance from
  completed/skipped/error outcomes and suppresses repeat queue requests.
- Local capture: Product Owner explicitly selected server-only scope; see
  `docs/DVR-SERVER-ONLY-SCOPE.md`.

`npm run verify` passed for `0.3.71`, which was installed as the normal app.
An old capability Task reported a rendezvous-aborted shutdown line during the
developer-slot replacement; the new app launched and displayed a populated guide.
After deleting only that third disposable capture, a fresh `0.3.70` app launch
showed zero Scheduled, zero Series Rules and only the pre-existing completed
item in Recent. Model/controller tests cover permission,
stale account/scope, duplicate and state checks; restricted-account native
mutation refusal was not exercised. Product Owner review is required before the
parent epic is closed. Use
`docs/MORNING-EPIC-ACCEPTANCE.txt` for remaining physical checks.
