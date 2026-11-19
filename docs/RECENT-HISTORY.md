# Live Recently Watched management

From fullscreen live playback, press **Replay** (default mapping), or choose
**Recent** in the on-screen player controls. Use **Up/Down** to highlight the
channel you want to remove. Press **Right** to focus **Manage History**, then
press **OK**. **Left** returns to the highlighted channel, **OK** on a channel
watches it, and **Back** closes the browser. Fullscreen **\*** belongs to Roku.

In the guide's **Recently Watched** group, open **\* → Manage Recently Watched**.
Both routes offer **Cancel**, **Remove selected channel from history** when
applicable, and **Clear all live Recently Watched**.

Removing a channel preserves the order of other entries. Clearing removes the
live recent ring and previous/last-watched recall targets. Favorites, VOD history,
guide position and current playback are preserved. Watching a channel again
adds it back; pausing or rebuffering the current recorded tune does not reset
its recorded marker merely because history was cleared.

Both surfaces update together. The selected row stays on the same channel when
possible, otherwise moves to the adjacent remaining row. Clearing leaves the
guide group empty and focuses **Manage History** in the fullscreen browser;
**Back** still closes the browser. Edits use account-scoped preference
storage. If persistence fails, the standard on-TV notice explains that the
change is session-only. Cancel and stale-dialog/account callbacks do not write.

**Sync scope:** Removing or clearing live history affects this account on this
Roku only. Dispatcharr Sync currently syncs profiles, not the shared `recents`
category. Sync neither imports shared history into Roku nor publishes Roku
removals; it preserves any existing shared `recents` data. These edits do not
delete history on the server or another device. Cross-device deletion and its
merge rules are not implemented or qualified.
