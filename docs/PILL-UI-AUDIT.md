# Centered pill UI — on-device audit

Work item: `AerioTV-Roku-iut`. Rendered inspection: November 11, 2026.

## Implementation

`uiButton` and `uiButtonLabel` use full-height, horizontally/vertically centered
label boxes and half-height corner radii. Welcome, connection selectors/actions,
phone setup and program actions use these primitives. Group sidebar labels are
centered; Settings rail icon/text runs are centered together. Remote key hints
use the entire pill as their label box, not a hand-positioned baseline.

`AerioPillList` retains native MarkupList focus, selection and scrolling, with
centered rounded action rows in both states. It replaces all four LabelLists:
Settings, guide picker, player options and VOD details. Floating focus prevents
the native wrapping divider from introducing clipped rows. Informational and
license rows deliberately remain plain left-aligned text.

`AerioDialog` retains native Dialog/ButtonGroup navigation, selected indices,
dismissal and original button text, with centered pill overlays. All eighteen
legacy application Dialog constructions use it. Roku owns the dark dialog panel;
title/message colors stay readable in application light mode.

## Actual Roku inspection

The gallery uses production renderers with synthetic data, replaces Main/Scene
startup, disconnects account/media event handlers, prevents the phone receiver
from starting and uses temporary metadata cache storage. It does not load the
application registry or contact a provider. Shipping and pairing-build package
guards reject its hooks. It is not an owner-testing application.

39 rendered cases were captured and inspected, not merely counted as successful
HTTP screenshots. Local evidence: `out/ui-audit/*.jpg` and `captures.json`.

| Surface | Cases inspected |
| --- | --- |
| Entry/setup | Welcome; Dispatcharr, Xtream and M3U setup |
| Phone | Ready, expired, verification failure/retry; ready at 120% text |
| Action lists | Guide picker, player options, long player label, VOD details |
| Scrolling | 13-action guide picker, native Down to index 9; no clipped focused row |
| Program | Recording, archive, live and close buttons |
| Navigation | Top navigation, group strip and group sidebar |
| Playback | Live and recording transport icon controls; no playback started |
| Settings | Connection, Live TV, Player, Movies, DVR, Appearance, General, Remote, About, What's New, licenses |
| Dialogs | Duplicate Cancel/Add Anyway/Replace, delete confirmation, diagnostics |
| Appearance | Settings/options at 120% text; light Settings/dialog/hints; four hint heights |
| System keyboard | Native voice keyboard and Done/Cancel, inspected with synthetic text |

Inspection found a black join in the focused group-sidebar pill. Both ring/fill
now overlap their corner joins; a fresh Roku capture confirms the seam is gone.
Native focus was checked with remote events and native index assertions in the
guide picker, player options, VOD actions and duplicate dialog. Long-list
scrolling was separately checked and visually inspected.

### Explicit limitations

Follow-up: the populated library/Settings audit is documented in
[`UI-LIBRARY-AUDIT.md`](UI-LIBRARY-AUDIT.md), including rendered findings assigned
to `AerioTV-Roku-mrr.2` and `.3`. The scope below describes the original 39-case
pass, not that expanded audit.

- **Native voice keyboard is not pill-compliant.** Its keys and left-aligned
  Done/Cancel remain Roku-owned styling. Retaining it preserves standard voice
  and text entry; replacing/restyling its framework needs separate investigation.
  The screenshot runner crops out Roku's own mobile-keyboard QR banner.
  The owner subsequently accepted native system styling; `AerioTV-Roku-1rm`
  is closed and custom keyboard styling is not required.
- The gallery covers shared library navigation/action renderers, not every
  populated VOD/DVR library view or every provider-specific dialog message.
- Content cards, guide cells, informational text and text-entry fields are not
  action buttons and intentionally retain their own presentation. Transport
  icon buttons remain circular, with centered icons.
- No saved settings/connections changed, destructive action executed, or media
  started. Real duplicate transactions are tested only with a memory registry.
- This is not exhaustive accessibility/screen-reader certification or phone-app
  acceptance of automatic guide handoff.

## Verification

- `npm test`, `npm run check`, `npm run build`: passed.
- Gallery: all 39 cases rendered without reported compiler/runtime diagnostics;
  screenshot review completed with the exceptions above.
- Native real-HTTP apply suite: eleven checks passed with `AerioDialog`, including
  duplicate Cancel/Add Anyway/Replace, refusal at capacity, automatic add/guide
  handoff, real provider Tasks and JSON/XMLTV guide loading.
- Full-app no-save smoke: five checks passed against the exact candidate below:
  live QR, code renewal, receipt/provider verification, retry, cancel to setup.
  It restored the normal build; the checksum-verified candidate was subsequently
  reinstalled for owner testing. Evidence: `out/pairing-app-native-results.json`.

## Owner-testing artifact

`out/pairing-tests/pill-ui/aeriotv-roku-v0.3.100-pairing-test.zip`

SHA-256:
`91f8b8b1f3c2f45e625588e198b8f0a66af963ea285d49e1a27483461afb8734`

Checksum file: `out/pairing-tests/pill-ui/SHA256SUMS-pairing-test-v0.3.100`
(`shasum -a 256 -c` passed). This exact developer candidate is installed.

It remains explicitly branded **PAIRING TEST BUILD — DEVICE-KEY SOURCE NOT
SECURITY-QUALIFIED**, not a Beta/Store package. Shipping entropy stays fail-closed.
The local build also includes the owner's existing uncommitted cache/mapping and
version work; those files are not part of this UI commit.

Rollback: the previous verified auto-guide developer ZIP remains at
`out/pairing-tests/auto-guide/aeriotv-roku-v0.3.100-pairing-test.zip`, SHA-256
`40bd99329ff0c33fb4be807690970ba7d2ddd3b4add64bee0f9f7b079739794c`.

## Reproduce the safe gallery

With developer credentials supplied only through the environment:

```sh
npm run build
python3 scripts/build-ui-audit-probe.py
node scripts/test-ui-audit-native.mjs out/ui-audit-probe.zip out/pairing-tests/auto-guide/aeriotv-roku-v0.3.100-pairing-test.zip
```

The runner restores the pinned auto-guide ZIP in `finally`, even after failure.
Fresh capture manifests intentionally say `visualReviewPending: true` until a
human/agent actually inspects the images; capture success is not visual approval.
