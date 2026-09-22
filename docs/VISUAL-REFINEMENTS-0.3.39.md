# 0.3.39 development visual refinements

`faa.19`: tab icon/text runs are centered together using measured text width;
labels are vertically centered in the full control height. Group pills center
their labels on both axes; sidebar rows retain left alignment and vertical centering.

The footer contract is **key/button label in a capsule, plain help alongside**.
It applies through RemoteHints to Guide, player info, channel browser, guide
pickers, Settings, VOD library, and VOD details. Status messages remain plain text.
Tests cover content centering, key-only capsule boundaries, adjacent help and
narrow-width handling. Native Guide/Pills and Settings captures confirm this
appearance. This is not a new physical-remote acceptance run.

Local captures: `out/visual-pills-0.3.39.jpg`,
`out/visual-settings-0.3.39.jpg`, `out/visual-vod-0.3.39.jpg`.
The normal development build is restored after capture fixtures; no public release
is created by these refinements.

`faa.20`: five group pills are now visible at the top instead of three.
`faa.21`: guide EPG flags are separate rounded badges using the upstream palette:
LIVE red (`FF4757`), NEW green (`27AE60`), PREMIERE/FINALE purple (`9B59B6`).
Episode numbers and times remain plain text. Existing visibility preferences are
respected; recycled cells hide old badges and omit pills that cannot fit.
Native capture: `out/visual-badges-0.3.39.jpg`.

`faa.22`: primary tab rows are centered within the 1728px safe area on Guide and
VOD. Group strips center their actual visible count (up to five) across 1920px;
the count caption is centered too. Library subnavigation keeps its heading-safe
placement. Geometry tests cover one/five groups and two/three primary tabs.

Full verification passed. Final native capture `out/visual-centered-0.3.39.jpg`
confirms centered top/group strips, colored program badges, and key-only footer
capsules. The final normal ZIP was installed and ECP confirmed 0.3.39. SHA-256:
`fc43f554c536ce9d7e3b345009563054081376f44f2cadcc5d300cea800f513e`.
