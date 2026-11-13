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

The issue remains open until the complete all-path native matrix and integrated
active-session/UI behavior have been checked. In particular this document is
not a claim of real-owner video acceptance, profile-specific Fix Login/Child UI,
or completed epic delivery. Public switching stays fenced behind scoped state,
read-only roster, PIN/Child rules and the rest of the profile controller work.
