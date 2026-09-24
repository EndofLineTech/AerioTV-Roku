# Credential policy for Roku connections (ah5.2)

The Product Owner chose **opt-in per-connection API-key persistence**. The
existing Dispatcharr connection remains compatible with its Remember choice;
new named connections default to session-only until their own Remember choice
is enabled. Roku's app registry is a small persistent store, not Apple's
Keychain or an encrypted credential vault. Anyone with access to the signed-in
device can use a remembered account. Clearing Remember removes that connection's
saved key; Forget removes its saved key and account-scoped preferences.

Dashboard passwords and Xtream/provider passwords are **never persisted on the
Roku**. A dashboard password is sent once to the configured Dispatcharr origin
to obtain the signed-in account's API key, then cleared from the Scene and Task.
Provider credentials entered by an authorized administrator for a Dispatcharr
import are sent once to that same existing server. Dispatcharr owns its provider
configuration and proxy; the Roku retains only bounded non-secret connection
metadata and, if chosen, its own Dispatcharr API key. Dispatcharr 0.31 returns
stored M3U-account passwords in **admin** list responses; the Roku Task must
whitelist non-secret fields and discard those response values before publishing
to the Scene. No provider password, secret URL or raw provider playlist is
written to Roku preferences or public evidence.

The later approved **direct Xtream connection** changes the runtime boundary:
the XC username/password live in Scene/Task memory for the current session only,
because `/player_api.php`, `/xmltv.php` and `/live/...` require them in the
configured server's URL. A new app launch requires re-entry. They are never
written into the registry, preference store or metadata cache, never printed,
and are cleared on switch/Forget/failed verification. Send them only to the
explicit Xtream origin. Direct M3U/XMLTV URLs saved in a connection cannot
contain userinfo or query parameters; signed private URLs need a different
session-only design before support can be claimed.

When an API key expires or is revoked, the Roku will stop using it and show
explicit re-login. There is no automatic dashboard password replay and no
assumed long-lived refresh token. A changed authenticated user identity requires
reconnection before account preferences, guides or media are restored. Local/WAN
address switching must verify the **same Dispatcharr account** before sending
the key to an alternate configured origin; never follow credential-bearing
pagination/media URLs to unrelated hosts. Native network and account-switch
tests are tracked by the remaining ah5 stories.

This decision preserves a session-only path and does not claim equivalence to
iCloud Keychain. See [Roku file-system storage limits](https://developer.roku.com/dev/docs/file-system.md)
for the app registry's 32-KiB maximum.
