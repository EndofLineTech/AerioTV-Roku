# Provider guide refresh on Roku — 2026-10-02

After the owner repaired the guide source, the installed versioned v0.3.88
ZIP on the 3820RW2 / Roku OS 15.3.4 showed 36 authorized channels with
mapped current/future programme titles, start/end times, episode subtitles,
channel logos and category colours on launch. An explicit **Guide `*` → More
guide actions → Refresh guide** then repopulated the same rows without a
mapping warning. `Play` on the selected programme opened its provider-backed
details with a description and artwork. No server data was changed.

Private captures in the release worktree's ignored `out/` include
`gh-guide-after-explicit-refresh.jpg`, `gh-guide-refresh-scrolled.jpg`,
`gh-guide-refresh-revisited.jpg`, `gh-guide-refresh-revisit-immediate.jpg`,
`gh-guide-refresh-revisit-settled.jpg` and
`gh-guide-refresh-real-details.jpg`. Ten channels were traversed and revisited;
logos and category colours appeared on the first return capture rather than
waiting for a second load. A 35-second read-only ECP sample on this lineup
reported 35.0 MB peak app memory, 60.7 MB texture memory, no swap and zero
failed samples (`out/gh-guide-after-refresh-resources.json`). The guide-logo
cache is capped at 24 entries / 12 MiB by `components/GuideLogos.brs`.

This is acceptance on the available 3820RW2 with a 36-channel lineup; it is
not a measurement on the reporter's 3810X or a larger provider lineup. A brief
separate live tune reported `play` and then failed with a Roku media error;
Back still returned to the populated current-time guide. This guide check
does not establish continuous playback, decoded picture or audible sound.
