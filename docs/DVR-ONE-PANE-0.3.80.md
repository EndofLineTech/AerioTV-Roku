# Single-pane DVR native check — local development build

Target: Roku Streaming Stick 4K `3820RW2`, OS `15.3.4`, Dispatcharr `0.31.0`.
This is a modified local `0.3.80` build, not the published `0.3.80` release.
Private device captures remain in ignored `out/`; no account credentials, media
URLs, or raw screenshots are part of this document.

The first native install exposed a real layout failure: plain `LabelList` heading
rows rendered in the same weight as recordings, and focus scrolled the headings
below the selected recording. The corrected normal package uses a `MarkupList`
with bold accent section rows, indented media rows and non-wrapping focus. On the
target, the section order stayed Recording Now, Scheduled, Recent, Series Rules;
Up/Down did not focus an empty heading, OK opened the selected recording's facts,
Replay refreshed the list, and Back returned to the guide. A native capture
confirmed the heading above its row with no overlap. `npm run verify` passed
after this change, including the model/controller tests and package inspection.

With explicit Product Owner approval, an isolated single-use native probe
created one bounded disposable server recording and GET-confirmed the newly
created ID, channel and probe program marker. The normal package was restored
before recording began. The list changed from Scheduled 1 to Recording Now 1
after refresh, with the new row first under its bold heading. The active row
offered Play / resume; Roku reported the HLS reader and `buffering` then
`playing`, and Play paused/resumed. Back returned to the same recording row.
The target-specific Stop confirmation produced a stopped partial file in Recent.
On that file, Roku displayed its native fast-forward and rewind timeline after
the corresponding remote keys. Only the newly created disposable recording was
then permanently deleted after its target-specific confirmation. A fresh list
returned to the baseline: Now 0, Scheduled 0, Recent 1, Rules 0. The normal
modified package remains installed; no other server item was changed.

**Remaining evidence:** The developer screenshot was black during Video playback;
native `playing` is not proof of physical picture or sound. No person confirmed
either on the TV during this run. At the time of this first test, growing HLS
disabled native trick play; subsequent native seek testing is documented in
`docs/DVR-TRICKPLAY-0.3.80.md` (`AerioTV-Roku-3ga`).
