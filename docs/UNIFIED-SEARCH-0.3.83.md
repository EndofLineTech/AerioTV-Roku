# Unified Roku TV search — AerioTV-Roku-ajr

The guide's existing **Search EPG / movies / TV together** destination now
offers All, EPG title, EPG description, Movies, and TV Shows scopes. In All,
one native keyboard submission fans out to the existing server-indexed EPG
Task and the existing account-verifying Movies and TV Shows Tasks. Authorized
results appear interleaved on the same remote-navigable list so all three
types can appear on its first screen. Movie/series selection rechecks the
current account and opens its normal server-verified VOD detail. Back returns
to the same search row; an EPG result returns to its mapped channel and
program in the guide. A VOD search detour does not replace the saved library
browse bookmark.

The EPG Task uses 50 server-indexed programs per page with an explicit
200-airing lineup fanout ceiling and the account's configured guide dates.
Each VOD Task requests at most 20 titles per page, validates `/users/me/`
permissions against the connected account, and uses the existing trusted-page
and bounded HTTP policies. The mixed list caps at 240 entries per page,
rebuilds its own next-page requests and never follows server-provided next
URLs. Stale Task events and account changes cannot open VOD details, and a
permission refusal empties partial results. Search remains cancelable with
Back; source failures identify affected domains without exposing HTTP URLs.

Direct Xtream/M3U connections have no equivalent shared Dispatcharr index.
The Guide options identify this limitation; direct channel search and
Xtream's existing category-scoped search remain available. No cross-category
scan or new server write is introduced.

## Verification

Model/controller tests cover scope permission gating, bounded interleaving,
partial failures, authorization refusal, stale-account suppression, invalid
queries, and the saved library bookmark guard. `npm run verify` checks the
packaged app and tooling. On the target Roku 3820RW2 / OS 15.3.4, a single
credential-free query string produced EPG, Movie, and TV Show rows together.
The permitted Movie and TV Show rows each opened their existing detailed view,
and Back restored focus to the corresponding search row. An EPG row jumped to
its authorized channel and airing; the ordinary Guide Replay returned to
Now. Private screenshots stay ignored under `out/` and decoded playback
picture/audio is not asserted by these search navigation checks.

This feature and the accepted guide/DVR-icon polish are post-v0.3.82
development work. The published v0.3.82 ZIP remains unchanged; a later
testing release must exclude the unverified HLS recovery candidate; see
the [v0.3.83 release boundary](RELEASE-0.3.83.md#explicit-release-scope-and-limits).
