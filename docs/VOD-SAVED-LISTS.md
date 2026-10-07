# VOD saved lists

The VOD navigation has three separate lists on Dispatcharr and direct Xtream
connections:

| List | How a title gets there | How it leaves |
| --- | --- | --- |
| Recently Watched | A movie or episode plays and reports actual progress. Completed titles remain. | Remove the selected entry or clear the list in `*` Library options. |
| To Watch | Choose **Add to To Watch** on a movie or TV show's details. Existing Dispatcharr Watchlist choices appear here. | Choose **Remove from To Watch** in details or remove it from the shelf. Playback does not remove it. |
| Favorites | Choose **Add to Favorites** on a movie or TV show's details. | Choose **Remove from Favorites** in details or remove it from the shelf. Playback does not remove it. |

A title may belong to both To Watch and Favorites. Neither choice adds it to
Recently Watched. **Continue** remains the Dispatcharr shelf for resumable titles
and verified next episodes; it is not a complete viewing history. Recently Watched
begins recording only after the feature is installed; old watched markers are not
reinterpreted as past plays. Its 20 most recent identities are saved locally per
connection/account, without playback URLs or passwords.

Saved titles are checked against the current connection before they can be opened.
Unavailable or unauthorized history entries are omitted; temporary provider
failures show a retry message. For To Watch and Favorites, saved choices remain
until explicitly removed, even if the title cannot currently be resolved. A
provider change or account switch never exposes the previous connection's list.
Direct Xtream credentials are session-only; reconnect after restarting the app
to load saved titles from that connection again.

The existing account-local preference store has a **24,000-byte total budget
across all accounts**. To Watch, Favorites, Hidden and watched markers share the
40 curated-title limit; recent playback does not consume a curated slot. If a
preference write fails, the previous saved choices remain and an on-screen notice
explains the failure. Lists are device-local and do not sync between Rokus.

## Native verification — 2026-10-07

The v0.3.95 development source passed `npm run verify` and its tested app ZIP
was installed on a Roku Streaming Stick 4K 3820RW2, OS 15.3.4. With authorized
Dispatcharr connections, a movie opened through
the normal detail view, played long enough to report native progress, appeared
in Recently Watched after a process relaunch, and disappeared on Clear without
removing it from To Watch or Favorites. Movie and TV-series choices appeared in
both independent curated shelves; removing one choice did not remove the other.

The same authorized account was also tested through its direct Xtream-compatible
API in a separate session-only connection. A movie and a series appeared together
in To Watch and Favorites; selecting either resolved its verified detail and Back
returned focus to its row. An episode reported native playback progress, appeared
ahead of the movie in Recently Watched, and reopened its exact episode detail
using the parent-series identity. Both native playback samples reached ECP
`play` with `error=false`. This does not establish physical picture/sound or a
full end-of-title completion test; completion/history behavior has model tests.

The initial native check revealed a clipped eight-tab rail and a direct-Xtream
saved-title authorization mismatch. Both were fixed and rechecked on the same
device. At 120% text size, all tabs and the Favorites star were visible; the
original 100% setting was restored. Temporary connections and their preferences
were forgotten, leaving the original single saved connection selected and an
authorized guide active. Private screenshots remain ignored under `out/`; no
credentials, catalog IDs, or provider URLs are included in this document.
