# Scoped-state implementation (`mrr.7`, in progress)

`source/UserProfileScope.brs` supplies internal primitives, **not an activated
profile switcher or completed application isolation**.

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

Application settings load/write routing and recovery UI, callback
tagging/retirement, library caches, pending writes and native A/B/A UI acceptance
are still implementation work. No public switching or complete `mrr.7` delivery
is claimed by these primitives.
