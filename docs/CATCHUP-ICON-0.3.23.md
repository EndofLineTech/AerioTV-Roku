# Catch-up retest acceptance and icon follow-up

The PO completed `RETEST-0.3.21.txt`: **13 PASS, 0 FAIL, 0 SKIP** across CU01-CU09
and GOL01-GOL04. The worksheet and its inline notes are preserved verbatim.
Its actual-build field remains blank; 0.3.22 was the last installed normal build
before the results were submitted. No missing header values are inferred into it.

This physically accepts catch-up capability/retention indicators and the delivered
archive Go Live controls, including paused-state behavior and the second-viewer
check. It does not close the broader configurable timeline/scrub story `34y.12`.

CU01 also requests a Material Design icon instead of the CATCH-UP text. In 0.3.23,
the badge becomes Google's Material Icons **history** glyph (clock with a backward
arrow), teal at 28x28. Channel-number space increases from 68 to 128 pixels when
the icon is present. FAV retains its existing location. Textual retention remains
in the selected-channel summary and program details.

Asset provenance, Apache-2.0 license and regeneration instructions are in
`images/README.md`. No icon library is required at runtime.

Native scripted verification: icon Poster `loadStatus=ready` in modal/sidebar/pills
layouts; three-day retention still present; denied permission and missing facts
hide the indicator. Temporary hooks removed after testing.

## Focused visual check for the PO

No need to repeat the full accepted worksheet for this icon-only change:

- Browse a catch-up channel, ideally also a favorite. Confirm the history icon
  looks right and does not overlap the number, name, logo or FAV.
- Browse a channel without catch-up and confirm no history icon appears.

The previous badge's behavioral PASS results are not pre-filled acceptance of the
new icon's appearance.

## 0.3.24 placement correction

The PO requested the icon immediately beside the channel number. Its position now
uses the number Label's rendered width plus a six-pixel gap, rather than a fixed
column above the name. Number width is capped at 128 pixels to reserve FAV space.
Native checks in all three layouts measured a 26-pixel sampled number and a
six-pixel icon gap, with image ready and permission/facts gating still correct.

## 0.3.25 size correction

At the PO's request, the icon is now 20x20 to match the channel number's 20-pixel
font size, with its top aligned at y=4. The measured six-pixel horizontal gap stays.
