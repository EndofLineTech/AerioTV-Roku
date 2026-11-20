# HTTP and ingestion policy (mxz.4 / mxz.8)

Originally implemented in development 0.3.12. `HttpPolicy.brs` supplies structured categories;
`DispatcharrHttp.brs` retains callers' string error compatibility while applying
attempt/deadline budgets; `HttpTransport.brs` owns native transfer cleanup.

- 401 authentication and 403 permission are distinct, non-retryable failures.
- 409 is a conflict/resource refusal, not blindly labeled a connection limit.
- 404/410 distinguish unavailable items and expired sessions.
- A 429 reported to the [shared request gate](REQUEST-GATE.md) parks the server;
  the failing GET does **not** automatically retry, even with Retry-After zero.
  The park accepts seconds or HTTP dates, defaults to 60 seconds, and caps at
  120 seconds. For transient 408/502/503/504, the JSON request helper permits
  **one retry for an eligible GET only**, inside the original request and Task
  deadlines. It uses Retry-After when the delay fits; long delays return
  rather than sleeping indefinitely. This is not native media-reader backoff.
- Login, source changes and other POST mutations are never automatically repeated.
- Pagination is same-server trusted, rejects repeated next URLs, caps at 100 pages
  and 100,000 accumulated rows, and has an enclosing 60-second budget. VOD uses
  individual server pages rather than loading a full library through this helper.
- GET responses stage in app-owned tmp files and must be at most 8 MiB before
  ReadAsciiFile/ParseJSON. File size is also checked during transfer when native
  stat exposes it. Native memory pressure (75% or <32 MiB available) cancels work.
- Native POST response buffering occurs before the length check. Native in-flight
  stat visibility is not a proven hard network-byte quota. These are explicit
  platform limits, not a claim of an absolute pre-transfer cap on arbitrary input.
- Cooperative cancellation replaces abrupt STOP for HTTP-backed Tasks, allowing
  native transfer cancellation and staging deletion. Results are suppressed after
  cancellation. Existing current-Task identity checks remain in place.
- Native media error wording recognizes explicit authentication/rate/connection
  refusals without creating a second provider stream to inspect HTTP headers.
  A native Video error does not necessarily expose Retry-After or HTTP details.

## Verification

Actual requestJson/requestPages tests cover no automatic 429 retry, transient
GET cancellation before retry, Retry-After seconds/date/invalid/too-long cases,
no mutation retry, malformed JSON and repeated pages.
Existing Task-body and lifecycle tests also pass with cooperative cancellation.

Native `tests/cache-probe` phase `http` recorded:
- Valid JSON success.
- 64-byte test cap rejected a larger summary response as `response-limit`, one attempt.
- Deliberately invalid probe credential classified `authentication`, one attempt.
- Pre-cancelled operation classified `cancelled`, zero transfer attempts.
- Zero `aeriotv-http-*.json` staging files remaining afterward.

No shared server setting or stream source was changed. Rate-limit/server-failure
branches used deterministic transport-boundary tests; no production overload was
manufactured to force 429/503.
