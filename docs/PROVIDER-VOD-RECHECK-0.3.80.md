# Provider6 VOD recheck — 2026-09-25

This began as a bounded, read-only recheck of the historical `l4j.16` upstream
405 from `MEDIA-BLOCKER-FIXES-0.3.17.md`. A later, explicitly PO-approved
single-series metadata refresh is recorded separately below. No provider
configuration, account or streaming profile was edited. Credentials, provider
hostnames, redirects and playable URLs are not included in this record.

## Observations

- The verified admin identity and provider6/alternate accounts are currently
  active and VOD-enabled. Provider6 is an Xtream account with an active default
  profile using the identity credential transformation. Its previous upstream
  405 was observed through Dispatcharr as HTTP 500; changing Roku's API header
  did not repair it at that time.
- The provider's series metadata GET currently succeeds and advertises **62**
  numbered episodes. The prior S03E01 fixture remains advertised upstream with
  a Matroska extension. A two-byte Range GET on its generated provider path
  receives a redirect, and the redirected HTTP target returns **206** with a
  Content-Range and two readable bytes. The matching HEAD/Range request also
  returned **206** at the target. Redirects were inspected one hop at a time;
  no Dispatcharr API credential was sent to the redirected host.
- Two **currently cataloged** episodes in the same series, one from season 1
  and one from season 3, returned HTTP **206** and 1,024 bytes each through
  the Dispatcharr VOD proxy when provider6 was requested. These samples do
  not prove every provider6 movie, episode or profile is healthy.
- Before the approved refresh, Dispatcharr's authorized series episode listing
  contained **50** episodes. Its historical S03E01 episode ID returned **404**
  at the details endpoint. Compared with current upstream numbered metadata,
  S03E01-E10 and S03E12-E13 (12 episodes) were missing from that listing.
  At that point the exact Roku item could not be retested from the catalog.
  The separate `AerioTV-Roku-3rq` issue tracked this mismatch and its approved
  server-side correction.

## Approved one-series hydration and verification

The PO approved **one** bounded Dispatcharr refresh of the affected provider6
series after read-only inspection found its relation had
`episodes_fetched=false`, `detailed_fetched=false`, and no episode-refresh
timestamp. The existing provider-info action was called once for that relation
with `include_episodes=true`, causing Dispatcharr's documented lazy provider
refresh. It returned HTTP **200**, five season buckets and **62** episodes,
with `episodes_fetched=true`. This client requested no refresh for another
series and made no profile or account edit.

Read-only follow-up confirmed the authorized series listing is now **62/62**;
all 12 formerly missing season/episode positions appear, and the provider6
relation reports `episodes_fetched=true` with a refresh timestamp. An explicit
provider6 proxy GET for the exact restored S03E01 item with a 1-KiB Range
returned HTTP **206**, Content-Range and 1,024 readable bytes. No Roku picture
or audio claim follows from an HTTP range result. `AerioTV-Roku-3rq` tracks
the catalog discrepancy that this approved hydration resolved.

## Disposition

The historical upstream 405 is **not reproduced by current direct and proxy
Range samples**. The separate approved one-series refresh restored the missing
catalog rows; it did not change a provider stream URL, Roku media handling or
the external provider configuration. The old 405's root cause is unknown, and
these bounded samples do not guarantee every rendition works. Source selection
remains the documented Roku fallback for other unavailable provider copies.
