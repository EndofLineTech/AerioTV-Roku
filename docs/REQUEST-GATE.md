# Shared request safety (`mrr.14`, in progress)

`RequestGateTask` owns a memory-only serialized ledger across Tasks. Clients
submit individual Node tickets, not read/modify/write copies of global state.
Each exchange submits a fresh wire Node: queued SceneGraph events retain Node
references, so callers must not mutate/re-submit an already visible ticket.
Normal `AerioScene` bootstrap makes this broker mandatory: an absent/unready
broker fails closed. Standalone synthetic primitives without app bootstrap do
not contain production credentials and may run without it.

## Policy

- Key holds use SHA-256 digests. Only a bounded JSON 401 whose `detail` is
  `Invalid API key` or `User inactive` holds a key. Generic/proxy 401s and all
  403s retain it. XC username/password refusals remain a separate provider rule.
- Server parks use lowercase host and effective port, independent of path or
  credential. 429 honors delta/date Retry-After, defaults to 60 seconds and caps
  at 120. GET does not automatically repeat a 429, including Retry-After zero.
- Rechecks are due at 1/5/15 minutes from rejection, then every 30 minutes, with
  at least 60 seconds between permits. Parks override even due probes. A late
  ordinary in-flight 200 cannot lift a key hold.
- Only the active Scene binding retains a raw key for rechecks. Inactive saved
  keys are not enumerated. A specialized recheck Task asks for a broker probe
  permit, requests `/api/accounts/users/me/` once, and validates the exact typed
  account ID before reporting success. Malformed/different-user 200s retain the
  hold. The broker atomically consumes the due slot before starting HTTP.
- Prompt claims are serialized and shown once per held key. The interim prompt
  uses the approved title/body and Not Now; profile-specific remote sign-in and
  Child routing remain dependent controller work, not delivered profile UI.

The ledger is bounded and fails closed on live-hold capacity exhaustion;
expired server parks are pruned. Outstanding permits expire after five minutes.
Tickets and snapshots never contain raw keys. Reports clear retained response
body/headers/URL fields. Only a canonical refusal marker and parsed Retry-After
delta cross the mailbox; arbitrary response JSON, cookies and header values do
not. URL tickets retain only origin and the optional designated probe endpoint,
never query parameters or signed/provider path tokens. Nothing in the ledger is
persisted.

## Integration

`HttpTransport` acquires a permit before creating a transfer, reports the bounded
response before returning, and polls revocation while downloading. Bearer login
never sends an API key alongside its Authorization header. `HttpPolicy` exposes
specific-key-refusal classification, so connection/capability controllers no
longer delete valid keys on generic 401 or any 403.

The separate SessionHttp, HLS open/close, playback bridge, parallel mapping and
logo-download transports also acquire/report permits. Active transfers poll
revocation where their event loop permits cancellation; admitted mutations
cannot be undone after they have already reached the server.

All six metadata-cache read sites pass current key/host authorization instead
of an unconditional `true`. A fresh cache hit cannot bypass a held key or a
server park; safe shared metadata still does not become a user-state store.

Native Poster/Video/ContentNode contexts carry only a server key and credential
digest. Render-thread checks never wait on a Task. Poster assignments and new
video readers check the current snapshot; a broker change clears affected
network artwork and stops affected readers. Local packaged/tmp artwork remains
usable. Startup/live/HLS replacement readers also check the fence. Native media
errors without a Dispatcharr JSON body are **not** guessed to mean a revoked
key.

## Evidence and remaining acceptance

`scripts/test-request-gate-native.py` builds a standalone branded package with
no application registry access, checksum-verifies the installed prior app and
restores that exact ZIP in a finally path. Its fixture uses synthetic keys and
a local HTTP listener. `out/request-gate-native.json` records sanitized evidence.

Native checks cover generic 401/all-403 retention, genuine rejection, replacement
keys, prompt-once, four concurrent held-key clients, four concurrent parked-host
clients, real production JSON transport refusal/park boundaries, digest-tagged
Poster/Video fencing, and the first real 60-second recheck with duplicate-probe
prevention. The listener checks that forbidden paths receive zero requests and
that Bearer/API-key headers are not mixed. The remaining slow schedule points
are deterministic policy tests, not a claimed half-hour wall-clock run.

The expanded native matrix also starts the packaged synthetic 4:3 MP4 through
the native Video reader and loads a local HTTP image. A subsequent production
HTTP 429 clears/stops the reader and artwork, and rejects new Video/Poster
assignments without forbidden HTTP requests. HLS open/close, bridge, logo,
session mutation and parallel mapping bypass Tasks are exercised while parked.
This is synthetic media acceptance, not the owner's authenticated live/VOD/DVR
acceptance tracked separately.

The issue remains open until the complete all-path native matrix and integrated
active-session/UI behavior have been checked. In particular this document is
not a claim of real-owner video acceptance, profile-specific Fix Login/Child UI,
or completed epic delivery. Public switching stays fenced behind scoped state,
read-only roster, PIN/Child rules and the rest of the profile controller work.

## Current device requalification

Later envelope/merge requalification passes request and own-user App Data
checks, but the previously working H.264 clip fails with native code -3,
`Failed to create decoder`. A fresh video-only Scene reproduces it, excluding
earlier renderer/test stages as a prerequisite. The unchanged clip is H.264
High level 3.0, 640×480/yuv420p with AAC-LC; the listener receives its request.
No failure was converted into a pass or retried away. `AerioTV-Roku-a4n` tracks
diagnosis and renewed media acceptance. Sanitized decoder text, HTTP method
and Range metadata are captured. Video-only runs have a separate report and
never replace full-suite acceptance. The exact prior app was restored after
every failed run. No reset or rekey was performed.

After the owner explicitly approved a restart, developer-console remote key
simulation performed the system-restart shortcut; uptime reset confirmed it.
The fresh video-only probe then passed, followed by the complete 14-group
request/App Data/media matrix, including actual native playback and the
61-second slow recheck. The exact prior app was restored after both runs.
Decoder admission is recovered; the underlying firmware/resource cause is not
established, so `a4n` retains the diagnosis history rather than claiming an app
code fix or permanent cure.
