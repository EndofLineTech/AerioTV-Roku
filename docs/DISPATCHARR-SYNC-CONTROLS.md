# Private Dispatcharr Sync controls

These controls are implemented and developer-tested, **not publicly enabled**.
`m.profileSyncControlsReady`, `m.profileSyncSchedulingReady` and
`m.profileSyncWriterReady` remain false in shipping source. The entire profiles
epic and general category sync are unfinished.

The approved delivery phase is **profiles-only**. Unsupported categories and
settings lanes are preserved, not additional adapters required for this phase.
The historical remaining-work paragraph below is not a new scope requirement.

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
into a newer unprotected plain Add. A newer target row wins; unverifiable PIN
material or a mismatched live user ID refuses. The source stamp is retained
(zero becomes now), and roster Undo remains local without a tombstone.

Focused actual-controller evidence:
`out/mrr-delivery-roster-offer-red.log` and
`out/mrr-delivery-roster-offer-green.log`.
The focused source-row regression is
`out/mrr-delivery-source-roster-add-{red,green}.log`.

## Delivered boundary

- The existing selected Connection manager offers **Dispatcharr Sync (this Roku)**
  only behind the private readiness flag and a current full-access Dispatcharr
  holder. There is no new Settings rail category.
- Choices are device-wide: explicit Sync On/Off and Profiles On/Off. Sync defaults
  Off. Only Profiles is supported by this private writer; other categories are
  preserved unchanged, not claimed implemented.
- The menu explains device scope and preservation. Scheduled sync waits until
  the menu closes. Off cancels scheduled work and stops its timer without
  clearing durable pending edits.
- Status distinguishes Off, Profiles Off, pending changes, offline, address-held
  profiles, sign-in pause, capacity refusal and oversize refusal.
- `settingsV1.device.dispatcharrSyncEnabled` and `dispatcharrSyncProfiles` are
  local choices, not profile settings and never App Data fields. The app reads
  them before early roster processing. Sync Off does not erase existing profile
  protection; explicit Profiles Off prevents category application/writing.

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

Broader category controls/merges, safe 413 trims, picker/adoption UI, onboarding
offers and complete public profile/recovery/Child/admin acceptance remain open.
