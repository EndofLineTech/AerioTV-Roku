# Dispatcharr Sync controls

The profiles-only controls are available in the Beta profiles build. Readiness
does not grant account access or opt a Roku into Sync. Explicit consent is
required. See [delivery status](MRR-DELIVERY-STATUS.md) for historical two-account
PUT/readback/acknowledgement/Off qualification. That qualification is not blanket
permission for future writes and is not Apple or Android Sync acceptance.

The approved delivery phase was **profiles-only**. The owner extended it on
2026-11-23 (`e3e.7`) with the Guide [favorites](#favorites) category. Other
unsupported categories and settings lanes are still preserved, not additional
adapters required for this phase.
Neither that phase nor this document closes the broader `e3e.7` Shared/TV/Off
settings-scope requirement or its direct blockers `e3e.4` and `e3e.6`.

## Explicit roster suggestions

Follow-on Add source offers **From your other devices** when a verified read in
the current own session supplied missing users. Profiles Off, an address-held
holder, or a retired session suppresses the offer. Lists are bounded to five
profiles per page. Choosing one only prefills its username in the existing
own-credential form: it does not save a holder, copy credentials or grant access.
The normal fresh own-account authentication/protection read still applies the
current roster metadata and PIN before committing Add. Existing roster-add Undo
semantics remain unchanged. This also works through onboarding's Add action.
The Add lifecycle also retains the current source session's received row for
manual username matches. An absent target envelope cannot turn that roster user
into a newer unprotected plain Add. An equally recent or newer target row wins.
A newer source row is usable only when it agrees with the target's own PIN and
role. Conflicting protection, unverifiable PIN material, or a mismatched live
user ID refuses. The selected row's stamp is retained
(zero becomes now), and roster Undo remains local without a tombstone.

Focused actual-controller evidence:
`out/mrr-delivery-roster-offer-red.log` and
`out/mrr-delivery-roster-offer-green.log`.
The focused source-row regression is
`out/mrr-delivery-source-roster-add-{red,green}.log`.

## Delivered boundary

- The existing selected Connection manager offers **Dispatcharr Sync (this Roku)**
  only when the feature is ready and there is a current full-access Dispatcharr
  holder. There is no new Settings rail category.
- Choices are device-wide: explicit Sync On/Off, Profiles On/Off and
  Favorites On/Off. Sync and Favorites default Off. Profiles and Favorites are
  owned by this writer; other categories are preserved unchanged, not claimed
  implemented.
- The menu explains device scope and preservation. Scheduled sync waits until
  the menu closes. Off cancels scheduled work and stops its timer without
  clearing durable pending edits.
- Status distinguishes Off, Profiles Off, pending changes, offline, address-held
  profiles, sign-in pause, capacity refusal and oversize refusal.
- `settingsV1.device.dispatcharrSyncEnabled` and `dispatcharrSyncProfiles` are
  local choices, not profile settings and never App Data fields. The app reads
  them before early roster processing. Sync Off does not erase existing profile
  protection; explicit Profiles Off prevents category application/writing.
  During Add, a safety read may refuse a protected holder when Profiles is Off;
  it never applies the target roster. During an address pause, Add verifies its
  own credentials without the App Data read and records a durable paused
  origin. That holder cannot launch, switch in, or be published by Sync. A
  roster read under a different holder is not the deferred holder's required
  own-protection check, whether or not the read contains a matching row.
  Undo and Manage Profiles → **Remove from this Roku** remain local and do not
  acknowledge other edits. After resolving the address holds, remove this entry
  and use normal Add to read the holder's own
  protection. A keyless sibling
  still pauses the entire slot. After the final hold lifts, the durable write
  fence survives failed reads, backoff, and session changes until a current
  own pull commits. Pending edits still require a separate acknowledgement.

`DispatcharrSyncSettingsStore.brs` commits only those device members in one
bounded transaction. Admission independently verifies the actual adopted scope,
selected connection, current full-access holder and own key/hash, exact captured
connection/roster/settings roots, current credential and broker. It never
constructs an authenticated scope or read receipt to authorize Settings.
Child, held-own, stale A/B/A, changed roots/keys, malformed existing choices and
write/Flush failures refuse safely. Unknown root/device/account fields and native
number kinds remain intact. Missing choices do not cause a normalization write;
malformed opt-in never enables sync. A valid explicit Profiles Off is retained
even if another sync choice is malformed.

## Favorites

The Sync menu (Connection manager → **Dispatcharr Sync (this Roku)**) shows,
in order: **Turn On Dispatcharr Sync** / **Turn Off Dispatcharr Sync**,
**Turn Off Profiles** / **Turn On Profiles**, **Turn On Favorites** /
**Turn Off Favorites**, and **Back**. The choice is stored as
`settingsV1.device.dispatcharrSyncFavorites` (exact case, boolean) in the same
bounded transaction as the other choices. If the member is missing, Favorites
is Off. A malformed value fails closed, like the other choices. A change that
does not name Favorites keeps the stored member. Status shows
`On — Profiles and Favorites`, `On — Favorites` (Profiles Off) or
`Changes pending` when this profile has unsent favorites.

Favorites work only while Sync **and** Favorites are On. Profiles may be Off.
In that case the scheduler still runs its own pulls and writes, but it never
imports roster data or writes the profiles category.

- **Pending.** A Guide favorite toggle (`onPreferences`) marks the active
  profile's favorites pending only while both switches are On. The existing
  one-second dirty debounce schedules the write.
- **Profile-owned state.** It lives in that profile's account preferences as
  `dispatcharrSyncFavorites: {pending, acknowledgedAt}` beside `favoriteIds`.
  It is never a device or wire field. Removing a profile removes it.
- **Pulls.** Every scheduled own read (session start, 15-minute cadence,
  picker and network return) returns the server category. A category newer
  than `acknowledgedAt` is applied with `dispatcharrSyncFavoritesOnNewerPull`:
  - Clean: the server order wins, but a local favorite outside the current
    lineup is kept.
  - Pending: union, local first. Untranslatable server ids stay on the server
    and are carried on the next write.
  - First sync: a profile with local favorites and no sync record merges
    instead of replacing.
- **Lineup.** Translation uses only the active session's Dispatcharr Guide
  lineup (`syncFavoritesLineup`: channel `id` + `uuid`). Without one, nothing
  is applied, acknowledged or written.
- **Guide refresh.** Applied lists persist to the active profile and refresh
  the favorites group and FAV badges (`applySyncedFavorites`) without
  republishing them as a local edit.
- **Off.** Off never applies pulled favorites and never rebuilds the category.
  A whole-envelope PUT for profiles carries it unchanged.

Console lines for QA (counts only, no ids):
`[dispatcharr-sync] favorites pending count=`,
`[dispatcharr-sync] favorites applied count= … pending=` and
`[dispatcharr-sync] favorites acknowledged pending=`.

Limit: edits made while Favorites or Sync is Off are not marked pending. A
profile that already synced and is later re-enabled takes a newer clean server
list for lineup channels; off-lineup favorites are still kept.

## Qualification

Host tests cover explicit choices, shipping-off/Child refusal, stale context,
exact roots, own credentials, dirty retention and transactional rollback.
Native model tests also preserve case-distinct future members, binary64,
integral doubles, milliseconds, null and emoji.

The first real UI run exposed an exact-case registry defect: a literal change
map wrote `settingsv1`, not canonical `settingsV1`. A new case-sensitive registry
fixture reproduced it; explicit string-key assignment fixes it
(`AerioTV-Roku-91x8`). Another tests-first regression proved that the activation
helper restarted the timer after Off; it now requires explicit enabled/Profiles
admission (`AerioTV-Roku-w0ir`).

Final normal-app native qualification, without controller diagnostic injection:

- Real ECP On → Profiles Off → Profiles On → Back → B-own me/list/key read → Off,
  with seven HTTP-200 key acknowledgements, zero requests before menu closure,
  unchanged source scope, foreign accounts/default credential retained, no PUT
  acknowledgement invented, and final timer stopped:
  `out/mrr-sync-controls-final-native.log`.
- Separate-process relaunch preserves explicit Sync On/Profiles Off and pending
  edits, restores B with its own key/fresh scope, and refuses to apply a received
  Profiles PIN/Child row while that category is Off:
  `out/mrr-sync-controls-cold-qualified-native.log`.
- Native case/precision/fault matrix:
  `out/mrr-sync-controls-final-primitives-native.log`.
- Existing restricted Child Settings regression:
  `out/mrr-sync-controls-child-regression-native.log`.
- Full verification:
  `out/mrr-sync-controls-qualified-verify.log` (0.3.100, 346 files).

The controls screenshot was inspected: bounded explanatory text and three
remote actions fit. A later capture also showed Roku's mobile-keyboard system
overlay; this is not claimed resolved or causal for intermittent ECP delivery.
Earlier Select timeouts were foreground/no-screensaver runs and remain recorded
under `667m`; later successful delivery is not proof of their cause.
All isolated runs, including failures, cleaned disposable sections and restored
the exact owner app. No network reconfiguration, certification, release or owner
acceptance is implied.

The current read-only qualification (`scripts/test-sync-controls-readonly-native.py`)
uses the released v0.3.102 ZIP as the exact restore target. It opens the existing
Connection manager route, then drives the Sync submenu with actual ECP keys:
Off → On with a keyless sibling held → Profiles Off → Profiles On → Back →
hold release → own read → Changes pending → Off. The hold and release are
disposable local fixture state, not a server URL change. The probe refuses
mutating HTTP and requires that pending edits remain without an acknowledgement
and that the disposable registry section is removed. The qualification report
is `out/e3e7-controls-native-qualified.json` (seven ECP HTTP 200 responses with
matching dialog state/focus). Offline native fixture qualification is in
`out/e3e7-offline-model-qualified-native.log`; it does not run a provider
fixture or modify the Roku registry.

## e3e.7 evidence and limits

| Criterion | Evidence | Not established |
| --- | --- | --- |
| Explicit adoption; manual match keeps stamp and protection | `ProfileOwnSignInNavigation`, `UserProfileOwnSignIn` and `out/mrr-delivery-source-roster-onboarding-native.json`. Choosing a suggestion only prefills the username. A newer valid matching peer row can restore a removed user; imported Child Add still requires all existing adults to have PINs. | The complete peer-controlled Add/Undo and PIN-required continuation on physical clients. |
| Strict merge, stamps, claims, cap, tails | `DispatcharrSyncMerge`, `DispatcharrSyncRoster`, `DispatcharrSyncRosterWrite`, `UserProfileModel`, `UserProfileManagementPolicy`, `PhoneSetupProfiles`, and the native §16.4 JSON fixture. The §16.7 split case retires a tombstoned local holder but keeps a newer peer row as a suggestion. | No literal timing assertion from a phone. |
| Tombstones, stale-device guard, cleanup, re-add and pending | `DispatcharrSyncRosterWrite`, `DispatcharrSyncAckStore`, `out/mrr-sync-own-retirement-native.log` and `out/mrr-sync-unchanged-settled-native.log`. Successful acknowledgement clears only removal intent from its exact snapshot; failure and stale receipts keep it. | No fresh deployed PUT or real peer-driven delete/re-add in this qualification. |
| Held slot, Undo, resume | `UserProfileOwnSignIn`, `UserProfileLifecycle`, `DispatcharrSyncMerge` and `DispatcharrSyncAckStore`. A held profile need not have a key to gate the slot. Another holder's roster does not resolve deferred Add protection. Held failures do not acknowledge or clear pending changes. | Combined physical peer/server address-replacement scenario. |
| Cadence and pull-before-PUT | `DispatcharrSyncSchedule`, `DispatcharrSyncWriteTask`, `out/mrr-sync-session-scheduler-final-native.log`, and `out/mrr-sync-network-events-native.log`. The authenticated switcher queues picker work against the actual session and refreshes its idle snapshot safely. | Cold/no-session picker has no authenticated actor; Add's credential form suspends background work. Timing arithmetic is not a physical 15-minute soak. |
| Unowned and Off categories/settings | `DispatcharrSyncMapping` selects `v`/`tv`/Off with no fallback; `DispatcharrSyncWriteBody`/`DispatcharrSyncRosterWrite` exercise checked, typed pass-through of `v`, `tv`, `mobile`, future rows and milliseconds on peer-shaped payloads. | There are no active settings lanes, lane-seeding transitions or per-item Shared/TV/Off controls; the general engine remains `e3e.6`. |
| UI/status/focus and peer round trips | Native control and cold-restoration reports above; the read-only live driver checks actual ECP focus and pending state on the approved test Roku. Peer-shaped native fixture round trips prove Roku's wire behavior only. | Named Apple/Android Sync clients producing, consuming and applying these writes were not exercised. Setup encoders are not Sync readers. |

### Host-only Profiles writer follow-up

The writer's size/quota preflight and scheduled retry classification are
covered by host mapping, checked-body, Task, scheduler and Scene-controller
tests. Refused writes leave pending intent and do not trim peer data or create
an acknowledgement. Preflight storage-full does not latch an account's
canonical creation; an oversized snapshot permits read-only refresh and a
genuine local edit can retry. These are offline tests, not new device/peer
qualification.

The owner confirmed the delivery scope remains Profiles-only. The checked-in
mapping describes settings lane selection and typed pass-through, not a versioned
setting-key/value contract for a Roku adapter. Any future Shared/TV/Off settings
phase would require approval and a contract covering keys, value kinds,
defaults, missing lanes and scope-transition seeding. General category adapters,
full-category legacy migration, and device/peer acceptance are not established
by this host-only work.
