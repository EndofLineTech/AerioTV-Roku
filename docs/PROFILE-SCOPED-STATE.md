# Scoped-state implementation (`mrr.7`, in progress)

`source/UserProfileScope.brs` supplies scoped-state primitives. Verified
Dispatcharr connections now activate per-account settings through
`UserProfilePreferenceNavigation`, **not a public profile switcher or completed
application isolation**.

## New-account seeding

The new blob is built from spec14 step3.4's exact account/guide Copy allowlists.
All other account data starts empty, including future unknown fields, favorites,
recents, progress, collections, reminders, per-content overrides and startup
group. Nested settings are deep-copied, not shared with the default account.

The approved appearance/player extension is `profileSettings`: theme/preset,
accent, panel/text/contrast, audio mode, live transport/startup retries, video
fit, archive skip and player-info visibility. Clock, accessibility, networking,
remote mappings/direction and physical signal/display controls remain local.
The explicit field catalog is in `userProfileSettingsFields()`.

Inputs are type-filtered before entering legacy normalizers. Validated output
is canonicalized so a native case-sensitive map cannot retain an older raw
camel-case value beside a lower-case normalized value. This handles the new
scoped boundary; it does not close the separate general old-model audit `9sq`.

## Migration and write planning

`userProfilePrepareSettings` preserves existing account data and copies the
normalized legacy device baseline only when `profileSettings` is absent. An
empty present map is an intentional settings value. A malformed present root
requires recovery rather than importing another user's effective preferences.

`userProfileSettingsCommitPlan` stages a single preference-store value: profile
changes belong to the target account, physical-device changes remain on the
device, and the original appearance/player baseline stays available for other
unmigrated defaults. Existing unknown settings are preserved on own-account
writes but never seeded to a new account. Plans do not mutate the source store
or authorize adoption before a successful persistence operation.

## Immutable callback identity

Session context includes slot, local profile UUID, verified server user ID,
preference identity, authorization generation and fresh session UUID. The
existing default preference identity remains `base|user|slot`. Returning A → B
→ A creates a different session identity, so an old A callback cannot become
current just because its account ID matches again. Different assignments and
different slots also retire old contexts.

## Evidence and remaining integration

The shared scope tests run on host and Roku, including malformed settings,
settings-only seeding, A/B/A, two-slot separation, typed IDs, generation changes,
legacy migration and nonmutating write plans. `commitUserProfilePreferences`
checks the captured/active immutable context before one atomic settingsV1
transaction, refuses oversize writes without eviction, and reports rollback
recovery explicitly. Faults and late writes are tested on host/native fake
registries; actual private-registry roundtrips preserve own data and the other
user and refuse a stale-session write without changing stored bytes.

The extended native suite passes 286 assertions with private-registry cleanup
and exact prior-app restoration;
report: `out/profile-scope-native.json`.

## Application routing and normal-app evidence

The normal Dispatcharr connection stages settings under the verified active
profile's identity and authorization generation, persists them atomically, then
adopts the session and effective appearance/player settings before configuring
the guide. During connection transitions, scoped persistence cannot fall back
to writing another profile's effective settings into the device baseline.
Routine preference writes use the captured current scope; failure does not
adopt a replacement store and rollback failure fences further profile work.
Connection reset retires the active scope and restores the device baseline.

The controller's shared native tests cover activation, own-data preservation,
single Flush, profile/device separation, stale scope refusal, failed activation
without presentation adoption and mismatched-account refusal.

`scripts/test-profile-settings-native.py` exercises the **actual normal app**
against synthetic own-key HTTP accounts and a unique private registry/cache.
It runs two-slot A → B → A across reinstalls: A migrates Sunset and saves
Midnight, B retains Forest, then A restores Midnight with its stable default
profile ID. Each keeps its own favorite and the original Sunset device baseline.
All three screenshots were captured/inspected (Midnight/Forest/Midnight guide
colors). The section is cleaned and the checksum-matched prior app restored
after each run. Report: `out/profile-settings-native.json`.

This is **two-slot** settings isolation, not same-slot authenticated profile
switching. The populated normal-app rerun also verifies that each own-key
account receives only its own synthetic channel (7/8/7) and keeps its FAV marker.
The A run also injects one failed settings Flush through a private registry
proxy while exercising the real remote-map controller. The prior registry
bytes, active Midnight appearance and original Sunset device baseline all
survive rollback; existing settings-controller rollback restores the entire
prior store, never the effective profile appearance into the device baseline.

## Task retirement

Account-bound network Task constructors capture the active session nonce before
RUN. The shared callback guard checks both actual Node identity and this nonce;
returning to A cannot revive an old A Task. Transport admission, in-flight
download polling and cache authorization also reject a retired Task's nonce.
Initial authentication (before an active session), the shared policy broker and
explicit owned-session/temp-file cleanup have distinct lifecycles; outgoing
cleanup never borrows the incoming account's key.

Constructor coverage is checked across production component scripts. Shared
host callback tests cover retirement/A/B/A. The native request-gate fixture
captures a real Task session, begins a delayed HTTP response, retires that
session, verifies cancellation and refuses a second HTTP path/cache access.
Its full expanded 13-group matrix still passes with exact prior-app restoration.

## View event envelopes

Guide, Browser, VOD, DVR, Settings and on-demand media capture the session from
their explicit configured model/request, not the global identity when delayed
data is emitted. Preference/state/bookmark, playback/record/archive/history and
search-selection events carry that captured nonce; owning handlers reject stale
events. Preference merges strip the transient field before persistence. The
native accent keyboard retains its opening session independently of rerenders.

On-demand close/seek/go-live use additional assocarray context signals; legacy
scalar outputs remain available, but the normal app observes the scoped signals.
Host handler tests exercise stale controls without account/archive/storage state
present, proving refusal occurs before work. An untagged legacy seek cannot
bypass an active scoped session.

The normal-app native fixture now toggles favorites through the real Guide save
path and injects stale Guide preferences, VOD history, Settings, Guide/Browser
watch/history actions and media close/seek/go-live controls. All three cases
reject them, preserve current state,
perform no unintended playback/dialog transition and persist no `aeriosession`.
Private registry cleanup and exact prior-app restoration pass.

Authorization-refresh generation adoption, remaining dialog/control event audit,
complete pending-write coverage and same-slot native A/B/A acceptance remain
implementation work. No public switching or complete `mrr.7` delivery is claimed.
## Legacy owner reconciliation and cold-process selection

The original `legacy` Dispatcharr slot can reconcile unscoped `preferences`
only after its own verified default matches the original `serverUrl` and
`accountIdentity`. An existing default with a different username or ID is not
that owner. The old slot-less account blob, canonical owner blob, and unscoped
object merge only when overlapping leaves agree; differing private arrays or
values are a recovery condition, never a last-writer-wins guess. Malformed,
empty-present, conflicting, and over-budget sources remain untouched.

The canonical owner data, stable default roster, and retirement of the consumed
legacy value share one registry transaction. A failed Flush restores exact
previous bytes and absence. Unknown fields and binary64 values survive. The
rendering path no longer reads unscoped preferences. Unrelated connections do
not consume or delete them, and replacement/address fences remain until the
owner's migration succeeds. A strict raw migrated root may have sparse device
settings; only its device runtime baseline is normalized before presentation.

At process launch, a selected full-access non-default with no remembered own key
or an address hold restores the default before any credential is read. This
selection is committed atomically; failed persistence prevents connection.
Remembered own holders remain selected. A Child never takes this automatic
fallback. This does not authorize active-key rejection/reconnect fallback, which
must retain the active holder, or claim completion of Child unavailable/escape,
public picker, or sync lifecycle work.

## Own refresh and unavailable full-access recovery

Connect and manual lineup-refresh Tasks now derive identity binding and Channel
Profile filters from the persisted selected holder. Non-default Tasks clear both
default filters and bind their own user ID and username. Default Tasks retain
the slot's complete `channelProfileIds` choice. Capability refresh also binds the
username; a same-ID response for another username is not accepted.

Network results retain only allowlisted identity/assignment/permission facts,
never passwords or API keys inside `verifiedUser`. A changed assignment or
permission signature retires the old session and reconnects the same holder
through its own authentication/roster/full-lineup path. Old UI callbacks cannot
write into the new session, and this reload does not auto-play. Server promotion
or demotion updates and stamps only that holder's roster row atomically; failure
keeps the application covered instead of granting unsaved authority.

An active non-default Admin/Standard whose key was refused now receives its own
“Sign In with Remote” / “Not Now” prompt, without a playlist-edit or phone-update
action. Its own form runs under a fresh credential-task nonce, **not** a fabricated
authenticated user scope. The existing PIN still gates the form. A successful
own-username login may move a recreated user's data and key, then starts a fresh
own-user authentication/roster/reload before exposing content. Cancel, including
Back during delayed verification, retains the unavailable holder and cover.
The default key is never borrowed. A rejected non-default Child receives neither
this prompt nor this form. Active-default/Child recovery and Child escape remain
separate unfinished integration, not implicit authorization from this path.

General setup now hides the default sign-in and Channel Profile rows while a
non-default is selected. Independent field guards refuse forged method/key/
password/username/Channel Profile callbacks; reconnect, Remember and eligible
address edits remain available to full-access holders. A persisted Child is
never rendered on the general setup page, including failure paths.

The general native setup keyboard also captures its exact node, fresh editor
nonce, selected connection, persisted roster, field and current session. A late
callback cannot change credentials after A → B → A or a replaced editor. Its
connection snapshot uses the registry loader's normalized representation:
native in-memory patch aliases are not a valid byte-comparison baseline.
