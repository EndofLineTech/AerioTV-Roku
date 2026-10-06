# Guide first paint — 0.3.91 candidate

Branch `fix/guide-first-paint` starts from committed `dev` v0.3.91. The
authorized channel lineup remains usable immediately. This candidate starts
the first **visible** logo batch and the EPG mapping Task while the guide
SceneGraph canvas is being built, rather than waiting for the first draw and
the logo coalescing timer. Subsequent row changes still use the timer, and the
per-connection authenticated tmp cache retains its existing 24-file / 12-MiB
limit. Visible IDs are numeric, deduplicated and selected from the restored
scroll position; other accounts' logos are not reused. The guide remains
interactive if an image or metadata request fails.

After the measurements below, the PO chose to remove program-category
background coloring altogether (Beads `AerioTV-Roku-cug`). The EPG mapping
and window are still authorized, fetched and cached separately from the
initial channel lineup to populate program titles, times and details.
Moving mapping startup earlier can shorten that wait without holding the
operable channel guide or delaying its launch beacon. Historical tint timings
in this report describe the **pre-removal** build and are not current UI
acceptance criteria.

## Native measurement and causal breakdown

On the 3820RW2 / Roku OS 15.3.4 with the same saved, authorized 36-channel
lineup, `scripts/measure-guide-first-paint.py` drove six fresh dev-app
processes per variant. Both variants retained the same 116×104 poster load
dimensions and the same provider responses. The baseline was the committed
v0.3.91 code with **timing markers only** in an isolated probe worktree; the
candidate contains the earlier prefetch and mapping changes. All timings
below are **medians in milliseconds after guide configuration**, from filtered
native console events (not end-to-end launch durations):

| Warm source/cache stage | Baseline, n=6 | Prefetch, n=6 |
| --- | ---: | ---: |
| First grid draw begins | 50 | 51 |
| First program label set | 726 | 791 |
| First category-matched tint set | 1,651 | 1,678 |
| First logo file received | 764 | 172 |
| Six logo files received | 1,007 | 313 |
| All six visible Poster nodes `ready` | 3,548 | 3,182 |

Credential-free numeric run records remain ignored locally at
`out/guide-baseline/out/guide-baseline-corrected.json` and
`out/guide-first-paint/out/guide-first-paint-corrected.json`. The
`scripts/measure-guide-first-paint.py` collector in this branch records only
timings, cache/network labels, app version and uptime; it never persists raw
console lines or provider identifiers.

Prefetch moves file availability forward by about **0.6–0.7 s**, but the
on-screen all-logo milestone improves by only **0.37 s** (~10%): texture
decoding/loading, not HTTP transfer, now dominates. Six corrected warm runs
per variant reported all visible posters ready in baseline 3,463–3,570 ms
and prefetch 3,117–3,232 ms. No device reboot or raw provider data was logged.
An 80×80 decoded-poster trial reached 3,140 ms median (vs 3,190 ms with
116×104 at that stage), a negligible difference, so original sharpness was
restored. Guarding redundant Poster dimensions/visibility also changed the
median by only ~36 ms and was removed.

The first available program had **no matching category** and was correctly
neutral in every instrumented warm sample (`has-category=false`, not focused).
The first recognized category came from a later cached window; colors are
computed in the **same draw call** as the associated program title, rather
than fetched or painted by a separate color Task. With the provider repaired,
two cache-expired mapping-network samples completed mappings at 1,157/1,198 ms
and first recognized tint at 2,389/3,104 ms. The slower sample fetched two
guide windows over the network (2,053/2,687 ms); the other reused two windows
(1,445/1,974 ms) and fetched a third. The gap after the initial lineup comes
from authoritative mapping plus serial guide-window restore/network fetch,
not a late category-color operation. As the visible time range moved to three
windows, a separate six-run series showed first tint at 1,954–2,025 ms (one
of those windows held the first matching category); the label/tint coupling
remained the same.

After the owner restored the provider EPG, a cold launch on the same 36-channel
account produced authorized mappings and two guide windows from the network.
An early private capture requested at 2 seconds (captured at about 3.6 seconds)
showed channel names and "Loading guide...", without program titles, category
colors or logos. A later capture at about 13.8 seconds showed program titles,
category colors and logos together. A middle capture at about 5.8 seconds
already had the program titles and their category colors in the **same frame**,
but two visible logos were still blank; those appeared in a later frame.
The console reported the mapping request at 1,032 ms and first two guide
windows at 1,456/2,130 ms after authorized lineup configuration. The mismatch
is thus not a separate late color-paint step: it is the difference between
the immediately operable lineup and asynchronous, authoritative program data.

The actual visible provider logos are PNGs: four of the six are 1,440×1,080
or 3,200×2,400 pixels, despite appearing at only 58×58 in the guide; file
sizes range from 22,578 to 447,962 bytes. A disposable **probe only** copied
tiny packaged PNGs to the same `tmp:/` paths and used the same Poster nodes:
all six reached `ready` at a **905-ms median** (898–956 ms, six warm launches;
the first run was 747 ms). The six-run result is retained in ignored
`out/guide-baseline/out/guide-tiny-tmp-six-runs.json`. That isolates large-source image
processing/decoding from the tmp path and guide scene layout. The inspected
Dispatcharr v0.31 image proxy serves raw artwork rather than resized
derivatives. `roBitmap` documents a 2,048×2,048 maximum, so decoding
the 3,200×2,400 originals into Roku bitmaps for client-side downscaling is
not a safe generic substitute. Sized server artwork is the likely route to
substantial further image-speed improvements, subject to an authenticated,
account-scoped endpoint and a separate cross-device test.

An on-device read-only guide sample with the repaired EPG measured peak app
resident 33,234,944 bytes, texture 88,842,240 / 100,000,000 bytes, zero swap
and zero failed samples. Six larger original PNGs should not be replaced by
more parallel full-size bitmap decoders without checking memory on older Roku
models. The candidate passed `npm run verify` (195-file ZIP) and screenshots
remain ignored locally; the code and safe timing collector remain on the local
branch pending product acceptance.

## Roku TimeGrid

Roku's [TimeGrid](https://developer.roku.com/docs/references/scenegraph/list-and-grid-nodes/timegrid.md)
has native channel/program rows, remote timeline navigation, default channel
logos, `channelInfoComponentName` for custom channel information and loading
feedback. The app's mini-player can remain elsewhere in the Scene. The
documented stock program fields and background bitmap do not establish support
for the current per-program category tints and multiple badge pills. A
disposable prototype is tracked in Beads `AerioTV-Roku-c7l` to compare
visual/focus fidelity and rendering cost; switching controls alone would not
speed up server mapping, guide or authenticated logo downloads.
