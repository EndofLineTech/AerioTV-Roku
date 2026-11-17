# Profiles delivery status — November 17, 2026

This records the approved developer/import-and-verify phase, not a signed
release, public feature enablement or owner acceptance.

| Main experience | Current evidence |
| --- | --- |
| Create, switch, manage, reorder and remove real-account profiles; isolated own credentials/data | `mrr-core-avatar-native`, `mrr-controls-canonical-native`, `mrr-picker-light-large-qualified-native` in `out/`; documented in [developer baseline](PROFILES-BASELINE.md). Do not repeat these completed flows as new prerequisites. |
| Protected phone-import controller, explicit Sync consent, Who watches, Add/Undo and Continue/recovery | `out/mrr-delivery-onboarding-qualified-native.log`/`.json`: all result flags, cleanup and exact baseline restoration pass. Real approved account authentication and local transactions; decoded private payload and suggestion hint, not a phone sender. |
| Profiles-only Sync | Own read/merge/checked PUT, atomic acknowledgement, outgoing flush and bounded scheduling have private native evidence in [writer status](DISPATCHARR-SYNC-WRITER.md). Explicit controls and session-bound suggestion Add are documented in [Sync controls](DISPATCHARR-SYNC-CONTROLS.md). Unsupported categories remain unchanged. |
| VOD/DVR layout | Existing inspected populated visual fixes remain complete in [UI audit fixes](UI-AUDIT-FIXES.md). They are not proof of account-backed playback. |

## Actual remaining boundaries

The final source-row version also passes
`out/mrr-delivery-source-roster-onboarding-native.log`/`.json`: name/stamp/origin
are retained and roster Undo creates no tombstone. Full automated verification
passes in `out/mrr-delivery-final-verify.log` (380-file normal ZIP).

The supplied accounts have empty movie/series catalogs; existing read-only
inventory is `out/mrr-integrated-media-readiness.json`. Populated real-account
VOD acceptance cannot be claimed from an empty library.

Actual named Android **and** Apple sender interoperability, the production
listener entropy disposition, public Directions access/certification disposition,
Dashboard OS-floor verification and explicit owner acceptance remain unverified.
The approved import-only PIN phase does not require inventing new salt creation
or Device Admin onboarding. Normal shipping readiness gates remain off.

Real App Data uploads and real server-user/settings mutations have **not** been
authorized or performed. Synthetic native writer/admin evidence must not be
described as real-server mutation acceptance.

## Native runner access

Use `PATH=/opt/homebrew/bin:$PATH` for native Python runners on this Mac.
The owner granted that Python Local Network permission; a direct read of Roku
control returned HTTP 200. Xcode's separate `/usr/bin/python3` still returned
errno 65 during diagnosis. Do not diagnose the Roku as offline merely from that
runtime, reset security databases, disable VPN controls or repeat reachability
matrices. No network configuration was changed.

The persistent installed developer baseline remains the previously authorized
versioned ZIP; isolated acceptance runs restore it exactly. Follow-on source and
its evidence are not an assertion that the installed checkpoint was upgraded.
