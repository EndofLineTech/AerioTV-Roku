# Streaming Stick 4K two-Video feasibility probe

Development-only native fixtures `0.3.47`, `0.3.48`, and `0.3.49` were derived
from verified normal `0.3.45`; they are excluded from the restored normal app.
Target: Streaming Stick 4K `3820RW2`, Roku OS `15.3.4`, 1080p, Dispatcharr
`0.31.0`. Two temporary SceneGraph Video nodes used the existing account's
MPEG-TS live playback descriptors. The first node owned audio; the second was
muted. Both were stopped, cleared and removed at the end of each run. No media
server or long-lived channel session was added.

| Controlled run | First Video | Second Video | After cleanup |
| --- | --- | --- | --- |
| Different live channels (`0.3.47`) | `playing`, code 0 | `error`, code -5 | Both removed |
| Different channels with second alone afterward (`0.3.48`) | `playing` | simultaneous `error`, code -5; later alone briefly `playing`, then `buffering` at 20 s | Both removed |
| Same live channel in two nodes, then alone (`0.3.49`) | `playing` | simultaneous `error`, code -5; alone `playing`, code 0 at 20 s | Both removed |

One read-only ECP `query/chanperf` sample during the dual run reported about
78.6 MB application memory used. This is **one sample**, not peak or sustained
memory; the texture query did not yield a usable counter. Device uptime and
native logs did not establish picture/audio quality. The target plus current
server path did not sustain two simultaneous Video sessions in these trials.
Because even the same-source second node failed while that source worked alone,
the result is not explained solely by a bad second channel. The probe does not
isolate decoder contention from concurrent client/session limits or establish
the maximum stable stream count on other hardware or providers.

## Native error follow-up (isolated development 0.3.52)

The same-source dual-Video trial was repeated with a structured, whitelisted
`Video.errorInfo` check. With the first node `playing`, the second returned
`category=mediaplayer`, internal error code **16**, and the diagnostic matched
**“only one playing instance supported.”** Once both nodes were stopped and
removed, that source played alone. A concurrent bounded `roUrlTransfer` timed
out without staged bytes; that result is inconclusive for server fan-out and
does not explain away the native player's explicit rejection.

An [Roku developer forum reply](https://forum.developer.roku.com/t/playing-2-video-nodes-in-scene-graph/10246)
also says ordinary SceneGraph apps cannot play two Video nodes at once;
[the later multiview discussion](https://forum.developer.roku.com/t/roku-multiview/11357)
mentions a separate `roMultiDecode` path but no documented public contract.
This measures the **one-playing-instance limit on the tested Stick/OS/Video
path**, not the capacity of a future restricted multidecode API.

The Product Owner chose **measured deferral** if useful simultaneous playback
could not be demonstrated. Do not advertise or implement a multiview layout on
this evidence. Peak/steady memory and texture measurements, real picture/audio
observation, provider-slot diagnostics and a longer cleanup run would be
required before a *different* future multiview API could be called viable.
They do not overturn code 16's current one-instance rejection. Dependent
delivery remains gated rather than presenting a false grid. The native
fixture must be replaced by the normal development build after the trial.
