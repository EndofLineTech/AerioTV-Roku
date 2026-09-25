# Connection credential recovery (0.3.73 candidate)

The Roku persists no dashboard password or refresh token. It cannot silently
refresh a revoked Dispatcharr API key. An HTTP 401 or 403 from the account
verification endpoint (`/api/accounts/users/me/`) now requests explicit
re-login. On that result, the Scene stops playback and account-bound requests,
invalidates the old guide and media state, deletes the selected slot's saved
key, and returns to setup without reusing the rejected in-memory key. If local
key deletion cannot be confirmed, the screen says to retry Forget before
relaunching. A verified change to a different account ID takes the same path.
An optional operation's HTTP 403 is not treated as account revocation.

Other failures, including temporary network/server errors, retain the key
for manual retry; no dashboard password is replayed and no automatic auth
retry loop is introduced. A newly entered password can be submitted once to
the existing Dispatcharr server to obtain the account's API key. Remembering
that key remains the viewer's per-connection opt-in choice.

The Task and HTTP policy tests exercise 401, 403, 503, optional capability
denial, and changed-user outcomes. On the Streaming Stick 4K, 0.3.73 installed,
automatically restored the remembered Main guide, and rejected one deliberately
invalid key on a newly added session-only slot. The native setup screen showed
an empty key field and requested re-login. The disposable slot was forgotten;
Roku Home then relaunch again populated Main's guide. This is a controlled
invalid-key test, not a real key rotation or provider revocation. Private
captures remain under ignored `out/`. A real revocation, changed-user account
and storage-write failure still need authorized fixtures; they are not inferred
from tests. See [connection policy](CONNECTION-CREDENTIAL-POLICY.md).

The PO closed `ah5.3` on 2026-09-25 with these fixture limits accepted.
Real revoked/rotated-key and storage-write cases are not retroactively marked
as physical PASS.
