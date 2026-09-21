# Live TV quality evidence - 0.3.30

This reconciles the `rgs.3` through `rgs.6` evidence that predates the focused
0.3.30 settings change. It does not claim a new device run: no Roku install
environment was configured during this review. The supplied 0.3.28 physical pass
remains the human acceptance source, while the native measurements below provide
the missing concrete figures.

## Target and evidence limits

- Hardware: Roku Streaming Stick 4K 3820RW2, Roku OS 15.3.4, 1080p.
- Server: Dispatcharr 0.31.0; observed live lineups ranged from 1,335 to 1,934
  authorized channels. The 1,934-channel measurement exceeds the 1,400-channel
  planning target.
- `PHYSICAL-ACCEPTANCE-0.3.28.md` records the PO's 50/50 PASS submission. Its
  date, media names, timings, and screenshot filenames were not supplied, so they
  remain unknown rather than inferred.
- The worksheet's marked PASS is device/remote evidence. Native fixtures and model
  tests are supporting evidence only.

## Account and guide acceptance

| Area | Physical evidence | Result and remaining boundary |
| --- | --- | --- |
| Login and secret handling | `PHYSICAL-TESTING-REMAINING.txt` X01-X03 and the completed connection/error cases in `PHYSICAL-VALIDATION-CURRENT.txt` | Dashboard sign-in, masked input, changed-URL secret clearing, bad credentials, cancellation, reconnect, Remember, and Forget were accepted. No credential value is retained in evidence. |
| Account restrictions and isolation | X04, A01, A02, TS14 | Restricted profile visibility, guide/cache isolation, account-scoped VOD state, and connection-hub capability gating were accepted. A missing fixture is recorded as a conditional test rather than an authorization bypass. |
| Ten-day guide and mappings | P17 guide checks, X05, X10, TS10, and the 0.3.28 pass | Historical/future navigation, rollover, effective/shared/dummy mapping handling, explicit guide refresh, and metadata failure recovery were accepted on hardware. The client never represents unfetched server history as locally stored data. |

## Media compatibility matrix

| Case | Observed native/device result | Status |
| --- | --- | --- |
| Dispatcharr live MPEG-TS | Roku's accepted reader identifier is `ts`; normal playback reached `playing` with user-confirmed picture/audio. | Supported on the tested Stick/server path. |
| Direct live stream with absent audio | Big Ten Network 404, CBS Sports Network 406, and ESPN 408 reported no direct audio in the captured native samples; the existing copy-video/AAC profile produced `aac_adts` and advancing audio/video positions. | Supported only through the existing authorized AAC profile when Automatic mode selects it. |
| Live audio/caption controls | The physical L01-L11 pass includes representative codec inventory, visible-caption scaling, AAC retry/choice behavior, and a controlled Roku-only outage. | Accepted at control level. Named media/codec rows were not submitted, so this is not a universal codec claim. |
| VOD Matroska and MP4/AAC samples | A Matrix Matroska copy played and sought; an alternate episode copy was MP4/AAC with seek/pause/resume. | On-demand evidence only; provider rendition behavior remains variable. |
| Native pause | A native live sample stayed paused at position 0.033 seconds after 30 and 60 seconds; no seek range was reported. | Short pause/resume only. It is not a retained rewind-duration claim. |
| HDR, surround, and unobserved subtitle languages | No named HDR, surround, or language-specific sample was captured for this 1080p target. | Unknown, not supported or unsupported by inference. |

See `DEVICE-VALIDATION.md`, `TIMESHIFT-FEASIBILITY-0.3.20.md`, and
`MEDIA-BLOCKER-FIXES-0.3.17.md` for the original captures and constraints.

## Large-lineup and resource evidence

| Condition | Measurement | Interpretation |
| --- | --- | --- |
| Cold/warm guide restore, 1,934 channels | Initial authorized lineup 2,212 ms; warm restart 1,932 ms; final cached guide windows 2,301 / 3,481 / 4,513 ms. | Samples, not service-level objectives. |
| Cold metadata rebuild | First guide window at 10,621 ms after configuration; mapping completed at 6,798 ms. | The unpaginated 6.7 MiB mapping response remains within the 8 MiB pre-parse guard. |
| Guide-only memory | 25-second run: peak 8%, minimum available 255,476 KB, final 7%. | Normalized guide/cache workload. |
| Guide refresh during live playback | 45-second lifecycle: peak 29%, minimum available 221,096 KB, final 7%; the same Video ContentNode continued playing across cache clear and lineup refresh. | Scripted-device behavior, not perceived audiovisual continuity. |
| Guide, browser, mini-player and playback | 65-second run: peak 30%, minimum available 223,484 KB, final 8%. | Includes logo browser and several guide-window jumps. |
| Endurance and cleanup | The submitted physical J04 soak and TS15 session-cleanup checks are marked PASS. | The submission has no duration, stream-count, or texture counter. Do not derive a memory/texture budget from it. |

`METADATA-CACHE-IMPLEMENTATION.md` and `METADATA-CACHE-STRATEGY.md` contain the
raw fixture conditions and cache limits. Peak texture usage and a new 0.3.30
sustained device run remain explicitly unmeasured; they belong to `rgs.6` and
`rgs.13`, not to the closed historical evidence.

## Scope after reconciliation

The accepted account, guide, and media matrices satisfy `rgs.3`, `rgs.4`, and
`rgs.5` for the tested Stick/Dispatcharr path. They do not establish behavior on
other Roku models, arbitrary provider codecs, HDR, every caption language, or a
guaranteed rewind buffer. `rgs.6` remains open for new peak-texture and sustained
0.3.30 measurements; `rgs.7`, `rgs.11`, `rgs.12`, and `rgs.13` have independent
physical, PO, or remote-backup prerequisites.
