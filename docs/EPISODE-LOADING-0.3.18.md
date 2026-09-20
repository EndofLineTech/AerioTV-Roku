# Deep Space Nine episode loading — 0.3.18

PO physical failure: E06 on 0.3.17, *Star Trek: Deep Space Nine*. The user clarified
that Browse episodes reported no available episodes. Other episode playback E26
passed, so this was investigated as a catalog-loading failure rather than a
general player failure. Tracked by `AerioTV-Roku-l4j.17`.

## Diagnosis

The initial broad `Deep Space` search also matched an unrelated 2016 series. Those
first observations were not counted as DS9 evidence. The corrected probe selected
the exact DS9 record using its TMDB identity580.

On the Roku against Dispatcharr0.31:
- Exact DS9 episode query: zero rows/total0.
- Default provider6: `episodes_fetched=false`, `detailed_fetched=false`.
- Repeating that provider's metadata request still left total0.
- The new bounded loader tried alternate metadata sources and returned **20 rows
  from44 currently available episodes** in **2,883ms**.

This establishes available episodes, not a claim that all seven seasons are
present in the configured provider catalogs.

## Fix

- Load episode metadata when Browse episodes needs it, instead of silently
  ignoring a provider-info failure during the series details request.
- Read the first episode page fresh so an earlier cached empty page cannot mask
  newly fetched episodes.
- If that first unsearched page is empty, attempt metadata hydration from at most
  three distinct providers, within the existing30-second Task deadline. Duplicate
  relations from one provider do not consume repeated attempts.
- Respect an explicit provider filter. These requests load metadata only; they
  do not start or stop media streams.
- Keep the1-MiB ordinary response cap; the provider-relations discovery uses the
  existing8-MiB ceiling and restores the ordinary cap afterward.
- Distinguish unsuccessful hydration from a confirmed empty catalog. Exhausted
  loading failures offer Refresh rather than falsely declaring no episodes.
- Clear the series category while entering episodes, and restore category/provider
  context with series focus on Back.

## Verification

The actual production UI was exercised by `tests/native/EpisodeBrowseProbe.brs`:
one matching DS9 series -> Browse episodes -> page1 **20/44** -> page2 **20/44** ->
Back to the original series at index0, with the library in the focus chain.
This was metadata/UI validation without playback. Temporary hooks were removed.

`VodSeriesLoader.test.brs` covers failed default -> successful alternative,
exhausted attempts, explicit provider filtering, cancellation and restored byte
limits. It runs in the normal test suite. Scripted tests do not replace physical
acceptance.

All39 suites, compiler/build and diff checks passed. The normal0.3.18 package
installed successfully and loaded guide mappings/windows in a30-second capture
without runtime errors. No probe hooks remain in the normal application.

## Focused retest

Use installed0.3.18. Guide -> * -> TV Shows -> * -> Search -> enter
`Deep Space Nine` -> Search -> choose
*Star Trek: Deep Space Nine (1993)* -> Browse episodes. Verify populated rows,
season/episode labels, FF/Rew paging, and Back to the selected series. Then test
one available episode if desired. E06 remains the PO's recorded failure until
the PO retests it; the marked0.3.17 worksheet is preserved unchanged.

The French-description report is separately tracked in `l4j.18`. The requested
top-level Live TV/VOD navigation is recorded on `b17.2`; neither is represented
as fixed by this change.
