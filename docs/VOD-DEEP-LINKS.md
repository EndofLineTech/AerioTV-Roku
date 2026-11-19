# Dispatcharr VOD links (private catalog)

The Roku app accepts `mediaType=movie`, `episode`, or `series` with a `contentId`
of 1–10 decimal digits, starting with 1–9. The ID is a Dispatcharr catalog ID
on the selected connection, **not** a playback UUID, TMDB ID, or public Roku
Search identifier. The app ignores link fields other than `contentId` and
`mediaType`; a link cannot supply a server, profile, credential, or stream.
The existing `live` / `liveFeed` route remains separate.

On first run, a valid link waits through setup and sign-in. On a saved
Dispatcharr launch, it skips optional profile selection but not the saved
holder's PIN or own-key sign-in. A warm request resolves from the authenticated
Guide or Live Player. In Settings, DVR, the library, or on-demand playback, it
waits for a return to the guide in the same session. A replacement or account
teardown retires work already in flight. A failed link never tunes a substitute.

The resolver uses the checked-in [media/provider contract](MEDIA-PROVIDER-CONTRACT.md):

- Fetch `/api/accounts/users/me/` under the active holder's own key. Match
  account ID and username and require current permission for that catalog.
- Read `/api/vod/{movies|episodes|series}/{id}/` fresh under the same key and
  require the exact returned ID. For a series, use the existing bounded
  season/episode scan and smart target from the holder's own saved progress.
  Read the chosen episode detail again and verify it still matches the
  selected episode and series before playing.
- Use a saved resume point where valid; otherwise start at the beginning.
  Skip the library, details and resume dialogs. Back returns to the guide.
  The player builds the same-origin `/proxy/vod/...` URL from verified
  metadata. Unknown containers, hidden titles, missing/denied details and
  ambiguous or exhausted series targets do not play.

This is app-side support for private Dispatcharr connections, not for Xtream
or M3U. Host tests use synthetic account/catalog responses and verify routing
and player requests, not device decoding, live provider behavior, public
search, or Roku certification/submission.
