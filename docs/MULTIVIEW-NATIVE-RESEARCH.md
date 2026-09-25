# Native concurrent-stream multiview: Logan Roku evidence

Research update for `AerioTV-Roku-cw0`. Product requirement: the **Roku opens
and displays at least two distinct live streams concurrently**. A one-feed
server mosaic, provider composite, rapidly refreshed images, and sequential
channel switching do not satisfy it. Target: Streaming Stick 4K **3820RW2**,
Roku OS **15.3.4**, Dispatcharr **0.31.0**. No server/account configuration was
changed, no native multidecode probe was run, and no picture/sound result is
claimed here.

## Primary evidence that this hardware family is a viable candidate

1. A photographed [Roku Developer Summit 2024 Multiview slide](https://miro.medium.com/v2/resize:fit:1600/1*9S4UeCGc76hf8_iQgFCJDg.png)
   (embedded in [attendee notes](https://mlangendijk.medium.com/roku-dev-summit-2024-b256e278402d);
   Roku hosts the [2024 SceneGraph session](https://developer.roku.com/videos/demos/summit-2024.md))
   explicitly states that the new **`roMultiDecode` component uses hardware
   decoding for multiple streams with simultaneous playback**, and that the
   announced rollout includes **Brewster, Bailey, Logan, and select TVs**. It
   describes multiple video/audio streams and PiP/multiview layout. This is a
   photographed presentation slide, not an SDK reference or a test of our app.
2. [Fubo's Roku support matrix](https://support.fubo.tv/hc/en-us/articles/30574847628045-How-does-Multiview-work-on-Roku)
   lists **3820X2** and **3821X2** for **two simultaneous views** on Roku OS 14+
   and Fubo app 5.8+. Fubo describes selecting a second live channel, changing
   one tile, choosing its audio, reordering tiles, and returning from fullscreen;
   transport controls are unavailable in its multiview. The target's 3820RW2
   is in Roku's [3820X2/Logan family](https://developer.roku.com/dev/docs/hardware)
   (Roku/Fubo model suffixes encode regional variants). Fubo's
   [launch announcement](https://ir.fubo.tv/news/news-details/2024/Fubo-Launches-Multiview-Beta-Feature-on-Select-Roku-Devices/default.aspx)
   calls this user-configurable concurrent playback of separate live channels.
   These statements prove **Fubo offers two-view support on the model family**;
   they do *not* disclose Fubo's implementation or grant another app SDK access.
3. The previous [AerioTV native probe](MULTIVIEW-FEASIBILITY-0.3.47-49.md)
   got `mediaplayer` code **16**, "only one playing instance supported", using
   **two ordinary SceneGraph `Video` nodes**, even with the same source. A
   [2025 Roku developer discussion](https://forum.developer.roku.com/t/roku-multiview/11357)
   records the same failure on an Ultra 4850X and points developers toward
   `roMultiDecode`. That failure measures the **ordinary Video route**, not the
   separately announced multi-decoder API. Simply repeating it at lower
   resolution cannot establish `roMultiDecode` capacity.

Other public components do not solve the simultaneous-live requirement:
`roVideoPlayer` was also described as single-playback by Roku staff in the
[historical developer forum](https://forum.developer.roku.com/t/multiple-rovideoplayers-behavior/3253);
[`roCompositor`](https://developer.roku.com/dev/docs/rocompositor) composes
bitmaps, not decoded live video surfaces; and Roku's
[`roAnimatedImage`](https://developer.roku.com/dev/docs/roanimatedimage)
downloads its whole resource first and recommends only one small animation.
Those paths are not native concurrent MPEG-TS stream playback.

## Access gap found by public-source search

Roku's published [BrightScript component index](https://developer.roku.com/dev/docs/brightscript)
and [SceneGraph media-node index](https://developer.roku.com/dev/docs/media-playback-nodes)
list `roVideoPlayer` and `Video` but do not list `roMultiDecode` or a public
multi-decoder node. Direct public reference URLs for `romultidecode` and
`multiview` returned 404, and a public-code search for `roMultiDecode` yielded
no sample implementation. A forum participant speculated about a developer
token; **the token, eligibility, and creation/control API are unconfirmed**.
Roku's Summit announcement plus Fubo's delivery are positive evidence for the
platform/model; they are not enough to compile a supported channel integration.
In particular, we have not confirmed that the development-slot app can request
the same capability without partner enrollment or a particular publisher key.

Further public search: the [Roku developer forum's own `roMultiDecode` search](https://forum.developer.roku.com/search?q=roMultiDecode)
returns one July 2025 post asking where its documentation is; public code and
GitHub-issue searches for the exact name found no usable sample. The public
[Roku Partner Knowledge Center search](https://partnersuccess.roku.com/hc/en-us/search?query=multidecode)
returns no article for `multidecode` (nor for `multiview`). These are bounded
search results, not evidence that an unpublished partner contract does not
exist. The [Partner Knowledge Center request form](https://partnersuccess.roku.com/hc/en-us/requests/new)
is the official next contact path; no request has been sent from this project.

Suggested technical request to Roku Developer/Partner Support (no server,
account or device credentials needed):

> Your 2024 Developer Summit announced `roMultiDecode` for Logan hardware.
> Fubo lists the 3820X2 family as supporting two views. We develop a native
> SceneGraph app for Streaming Stick 4K 3820RW2, Roku OS 15.3.4. Where can we
> obtain the `roMultiDecode` API reference and minimal two-stream sample? Is
> it available to a sideloaded developer app, and are a publisher entitlement,
> developer token, or enrollment required? Please specify the supported OS,
> model, creation/control/lifecycle interface, per-stream HTTP authentication,
> live MPEG-TS versus HLS/DASH support, simultaneous decoder limits, and
> single-audio/caption ownership. What is the supported route for an independent
> publisher to test and ship this on Logan?

**Next internet/platform inquiry** (via Roku's developer program, not guessed
methods): request the `roMultiDecode`/multiview SDK contract and example for
3820X2/Logan on OS 15.3.4; ask whether sideloaded apps can use it, whether an
app/entitlement/developer token must be issued, how per-stream URL/auth headers
and single-audio ownership work, supported MPEG-TS vs HLS/DASH formats/codecs,
resolution/bitrate/concurrent-session limits, and cancellation/teardown rules.
Ask whether Fubo's published two-view support is available to other publishers
on this model. Access to Fubo's implementation or account is not assumed.

Only after a documented, permitted API is obtained: construct a **disposable**
native proof under ignored `out/`, starting with two distinct authorized
low-resource live streams, bounded to a short run, no shared provider/server
writes. Collect independent stream identity, two moving pictures, actual sound
from the selected tile, native error/state and measured app/texture memory and
provider client counts; stop both and verify cleanup, account switching, live
single-player regression and reinstall the normal verified Roku ZIP. A device
feature query or creating an object without dual picture/audio does not qualify
as a two-stream PASS. Resuming deferred delivery stories `wt1.3` and `wt1.4`
requires this proof and scoped PO review.
