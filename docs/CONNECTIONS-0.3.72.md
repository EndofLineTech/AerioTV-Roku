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
this candidate.

On the Roku, the patched build installed and launched. A prior session's
renamed session-only slot survived the install. Selecting remembered **Main**
repopulated the authorized guide; switching back to the session-only slot
showed no saved key and did not reconnect. Its Forget confirmation named the
selected slot; confirming removed that slot and returned to **Main (1 saved)**
with Remember still on and its key masked. Roku Home then relaunch restored
Main's populated guide without entering credentials. These are scripted ECP
navigation and local private screenshot observations, not physical-remote or
audio/video acceptance. The screenshots remain under ignored `out/`. A second
authorized account, actual key revocation, and failed registry writes were not
exercised on the device; the failure and stale-event paths have controller
tests only.

In the later 0.3.80 candidate, the migrated legacy slot retains its
non-secret server URL/account identity and the former Remember choice as a
bounded recovery fallback; only the legacy key is removed after its scoped
key is saved. A credential-free Task probe used a separate Roku registry
section to migrate a dummy legacy slot, delete the saved roster, and confirm
the slot and its scoped key were recovered. The probe cleaned its keys and
the normal development channel was restored. An earlier unexplained loss of
the real Main slot during experimental sideloads did not reproduce with a
disposable Dispatcharr slot across a normal reinstall or a deliberate early
startup crash; it remains tracked separately as `AerioTV-Roku-itx`.
