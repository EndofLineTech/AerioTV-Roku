# Live Recently Watched management

Development implementation for `AerioTV-Roku-e3e.18`; not yet device-accepted
or included in a newly published release.

In the guide's **Recently Watched** group, open **\* → Manage Recently Watched**.
In the player's **Recently Watched** channel browser, press **\***. The dialog
offers Cancel, removal of the selected channel when it is in history, and
clearing all live history for the current account.

Removing a channel preserves the order of other entries. Clearing removes the
live recent ring and previous/last-watched recall targets. Favorites, VOD history,
guide position and current playback are preserved. Watching a channel again
adds it back; pausing or rebuffering the current recorded tune does not reset
its recorded marker merely because history was cleared.

Both surfaces update together. The selected row stays on the same channel when
possible, otherwise moves to the adjacent remaining row; clearing leaves an
empty list with Back available. Edits use existing account-scoped preference
storage. If persistence fails, the standard on-TV notice explains that the
change is session-only. Cancel and stale-dialog/account callbacks do not write.

Automated model/controller tests cover order, recall, current-playback state,
account changes, stale callbacks, cancellation, storage-failure behavior and
updates to both views. Native validation remains required for physical **\***
routing, dialog focus, empty-list navigation, storage across a real relaunch and
picture/audio continuity. On 2026-10-28 device access became available and the
normal 0.3.100 candidate containing these controls was installed after the crypto
probe; ECP confirmed AerioTV active. This is installation evidence, not completion
of the history acceptance checks. Cross-device deletion behavior belongs to the sync
engine's merge integration; sync is not enabled by this change.
