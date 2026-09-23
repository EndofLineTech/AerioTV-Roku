# Named Dispatcharr connections (0.3.72 candidate)

The setup screen's Connection row opens a saved-connection picker. Manage saved
connections adds a session-only slot, renames or reorders the selected slot,
and offers a confirmed Forget action. The separate Forget button acts only on
the selected slot. Up to four Dispatcharr slots are supported. Each slot owns
its server URL, verified account ID, optional Remember choice and saved API
key; the key lives in a separate app-registry value, not the roster JSON.
Dashboard passwords stay session-only. See
[credential policy](CONNECTION-CREDENTIAL-POLICY.md).

The first launch with an older single-server registry entry presents it as
**Main** without writing over the old data. Once the account connects, its
saved key moves to its own slot and its account preferences move to a
connection-scoped identity. Migration of older unscoped preferences requires
the original server URL and account ID to match; changing the URL cannot
carry favorites to a different server. Switching slots cancels old metadata,
media and capability requests, clears the guide instance and its observers,
and reconnects only if the selected slot has a remembered key. Changing a
slot's server URL removes its old key first and requires new sign-in. Forget
removes that slot's key and preferences without removing other slots.

`ConnectionStore.test.brs` and `ConnectionNavigation.test.brs` exercise
bounded storage, legacy migration, scope isolation, failed replacement-key
writes, and queued stale-guide preference events. `npm run verify` passes for
this candidate. On the Roku, initial guide startup, setup navigation, picker,
add, and rename were observed on the earlier candidate. The latest fixes to
key-write failure handling, guide observer detachment, and preference migration
still require a new native install and account-switch/Forget/restart checks.
The screenshots are private under ignored `out/`; scripted navigation alone
does not establish physical-remote acceptance.
