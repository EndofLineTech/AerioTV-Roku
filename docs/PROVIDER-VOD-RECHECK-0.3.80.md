# Provider6 VOD recheck — 2026-09-25

This is a bounded, read-only recheck of the historical `l4j.16` upstream 405
from `MEDIA-BLOCKER-FIXES-0.3.17.md`. No Dispatcharr/provider configuration,
account, catalog item or streaming profile was edited. Credentials, provider
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
- Dispatcharr's currently authorized series episode listing contains **50**
  episodes. Its historical S03E01 episode ID now returns **404** at the details
  endpoint. Compared with current upstream numbered metadata, S03E01-E10 and
  S03E12-E13 (12 episodes) are missing from that listing. The former exact
  Roku catalog item therefore cannot be physically retested as a present
  Dispatcharr title. The separate `AerioTV-Roku-3rq` issue tracks the catalog
  mismatch and any approved server-side correction.

## Disposition

The historical upstream 405 is **not reproduced by these current direct and
proxy Range samples**; no Roku-side or server-side fix was made in this recheck,
and its original root cause is unknown. This is not a universal provider-health
claim or a claim that missing catalog rows have returned. Source selection
remains the documented Roku fallback for unavailable provider copies.
