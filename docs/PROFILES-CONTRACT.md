# Dispatcharr user profiles: Roku implementation contract

Contract for `AerioTV-Roku-mrr.1`, November 12, 2026. This describes required
behavior, not a claim that profiles or sync have shipped. Beads remains the work
and decision register. The owner has authorized implementation and native tests;
that supersedes the earlier planning-only authorization, not the acceptance,
entropy, shared-contract or certification gates.

## Controlling references

The owner-supplied `roku-profiles-and-dispatcharr-sync.md` (November 12,
SHA256 `9f7c94873ec9b0f958f7aaf3f7cec7f0dafa129974264308dbb799e42b19ca1a`),
corrected `DispatcharrSyncSchema.md`
(`54731d14cdc4e276e044f0eb7bce7e3778dd3775c5885ec940b213cb9129cfbb`) and
`DeviceSetupHandoff.md`
(`a4ac97033a2b067403a2e840d835f787d788f89c7c0050fac0b7d6cb911ff3e4`)
are the implementation baseline. Originals are in the owner's Downloads.
`README for Mot.md` sets precedence. Conflicting November 8 Interop appendix
prose and old issue descriptions are historical, not alternative contracts.

Apple source reviewed at [`d75589d`](https://github.com/jonzey231/AerioTV/tree/d75589d):
`Shared/Profiles/{ProfileRules,ProfileStore,ProfilePinStore,ProfileDataStore,ProfileManager}.swift`,
`Shared/Dsync/DsyncSettingsMap.swift`, and
`Features/Settings/{ProfilesSettingsSection,ProfileSwitcher,ServerDetailView,SettingsView,TVSettingsSplitView,AppearanceSettingsView,PlayerSettingsView}.swift`.
The supplied spec header identifies subsequent peer fixes; its corrected hold,
undo, rejection and setup semantics take precedence over that older snapshot.
Do not claim independently executed Apple/Android interoperability from a source
review; acceptance must name the actual peer builds exercised.

## Owner dispositions

Recorded from the kickoff discussion; not inferred from permission to implement:

| Section 20 | Disposition / boundary |
| --- | --- |
| 1 Entropy | Import/verify existing v2 PINs only until Logan/shared-spec production entropy approval. No Set/Change/Reset/new Device Admin/PIN Required walk. The shipping setup receiver stays closed. |
| 2 Envelope platform | Owner approved `roku` after native qualification. Shared-document confirmation remains pending; do not claim Logan approved a change. Readers already accept arbitrary strings. |
| 3 Registry/local cap | Owner approved an initial four profiles per Dispatcharr slot, including default (maximum16 across four slots), adjustable only after full-app measurements. Native four-slot/key54/full24KB preference fixtures fit; wire cap25 is not the local cap. |
| 4 Settings location | Model Apple TV/iOS: Settings > Playlists > selected Dispatcharr playlist > Profiles. Roku equivalent uses the existing Connection area and selected slot, not a tenth Profiles rail category. |
| 5 Device Admin/kid-only | Deferred with new-salt creation. Imported Child profiles require existing full-access PINs and a usable protected exit; no new Device Admin onboarding. |
| 6 Interim protected default | Refuse before provider authentication or persistence. Never silently convert a Child/PIN-protected default into an unrestricted slot. |
| 7 Appearance/player scope | Model Apple per-profile settings behavior. Migrate supported appearance, accent and player settings to account scope; keep hardware/network/remote controls device-local. |
| 8 Child deep links | Route through the default profile's required PIN gate, subject to native/certification verification. Never silently grant adult access. If no safe authenticated route exists, do not play. |
| 9 Directions PIN | Build/test D-pad entry behind a developer-only gate. Public PIN-dependent profiles remain release-blocked pending certification/access disposition, including all-Directions households. No PIN bypass. |

Apple placement is verified in `ProfilesSettingsSection.swift` (header and both
platform sections), `ServerDetailView.swift` (iOS/tvOS insertion) and
`ProfileSwitcher.swift` (Manage Profiles route). Apple scopes settings through
`ProfileSettingsStore.scopedKeys`, which includes `DsyncSettingsMap.ENTRIES`, and
seeds from the default profile. Roku should reproduce the isolation, not Apple's
global UserDefaults swap implementation. This does not rename the existing
Connection category or change unrelated navigation.

The owner also chose to raise the application's minimum supported Roku OS to
**14.6**, rather than keep older devices sync-read-only. Roku introduced the
ParseJson `d` precision option in14.6 ([release notes](https://developer.roku.com/dev/docs/release-notes),
[developer announcement](https://blog.roku.com/developer/roku-os-14-6)). This is
the requirement for the upcoming profile-capable build, not a claim that the
Developer Dashboard has been changed. Minimum firmware is a Dashboard submission
setting, not an invented manifest attribute. Final delivery must verify it and
guard direct developer launches before precision-dependent parsing/writes.

## Identity, storage and authority

- A connection slot is one playlist (maximum four, unchanged). A user profile is
  a real Dispatcharr account within that slot. XC/M3U do not acquire user profiles.
  Dispatcharr **Channel Profiles** are server lineup assignments, not household
  identities; new code uses `UserProfile*`. User-facing messages must distinguish
  the two meanings.
- Exactly one stable default per Dispatcharr slot. Construct it from the live
  verified `/me/` user ID and username, not an empty manually saved slot username.
  Its key remains `connKey_<slotId>`; non-default activity must never overwrite
  or delete it. Initial default creation has no roster stamp.
- Other keys follow Remember, stored separately from non-secret roster metadata;
  no passwords at rest. Remember off removes all slot key registry copies but
  retains session-only keys until normal session teardown/relaunch. Return to the
  default in that session must not lose its memory-only key.
- Profile IDs are stable, lowercased/registry-safe on import. Match local users
  case-insensitively by username; wire dedupe uses integer userId. Validate
  imported IDs before forming key names. Display names are bounded to 40 UTF-8
  bytes at code-point boundaries. Order is stable with explicit order first;
  never-moved ties follow default/creation/insertion order. Move stamps every
  changed stored order. Avatar catalog/default color/initial rules use spec6.6
  and native UTF-16 vectors, not a new Roku hash.
- Admin comes from verified server level (including staff/superuser rules), never
  an imported label or the upstream record's historical default level10. Standard
  and Admin have equal app-local management rights. Both base and active identities
  must separately be verified server admins for server user/API-access/assignment
  actions. Server capabilities always override local role labels.
- Roster corruption/wrong-root/newer schemas load read-only and prevent connecting
  the affected slot. Never recreate a default-only roster that drops PINs/Child
  roles/holds. Forget is a local recovery action, not a synced tombstone.
- Registry updates stage a complete candidate and one flush with rollback; failed
  persistence must not commit active scope or new server URL. Account/settings
  budgets and compressed shared Dev-ID capacity are different limits. Measure both.

## Session transaction and recovery

Scope = connection slot + verified active user/local profile + authorization
generation. Stage target authentication, `/me/` identity/capabilities/lineup,
preferences and PIN gate; commit only after success. Failed/cancelled switch
retains the outgoing profile. Confirm playback stop; no switch autoplay. Flush
outgoing sync before changing scope. Retire old Tasks/Video headers/artwork and
reject late callbacks/writes by generation; a dropped write remains dirty for
its original profile's next session.

Non-default connects/refreshes do not inherit the default Channel Profile filter.
Hide the slot's sign-in/Channel Profile editors while non-default is active.
Reconnect, capability refresh, Setup and every selected-connection reload use
one active-key resolver. Only verified default connects update slot identity.

Three distinct safety states must not be conflated:

| State | Key/scope | Behavior |
| --- | --- | --- |
| Rejected credential | Credential digest | Only a Dispatcharr401 body naming Invalid API key/User inactive rejects it. Prompt once, stop requests, slow probes at1/5/15min then30min, minimum60s apart and never during a server park. Wrong `/me/` identity holds the affected profile. Generic/proxy401/all403 keep valid credentials. |
| Address-change hold | Persisted per-profile slot state | Changed scheme/host/port holds **every** non-default, keyless included, with frozen default-identity snapshot/tags before URL/key use. Apply exact same-server recovery checks in spec6.7.7; keep active Child fenced. Pause roster both directions while any hold remains. |
| 429 park | Shared server host/port | Delta/date Retry-After, missing default60s, cap120s. No immediate GET/1s retry; stop every outgoing Dispatcharr path, not just JSON calls. |

Path/case/explicit-default-port-only edits are not address changes, but existing
Remember-off key cleanup still applies. Address changes discard old sync server
copies/sessions. Frozen identity survives until all holds settle. Default account
replacement keeps local id/PIN, rebuilds live identity/role, clears avatar/order/
stamp, and writes no tombstone. Fix Login signs in only the selected known user;
never use the slot/admin key as fallback for a refused non-default. Outside a
switch, refused active Child remains Child, not the previous adult or Setup.

## Scoped data and settings

`connectionPreferenceIdentity(entry, activeUserId)` is the account-scope basis.
Preserve existing default data on upgrade. New profiles receive a freshly built
settings-only allowlist from the default, never a copied whole blob with data
subsequently cleared. The base allowlist is spec14 step3.4; extend explicitly for
the approved Apple-style appearance/player scope. Favorites, recents/history,
collections, reminders, watched/hidden/VOD progress/My List, last channel,
startup group, DVR positions and per-content overrides start empty.

Authorized lineup/results/capabilities, tokens, callbacks and pending writes are
user-scoped. Safe shared server metadata caches may remain shared; cache reuse
must not confer authorization or bypass holds/parks. Remote mapping, network,
physical display/device controls stay device-local. Profile removal deletes only
the target eligible blob/keys; playlist Forget removes the complete slot locally.

## PIN, Child and launch policy

v2 = lowercase SHA256(raw16SaltBytes || normalized ASCII PIN), with 32hex salt
and64hex digest; constant-time comparison. Native vectors required. Numbers and
Directions accept4-6 entries; unknown length initially uses6 dots. Setup invalid
hash/salt downgrades per wire validator; newer malformed roster PIN leaves local
PIN alone; explicit/unknown `none` follows the corrected contract. No v1 writes.

Five wrong entries lock30s, further rounds double with exponent cap10; attempts
during lock do not count, success resets. Keep state per holder/device, never
sync it. Change/remove require current target PIN; reset/keep-PIN/add undo obey
spec7.5. Import-only rejects unsafe Child/full-access additions instead of trying
to create salts. Device Admin PIN is never synced/exported.

Use StandardPinPadDialog for Numbers, StandardKeyboardDialog for credentials.
Launch gate `wasClosed` exits; do not reveal protected content or show a second
dialog behind it. Picker precedes connectServer; AppDialog/AppLaunch beacons and
15s budget require native evidence. Child hides other names/switcher, fences
Connection/setup/receivers and direct handlers, and only exposes permitted
Live TV/Player/Appearance/About plus adult-PIN Manage Profiles. Count Directions
PINs when deciding whether any adult PIN exists; all-Directions is not no-PIN.

Native OS16.0.4 qualification corrects two API assumptions: wasClosed has a
void/null payload (act on the current dialog's signal, not `getData() = true`);
Options toggles the native PIN-pad highlight without closing it. In that case
keep the protected gate up. Home exits at OS level. See
[primitive evidence](PROFILE-PRIMITIVE-QUALIFICATION.md); these differences do not
authorize any route past an unverified PIN.

## Roster and wire rules

Use own verified user's normalized `<username>.aeriotv`: ASCII uppercase lowers;
UTF-8 bytes outside `[a-z0-9_.-]` become `-xx`; prefix `u` unless first character
alphanumeric; truncate46 characters (even splitting escape), append `.aeriotv`.
Empty username waits. Never write `app.molinete.aerio` or its legacy variants.
When legacy exists without canonical, either perform complete safe per-category
migration then delete legacy after successful canonical PUT, or stay read-only.

Native checked JSON must preserve exact key case/types, integers/doubles, emoji,
null, unknown objects/categories/lanes/row tails and millisecond timestamps.
Serialize once, validate and post that raw string, not a quoted/reformatted copy.
Observe server JSON128KiB and transport Content-Length132096-byte caps. ISO
whole-second Z parsing/writing and PUT/PATCH semantics require native probes.

Read-only roster is an **early prerequisite** of public switching, not a later
optional sync enhancement. Default creation stays unstamped; manual add matching
a roster row is a roster add preserving remote PIN/role/stamp. Pull never
auto-adds suggestions. Child/Profiles-Off preserve without applying/suggesting/
writing. Address holds pause both directions including no-session pushes, retain
dirty edits and pending add/undo marks, and trigger immediate pull on resume.

Strict-newer row merge, name/avatar claims and stripped-row guards60s/600s follow
spec13.3. Tombstones union90days; removal wins on `removedAt >= updatedAt`, but
never removes default. Remove active target safely before cleanup; stale callbacks
must not retain its key. Intentional newer re-add clears tombstone. Roster-add or
paused-add undo is local-only, not a deletion broadcast; held removal writes none.
Stale-device suppression, stored stamps and pending acknowledgement follow the
corrected schema. Picker pull max once30s plus2s reread, roster debounce1s,
regular cadence15min/network-return. Whole-envelope PUT always re-GET/merges;
disabled/unsupported lanes are carried unchanged, not applied or reauthored.

## Handoff and interim behavior

Interim: authenticate only `playlist.credential`; ignore non-default profiles
without authenticating them. Exactly one entry counts as default regardless of
isDefault; otherwise explicit default selects metadata. Unknown roles/types
normalize to empty/none. Show exactly "Multiple profiles aren't currently
supported on Roku. Stay tuned." on screen when extras are ignored. Refuse a
protected default before verification/persistence. No profile PIN material is
persisted; payload sync never auto-enables Sync.

Full receiver: retain playlist/profile IDs; match existing playlist id before
duplicate handling, snapshot identity before payload verification and persist
holds atomically before URL use. Commit slot first, then profiles/keys in a second
flush. Default first, all non-Child, then Child; order ascending with-1 last.
Default uses playlist credential and setup stamp. Existing non-default username
skips (Android behavior). Each entry at most one key attempt then one password
attempt when supplied/refused/wrong identity; retain only returned API key. Any429
parks remaining entries. Report partial failures without corrupting successes.
Sync offer is a separate explicit Turn On/Not Now choice, honoring prior decline.
Existing discovery, logos, automatic verified-new-account guide handoff and
Cancel/Add Anyway/Replace remain intact. Imported profile prompts must not cause
unrelated real account/recording mutations during tests.

## Code integration inventory and ownership

| Boundary | Existing Roku locations | Work owner / verification |
| --- | --- | --- |
| Slot lifecycle/default credentials | `ConnectionStoreModel`, `ConnectionNavigation`, `AerioScene`: rememberConnectedAccount, storedConnectionKey, applySelectedConnection, relogin, Remember, URL change, Forget | mrr.4/.6; fake registry failure/rollback and native keyless/address-hold cases |
| Pure roles/PIN/order/avatar/roster | Existing `ChannelProfileModel` must stay separate; new `UserProfileModel/Store` | mrr.4/.5/.8/.15; source-linked vectors and malformed/type cases |
| Data/settings/cache | `PreferenceModel`, `SettingsModel`, `SettingsNavigation`, `VodState`, `MediaSessionModel`, `MetadataCacheModel/Store`, guide/library callbacks | mrr.7; A/B/A, two slots, same IDs, old generation and shared-cache authorization tests |
| Common HTTP and retries | `HttpTransport`, `DispatcharrHttp`, `HttpPolicy`; `/me/` in DispatcharrTask, CapabilityTask, ProfileTask | mrr.13/.14; native retained GET401 before tmp deletion, PUT/PATCH raw JSON/length; synthetic rejected/generic401/403/429 |
| Bypass requests/media | `SessionHttp`, `MappingDetailFetch`, `LogoCacheTask`, `PlaybackBridgeTask`, `HlsSessionTask`, AerioScene/OnDemandPlayer Video headers; roHttpAgent in GuideView, ChannelBrowser, VodView/Details, DvrView, PlayerInfo, ProgramDetails | mrr.14/.6; no outgoing requests on held keys/server parks and late/in-flight cases; unrelated external TMDB must not receive Dispatcharr keys |
| Launch/navigation | `AerioScene.init/connectServer`, `LaunchModel`, `NavigationModel`, `SettingsHub/Rail/Model`, PhoneSetupNavigation/receiver | mrr.8/.9/.16; native dialog cancellation/masking, beacons, deep links and Child handler fences |
| Interim setup | `PhoneSetupModel`, `PhoneSetupApplyModel`, `PhoneSetupNavigation` | mrr.12; validator unknown enums, no additional credential requests/PIN persistence, actual on-screen notice |
| Admin server actions | Existing ProfileTask is Channel Profiles only; new UserProfileTask | mrr.18; dual admin gate, explicit user_id, correct PATCH array, no rotation of existing/caller key |
| App Data contract/engine | No current general engine; e3e.3 contract, mrr.15 early read-only, e3e.6 engine, e3e.7 scopes/roster writes | Reuse these owners; never make early read-only depend on completed e3e.4/.6/.7 |
| Full import/onboarding | PhoneSetupModel/Store/Navigation, profile management route | e3e.8; actual Apple and Android senders, partial/cancel/undo/holds and explicit sync choice |
| Acceptance | Existing d85/mrr.2/.3 visual fixes remain closed | mrr.10 local -> e3e.4; mrr.11 joins e3e.7/.8, mrr.18 and dgt authenticated evidence; PO accepts epic |

## Execution and native isolation

Contract first; independent entropy/HTTP/dialog/registry probes next; mrr.17 then
records evidence-backed shipping boundaries before profile storage and dependent
implementation. Shared request safety can proceed after native HTTP evidence.
Public switching waits for scoped state, read-only roster, PIN/Child and request
gates. Developer-only scaffolding is not public completion.

Before native installs, match the installed developer ZIP's MD5 to a local
checksum-pinned restore artifact. Use synthetic loopback/LAN fixtures and a unique
disposable registry section, never read or overwrite owner keys/settings. Preserve
the established Dev ID. Restore the exact previous ZIP after probes and record
native model/OS, checksums, actual assertions and limitations. No production App
Data/account/key/channel mutations, public release or signing is implied.

Host tests use injected digests/parser/transport/fake registry. The brs interpreter
cannot qualify native crypto, double/case-preserving JSON, HTTP, PIN dialogs or
registry capacity. Native evidence must exercise those primitives, not merely
show a successful compile/install. Snapshot/rendered fixtures do not replace
authenticated/video-backed or physical remote acceptance.
