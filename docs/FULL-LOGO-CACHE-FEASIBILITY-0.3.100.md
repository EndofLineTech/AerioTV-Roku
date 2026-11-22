# Whole-lineup logo cache sizing on the alternate Dispatcharr server

The owner's alternate account exposed **1,251 distinct logo IDs** among its
1,354 authorized channels. Roku 0.3.100 fetches logos only as rows become
visible and keeps at most 96 files / 20 MiB in per-connection `tmp:`. This
investigation measured the server's actual proxy responses, not the backing
provider files or a new Roku cache implementation.

A deterministic uniform random sample of 160 authorized IDs was fetched one
at a time through the same logo-cache API path the Roku uses, with its existing
2-MiB per-image ceiling and supported PNG/JPEG/WebP signature check. Nothing
except numeric summaries was saved; no artwork, IDs, URLs or credentials were
written to disk. Results:

| Measurement | Result |
| --- | ---: |
| Successful cacheable images | 160 / 160 |
| Sample body total | 16,969,404 bytes |
| Sample mean / median | 106,059 / 77,491.5 bytes |
| Sample 90th percentile / maximum | 162,441 / 1,244,749 bytes |
| Estimate for all 1,251 if similarly distributed | **132,679,528 bytes (~126.5 MiB)** |
| Conditional bootstrap range for total (95% of resampled means) | **102,672,017–167,081,785 bytes (~98–159 MiB)** |

The extrapolation is not an inventory of every file. Larger or inaccessible
logos among the unsampled 1,091 could change the actual cacheable count or
total; a small 24-ID pilot averaged 125,894 bytes, illustrating the sample
variation. The previous native 80-row browse retained 81 actual logos totaling
10,022,554 bytes, consistent with this order of magnitude.

All 1,251 would exceed the app's **96-file** cap by about 13 times and its
**20-MiB `tmp:`** byte cap by roughly six times at the sampled mean. `tmp:`
counts against app resources, whereas cachefs is shared, evictable storage.
Retaining compressed files would not prevent the much larger and
device-specific texture/decoding cost when Roku displays oversized images.
This study did not download every logo, cache all of them on the Roku, or
establish that whole-lineup retention is safe across Roku models. It supports
lazy, bounded retention rather than prefetching every image at connection.
