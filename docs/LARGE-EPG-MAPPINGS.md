# Large EPG mapping responses (development candidate)

Dispatcharr 0.31 ignores `page` and `page_size` on its EPG-data list. When
that list exceeds the Roku client's 16,000,000-byte metadata limit, the guide
cannot resolve explicit EPG assignments. A failed full-list request now falls
back **only when the failure is `response-too-large`** to authenticated detail
GETs for the assignment IDs in the current authorized channel lineup. At most
eight 64-KiB file-backed replies are in flight; each has a 20-second timeout
and the lookup has a 120-second deadline. Missing (404) assignments keep the
existing direct-ID fallback; other failures do not cache a partial mapping.
Results use the existing account- and lineup-scoped five-minute mapping cache.
Cancellation closes transfers and removes temporary files. The full-response
guard and memory-pressure handling remain in place. This path is only for
Dispatcharr mappings; oversized three-hour guide-grid responses still require
separate investigation if observed.

Logo downloads are separate. The guide's Diagnostics viewer now records
aggregate failed-download reasons (HTTP status, timeout, oversized, empty, or
unreadable image) without channel IDs or URLs, and reports visible channels
without usable logo IDs. A first-six-only symptom may be missing IDs or a later-batch
failure; the new log distinguishes these before a targeted correction.

Verification: `npm run release:prepare` passed, including tests, compiler,
build and package checks. A controlled Roku 3820RW2 run of the exact v0.3.97
source ZIP displayed the guide and follow-up logos on a 36-channel account.
A disposable ZIP forcing the oversize fallback (without changing the server)
resolved 36 authorized assignments natively in 899 ms after lineup; the
unmodified ZIP was then restored. See [beta candidate](BETA-CANDIDATE-0.3.97.md)
for bounded evidence. The affected 91-channel large-list account still needs
its own beta acceptance run.
