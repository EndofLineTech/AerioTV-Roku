# Dispatcharr-host multiview sidecar — product scope

PO decision 2026-09-25: replace the proposed Roku-native two-decoder multiview
with a **separate sidecar container on the Dispatcharr host**. This explicitly
supersedes the earlier no-new-runtime and Roku-must-open-two-streams constraints
**for multiview only**. Delivery is tracked by `AerioTV-Roku-cba`; no sidecar
is installed and no multiview mode is advertised in the Roku app today.

The earlier native feasibility experiment remains valid: two ordinary Roku
Video nodes returned a second-player error, while public `roMultiDecode` access
was not established. `wt1`, its native child stories and `cw0` were closed as
superseded, not passed. See [native research](MULTIVIEW-NATIVE-RESEARCH.md)
and [path comparison](MULTIVIEW-PATHS.md) for historical evidence.

## Product contract to design and validate

- Compose at least two **distinct authorized live inputs** on the Dispatcharr
  host into one bounded Roku-compatible live output. Two moving pictures and
  audible audio from the selected/focused tile remain the desired experience.
  Changing tile must select its audio; mixing both tracks or offering a silent
  grid is not an accepted substitute.
- Scope each source, composite session and control request to the verified
  viewer's account/capabilities. Do not expose provider credentials or
  playable upstream URLs to the Roku or to another viewer. Handle grants
  changing during playback, token expiry and a single failed input without
  compromising the other session or silently showing unauthorized content.
- Bound concurrent composites, input sessions, CPU/GPU, memory, output bitrate
  and idle lifetime on the shared host; define client disconnect, account
  change, Back/Stop and sidecar restart cleanup. Keep the normal one-stream
  Roku Live TV path available if a composite is unavailable.
- Choose the sidecar's compositor/transport and an authenticated tile/audio
  control contract only after feasibility measurements on that host. Prior
  Dispatcharr stream failover lists and single-input FFmpeg profiles are not
  already a multiview compositor. A potential FFmpeg-based solution is a
  design candidate, not an existing deployment or accepted resource budget.
- Verify the composed output on the target 3820RW2 with real moving pictures,
  sound and remote focus, then check provider/session counts and the effect on
  other viewers. Document deployment, observability and rollback before PO
  acceptance. Scripted media state alone is not picture/audio proof.

Changing Dispatcharr/provider settings, opening extra long-lived streams or
deploying the sidecar are separate implementation actions under this new epic;
the scope decision above does not itself authorize an unmeasured deployment.
