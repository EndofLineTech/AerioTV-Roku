# Cross-device and platform crosswalk (engineering research)

Status: engineering crosswalk with Product Owner scope decisions recorded below.
Baseline: `docs/PARITY-AUDIT.md` I01–I07, pinned upstream revision
`8d5818456e0f4421d93b8ff120ad878d63331091`; Roku 3820RW2 / OS 15.3.4,
Dispatcharr 0.31.0. No additional runtime service is assumed. Source evidence
describes implementation, not a running Apple TV or companion session.

| Upstream behavior | Current Roku boundary / possible counterpart |
| --- | --- |
| iOS touch gestures, orientation, edge brightness/volume, CarPlay, Files and iOS notifications | Exclude direct TV parity. Roku remote navigation and URL-based M3U/XMLTV connection setup already exist (`components/GuideRemoteInput.brs`, `components/AerioScene.brs`); neither is an Apple Files picker or mobile gesture. The existing in-app mini-player is distinct from cross-app PiP. |
| Mobile Google Cast/AirPlay sender | Exclude sender parity from the TV app. Roku system AirPlay does not expose an Aerio sender/handoff implementation (`PARITY-AUDIT.md` I03). |
| tvOS Top Shelf extension | Apple-specific home API; an **in-app** Recent Channels group/player overlay and VOD Continue Watching shelf already exist (`source/PreferenceModel.brs`, `source/GuideSettingsModel.brs`, `source/VodState.brs`). Roku system discovery/deep links would require a separate verified publishing contract, not a copied Top Shelf extension. |
| Standalone tvOS List | `TVListView.enabled = false` at the pinned revision; excluded. The active in-player Channels overlay has a Roku counterpart (`components/ChannelBrowser.brs`), a different feature. |

## I01 — sync or import/export instead of iCloud

`source/ConnectionStoreModel.brs` holds at most four named connections in a
device registry section; Dispatcharr keys are stored separately and Xtream
passwords only in session memory. `source/PreferenceModel.brs` contains versioned
device and account preferences, with a 25-channel recent ring; `source/VodState.brs`
holds at most 20 saved VOD items per account. These are local records. Current
Dispatcharr/playlist endpoints are used for catalog/guide/media operations, not
an identified shared Aerio preferences/progress API. No read/write sync endpoint
has been verified. Merely connecting two clients to the same server cannot sync
Roku-specific choices. An import/export path would require a separate, approved
transport (Roku has no Apple Files picker) and explicit user action.

Proposed *design constraints*, if the PO wants an import/export spike: export
only opt-in categories (e.g. visual/device choices, channel favorites/order,
VOD watchlist/progress) from an explicitly selected account; never silently
include API keys, session passwords, provider URLs, TMDB credentials, or an
account's permitted catalog. Use a versioned bounded document with origin and
account fingerprint, validate every item against the destination account's
current permissions, present a per-category dry-run/conflict summary, and default
to non-destructive merge. Deletion must be category- and account-scoped with
separate confirmation; a missing source item must not silently erase local state.
No transfer code or server write is authorized by this design note.

## I02 — companion feasibility

The pinned upstream companion host advertises `_aeriotv._tcp` and implements
pairing/authenticated bidirectional control and state feedback
([upstream companion reference](https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/App/AerioCastController.swift#L3320-L3603)). The Roku app has no advertisement,
WebSocket listener, pairing-code exchange, phone handoff receiver, or companion
session lifecycle. Roku's External Control Protocol (ECP) uses SSDP for **Roku
OS** discovery and permits remote keys when device policy allows; it is not
Aerio's application-level mDNS/WebSocket protocol. Official ECP documentation
also restricts in-app ECP commands and third-party ECP senders. An authenticated
phone-to-Roku Aerio control/state demonstration therefore remains unproven under
the no-extra-service rule. Do not turn on device policy or call ECP-key injection
an implementation of paired feedback. A delivery issue needs a supported
receiver/transport, pairing security and teardown design, then real-device tests.

## I05 — Roku launch/deep-link research

Roku documents `contentId` + `mediaType` launch arguments to `Main(args)`,
and `roInputEvent` for warm-app requests with `supports_input_launch=1`.
Current `source/Main.brs` ignores launch arguments, and `manifest` has
`supports_input_launch=0`. Roku media types include `liveFeed`, `movie`,
`episode`, and `series`, with distinct playback/bookmark requirements. Enabling
input launch without a resolver would claim unsupported behavior. A feasible
candidate uses an opaque, bounded account-scoped ID (no URL/key/title in the
request), validates it against fresh authorized channel/VOD identity, and routes
through the existing live or VOD player only after connection; missing/denied
IDs return to guide with a non-sensitive message. Cold and warm paths, stale
account, sign-in-needed, deleted title and Resume semantics need device tests.
Series smart-bookmark behavior and publishing/feed requirements need separate
scope; a generic `series` route is not equivalent to episode playback. No route
is enabled yet and no external catalog/feed publication is approved.

## I04 — recommendations / watched frequency

Recent Channels is a **recency ring**, not a watch-frequency counter; VOD Continue
Watching is an account-local progress shelf, not a Roku home recommendation.
Frequency would require bounded, account-scoped completed tune/view events,
validity checks after account changes, and a decided ranking/retention policy.
The existing in-app surfaces are the least invasive candidate if useful; system
recommendations and deep links depend on a verified platform/publication path.
The PO's current-scope choice is recorded below; no ranking or system-home
feature is promised.

## Product Owner scope decisions — 2026-09-25

- `4vg.1`: Approved Apple-only exclusions above. The active Roku Channels
  overlay is not the disabled standalone tvOS List; in-app features are not
  Apple Top Shelf, Cast/AirPlay sending or cross-app PiP.
- `4vg.2`: Defer cross-device sync and import/export. Preferences and VOD
  progress stay local; no backend, transfer service or credential export is
  approved. The account/conflict/deletion design above remains a constraint
  if sharing is proposed in a future scope.
- `4vg.3`: Defer companion discovery, pairing and control. The Roku remote is
  the supported path; OS ECP does not establish authenticated Aerio feedback.
- `4vg.4`: Defer content deep links. Normal app launch stays supported and
  `supports_input_launch` remains disabled. Do not advertise content routes
  without verified opaque IDs and cold/warm/auth/missing-item behavior.
- `4vg.5`: Accept the existing in-app Recent Channels and VOD Continue Watching
  as the Roku home-discovery adaptation. Recent is recency, not watch frequency;
  neither surface is a Roku system-home recommendation.

These scope decisions do not constitute new device acceptance. Any later
implementation needs model/Task tests, `npm run verify`, and Roku cold/warm
authorization and remote/navigation checks. Native player state alone does
not prove picture, sound or spoken feedback.

References: [upstream audit and links](PARITY-AUDIT.md#cross-device-and-platform-specific-features),
[Roku deep linking](https://developer.roku.com/docs/developer-program/discovery/implementing-deep-linking),
[Roku ECP](https://developer.roku.com/docs/developer-program/debugging/external-control-api),
[connection credential policy](CONNECTION-CREDENTIAL-POLICY.md).
