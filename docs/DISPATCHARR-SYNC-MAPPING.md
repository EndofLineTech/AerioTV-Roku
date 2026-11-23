# Roku Sync mapping contract

Foundation for `AerioTV-Roku-e3e.3`, against corrected v3 schema SHA256
`54731d14cdc4e276e044f0eb7bce7e3778dd3775c5885ec940b213cb9129cfbb`.
This is not a claim that every category has a Roku adapter.

The profile specification §13.8 explicitly permits a TV client to skip categories
it does not implement, provided it preserves their values and types. The current
writer owns **profiles only**. All other categories, including unknown future
ones, must remain unchanged; they must not pass through local normalizers.
Legacy-only data remains read-only: full-category migration is not implemented.

## Identities, timestamps and caps

`source/DispatcharrSyncMapping.brs` exposes these descriptors. Caps below are wire
caps, not permission to truncate peer data to smaller local storage limits.
Envelope/category `updatedAt` is UTC ISO8601 to seconds, with no fraction.

| Category | Wire identity / cap | Roku carrier and adapter boundary |
| --- | --- | --- |
| favorites | Integer channel PK / 1,000 | `favoriteIds`: channel UUIDs, local cap 2,000 |
| recents | Integer channel PK; watched-at Unix seconds / 50 | `recent`: ordered UUIDs, cap 25; no watched-at stamps |
| progress | Integer movie/episode PK; updated-at Unix seconds / 300 | `vod`: kind + UUID; position/duration seconds; `touch` is ordering, **not Unix time** |
| reminders | Integer channel PK + program start Unix seconds / 200 | `reminders`: UUID + local program ID, cap 50; use channel/start on wire |
| watchlist | Integer movie/series PK + added-at Unix seconds / 500 | `vod.watchlist`; existing `touch` cannot supply added-at |
| hiddenTitles | Integer movie/series PK + hidden-at Unix seconds / 500 | `vod.hidden`; existing `touch` cannot supply hidden-at |
| hiddenGroups | Server group names / 500 per group kind | `guide.hiddenGroups`: local group tokens, not names |
| groupOrder | Server group names / 500 per group kind | `guide.groupSort` + `groupOrder`; translate `group:<id>` through the authorized catalog |
| settings | Allowlisted names in `v` / `tv` / `mobile` | Profile appearance/player + account fields; no general adapter |
| remoteMap | TV remote slots | Device-local Roku map; preserve peer category |
| radioDefault | Boolean | Not implemented; preserve |
| collections | UUID / 50 collections, 500 integer channel PK members each | Local IDs, names and channel UUIDs; cap 20 collections; local first/last placement differs from wire `afterGroup` |
| profiles | Integer server user ID + username / 25 rows | Local stable UUIDs + own verified identity; four-profile local cap; qualified roster controller |

Profiles row/tombstone stamps are Unix **seconds**. Unknown categories may contain
milliseconds or doubles: preserve them without interpreting their units.
Names/avatar/PIN/role/stamp/order/tombstone merging is implemented separately by
`DispatcharrSyncRoster`, `DispatcharrSyncMerge`, and `DispatcharrSyncRosterWrite`.
Never derive server authority from a roster role.

`dispatcharrSyncChannelIds` translates UUIDs only through a caller-supplied
current authorized catalog's server PKs, never channel numbers. Decimal-string
local PKs become positive signed-32-bit integers; overflow/decimals refuse.
Unresolved or ambiguous UUIDs are returned separately and make translation
incomplete. Do not use an incomplete projection for full-category replacement.

## Favorites adapter (not yet wired)

`source/DispatcharrSyncFavorites.brs` is a pure adapter for the `favorites`
category, matching Android's `DsyncFavorites` / `DsyncGate`:

- **Read:** a category without an ISO `updatedAt`, `data` or an integer `ids`
  array is ignored; order is kept and a repeated id is dropped.
- **Clean pull:** the server list wins, in server order. Lineup channels the
  server dropped are removed; a local favorite outside the current lineup is
  kept, because this device cannot tell whether it was dropped.
- **Pull with an unsent local change:** union, local order first, then server
  channels this device lacks. Never a blind overwrite.
- **Write:** local favorites translated to server ids, then server ids this
  lineup cannot translate (carried, never deleted), capped at 1,000. Only
  `data.ids` is replaced; other `data` members and `extra` round-trip.

The writer still owns **profiles only**. Category switches, scheduling and
applying pulled favorites to the Guide are separate, reviewed steps.

## Settings lanes

`dispatcharrSyncSettingsLane` projects the original map without normalization:

- All devices selects `v`; Roku TV scope selects `tv`.
- Off selects nothing.
- A restored other-class scope becomes All devices.
- A missing TV lane does **not** fall back to `v`.
- Malformed selected lanes refuse application.
- Mobile/unknown lanes, names and original numeric kinds remain untouched.

This helper is not a settings applier, category switch, or write permission.
Per-profile local appearance/player scope does not authorize syncing device
network, hardware/display, credentials, remote mappings or PIN backoff.

`dispatcharrSyncAppearanceMappings` records the compatible appearance items
from the [pinned upstream settings schema][appearance-schema]. It does not apply
incoming values or activate any local scope. When an adapter is authorized,
each item uses its own scope choice and the normal `v` / `tv` / Off rules above.

| Dispatcharr wire name | Sync item | Wire value | Roku local carrier |
| --- | --- | --- | --- |
| `channelLogoSize` | `logoSize` | Integer 25–250 in tenths of a percent; 100 is stock | `guide.channelLogoSize` |
| `logoCornersGuide` | `roundedGuideLogos` | Boolean | `guide.roundedGuideLogos` |
| `logoCornersGuideCells` | `roundedProgramCells` | Boolean | `guide.roundedProgramCells` |
| `trueBlack` | `trueBlack` | Boolean | `profileSettings.trueBlack` (legacy effective appearance on direct connections) |

`logoCornersList` is a distinct setting and is not mapped to guide corners.
The local renderer does not normalize or write any peer settings envelope.

[appearance-schema]: https://github.com/jonzey231/AerioTV/blob/fe7ad4c1968a193efb7a55d68b2b3bd32d03b17a/docs/DispatcharrSyncSchema.md#49-settings

## Deployed capability and budgets

Read-only checks on both approved test accounts returned own App Data list
HTTP200 and canonical-key structured HTTP404 `key_not_found`. Both lists were
empty. Server-advertised limits were:

| Limit | Observed |
| --- | --- |
| Value | 32,768 bytes |
| User total | 131,072 bytes |
| Keys | 25 |
| Depth | 8 |
| Key length | 8–64 |

Evidence: `out/mrr-sync-deployed-read-capability.json`. Authentication and GETs
only; no account/settings/App Data mutation, oversized upload, throttle test,
or server-version claim. These advertised limits are smaller than the corrected
schema's reference deployment. They are **not** measured write-boundary results.
Unsupported/older endpoint responses, 403, 413 and 429 behavior are covered by
synthetic HTTP fixtures, not destructive checks against this server.

`dispatcharrSyncWriteBudget` uses the same fresh own list used for discovery.
It checks the independently encoded UTF8 byte count, advertised per-value and
total limits, replacement credit for only the exact canonical key, and key quota.
Absent limit metadata uses conservative 32-KiB/128-KiB/25-key bounds; malformed
supplied limits block writes. The absolute local 128-KiB write ceiling still
applies. Capacity refusal does not acknowledge pending changes, trim unknown
data, delete keys, retry immediately, or claim successful migration.

## Evidence and delivery boundary

Host mapping/task tests and compiler checks pass:
`out/mrr-sync-deployed-budget-host.log`,
`out/mrr-sync-deployed-budget-check.log`.
Native mapping checks pass `out/mrr-sync-mapping-native.log` / `.json`, including
Double-preserving TV lane projection and integer channel translation; the exact
persistent developer baseline was restored.
The added advertised-cap/quota checks also pass on Roku in
`out/mrr-sync-budget-native.log` / `.json`, with exact baseline restoration.
The full regression passed `out/mrr-sync-phone-qualified-full-verify.log`
(380-file ZIP). The foundation Bead `e3e.3` is closed; downstream integration
and final owner acceptance remain open.

General category adapters, timestamp capture and legacy full-category migration
are not delivered. They are not prerequisites invented by this mapping document
for the profiles-only phase. Actual sender interoperability, public Directions
access/certification, production entropy and owner acceptance remain separate
open epic requirements.
