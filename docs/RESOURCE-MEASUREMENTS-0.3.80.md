# Final-build Roku resource measurements — 2026-09-25

Issue: `AerioTV-Roku-05e`. Target: Streaming Stick 4K **3820RW2**, Roku OS
**15.3.4**, 1080p, Dispatcharr 0.31.0. Installed development ZIP was verified
as app-source commit `dbca672`, version **0.3.80**; the guide displayed **1,334**
authorized channels. No provider configuration or other viewer was changed.

## Instrumentation and bounds

The numerical sampler is `scripts/measure_roku_resources.py`. It collects
`query/chanperf` process memory and foreground limit plus
`query/r2d2-bitmaps` texture/system-memory counters at bounded intervals.
Private numeric-only per-sample JSON is in ignored `out/resource-*.json`;
the collector never stores bitmap names, registry contents, credentials,
media labels or raw ECP XML. `query/r2d2-bitmaps` can include Roku-managed
and otherwise unattributed graphics instances: **sum across instances is not
exclusive app texture usage** and is not directly comparable to one instance's
reported 100,000,000-byte maximum. Peak *single-instance* usage is reported
separately. The user's earlier physical Q03/Q04 results remain separate from
these scripted measurements; ECP `play` does not prove sound or picture.

Measured process memory limit: **513,802,240 bytes**. The engineering guard
for this run is at most **75%**, or **385,351,680 bytes**, consistent with Roku
Resource Monitor's foreground guidance. Per graphics instance, use a
conservative **75,000,000-byte** guard against the reported 100,000,000-byte
maximum. These are measurement/triage budgets for this target, not promises
for all Roku hardware or a substitute for sustained device acceptance.

| Workload | Measured duration and result | Peak process memory | Graphics memory |
| --- | --- | ---: | ---: |
| Process restart, saved connection | Authorized 1,334-channel lineup in **1,496 ms**; mapping **4,440 ms** after lineup; first window **5,091 ms** after lineup; 50-s resource sample | **90,718,208 bytes** | Single-instance **61,657,088 bytes** |
| Warm process restart | Lineup **1,326 ms**; cached mapping **646 ms** after lineup; cached first window **1,282 ms** after lineup; 50-s sample | **67,268,608 bytes** | Single-instance **62,156,800 bytes** |
| Guide rows/time windows | 72 s, 32 successful ECP arrow inputs, no app exit | **148,168,704 bytes** | Aggregate **57,602,048 bytes** at peak |
| Continued guide scrolling | 300 s then 180 s, 38 bounded inputs, no app exit; final process **134,021,120 bytes** | **134,103,040 bytes** | Single-instance **62,156,800 bytes**, stable across both phases |
| Live playback, first run | 600 s with native player observed playing; additional 60-s sample in the same session; no ECP resource-query failures | **231,260,160 bytes** (45.0% of limit) | Aggregate **122,789,888 bytes** across multiple graphics instances |
| Live playback, repeat run | 900 s with player `play` at each one-minute checkpoint; process usage plateaued around 39.5% of limit over the last five minutes; 82 resource samples, no failures | **202,911,744 bytes** (39.5% of limit) | Peak single-instance **62,279,680 bytes**; aggregate **124,559,360 bytes** across four instances |
| Retune attempts/failure cleanup | 90 s and 95 s resource samples; the selected neighboring streams stopped with native media error rather than becoming confirmed successful retunes | **113,606,656 bytes** (first sample) | Peak single-instance **62,607,360 bytes** (second sample) |

The first live sample followed earlier guide/error work and reached a higher
process peak than the later isolated 15-minute run; these are distinct
workloads, not a single continuous memory slope. The process and
single-instance graphics peaks stayed below the guards above. Roku uptime
advanced from **570,538** seconds at the start of this measurement work to
**574,740** seconds after the final local app exit/relaunch, with no observed
device reboot. App-owned media closed on local exit; ECP reported the
development app active and media `close` after restoration. An attempted
read-only Dispatcharr per-channel status check returned 404 both before and
during one short tune, so a final-build **server client-count cleanup
measurement is unavailable**; no other-viewer continuity is inferred.

The failed retune sample showed a Roku error **-5** for unsupported AAC on
one authorized source in a private screenshot. No working two-channel retune
resource sample was obtained during this session. `AerioTV-Roku-ssq` tracks
that separate source/compatibility investigation and the missing successful
retune comparison. The earlier accepted Live TV baseline is not revoked by
an unproven generalization from these particular streams.

Cold/warm timing is measured from the app's numeric native console markers;
"after lineup" is not an absolute launch-to-first-frame time. The 15-minute
live run was limited to already authorized media and stopped locally. The
device's normal development app/remembered guide was restored afterward.

Later follow-up: `ssq` traced one source's early native AAC decoder refusal
in Auto mode, implemented a bounded local compatibility retry and verified a
working-channel retune to that source with native audio/video state and PO
physical picture/sound. See `AAC-RETUNE-RECOVERY-0.3.80.md`. The historical
resource samples above remain their original measured outcomes, not
retroactively successful retune measurements.
