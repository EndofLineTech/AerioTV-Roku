# Own-account App Data reads (in progress)

`DispatcharrSyncKey.brs` implements the shared schema's UTF-8 byte key algorithm:
ASCII uppercase only is folded, unsafe bytes become `-xx`, nonalphanumeric
starts receive `u`, the encoded name is cut at 46 characters (even within an
escape), then `.aeriotv` is appended. Empty usernames wait. No trimming, Unicode
case folding or alternate key scheme is applied.

Read discovery validates the bounded server key list. The canonical key wins
over legacy keys. Legacy-only data yields a migration-required/read-only plan,
with all legacy sources retained for a future full category merge. It never
creates an empty canonical replacement or writes/deletes a legacy record.
Every plan explicitly has `allowWrite: false`.

`DispatcharrSyncReadTask` is an **internal, not UI-activated** read-only Task:

1. Verify `/api/accounts/users/me/` using its own supplied credential and match
   the expected account ID and case-insensitive stored username.
2. Read the same user's key list; never use an admin cross-user endpoint.
3. GET only the canonical key when listed. A missing canonical key or legacy
   migration requirement does not trigger any write or arbitrary legacy read.
4. Treat only a canonical GET's structured `404 key_not_found` after successful
   listing as missing. Forbidden/unsupported endpoints, proxy 404, transport
   failures, parks and malformed objects do not become absence/write permission.
5. Parse through native `ParseJson(text, "d")`, not shared `requestJson` or
   `copyJson`, preserving case, doubles, large integer stamps and unknown data.
   Future schema versions are reported read-only, not downgraded.

Transport admission, response bounds, cancellation and session retirement use
the existing request gate. The Task clears its credential before publishing a
result and does not log bodies or credentials. The `ready` state denotes a v3
object **candidate**, not an accepted roster: strict envelope/category/row
validation, merge/role/PIN/tombstone rules and application gates remain required.

Host tests cover the shared key vectors, malformed discovery, own-identity
refusal, legacy/missing records and HTTP failure distinctions. Native primitive
tests also exercise actual UTF-8 accented/emoji usernames, with exact prior-app
restoration (`out/dispatcharr-sync-key-native.json`). The isolated request-gate
fixture's 14-group matrix now includes 13 real native HTTP discovery cases:
canonical/legacy/missing, structured versus proxy 404, forbidden/unsupported,
wrong user/username/string-typed identity, malformed/future/integral-float schema.
It checks exact allowed paths, no cross-user/legacy reads, no mutation methods,
and preservation of double settings and millisecond integers through the Task
result. The full matrix, including existing media fencing and slow recheck,
passes with exact prior-app restoration (`out/request-gate-native.json`).
None of this is a claim
of measured production-server limits, sender interoperability, completed roster
import, sync writes or public profile switching.
