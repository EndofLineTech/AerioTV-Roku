# Direct feed gzip boundary (`AerioTV-Roku-e3e.24`)

This compares Roku `e945ec4` with the locally staged Apple `fe7ad4c` source.
Apple’s `Networking/PlaylistParsers.swift` uses Apple Compression and
file streams for raw XMLTV gzip; it considers the URL extension, MIME type
and magic bytes. Its M3U fetch takes a URLSession download through the text
playlist parser, with no explicit raw-gzip decoder. The pinned
`DeviceSetupHandoff.md` carries playlist and XMLTV URLs plus separate
`localUrl` and User-Agent fields; it does not define a gzip wire capability.
`DispatcharrSyncSchema.md` scopes that Sync provider to Dispatcharr, not
M3U/Xtream feed transport.

| Response | Roku behavior |
| --- | --- |
| Plain feed, even on a `.gz` URL or with a gzip MIME type | The staged bytes go through the existing M3U or XMLTV text path. Neither format is chosen by extension or MIME type. |
| HTTP `Content-Encoding: gzip` | XMLTV already enables Roku `roUrlTransfer.EnableEncodings(true)`; the parser accepts XML bytes if the transfer stages the decoded entity. This pass did not verify that result on Roku. M3U does not opt in; there is no new M3U HTTP-gzip support claim. |
| A raw gzip file left in staging (`1f 8b`, regardless of URL or MIME type) | XMLTV already rejects it before parsing. M3U now rejects it before `ReadAsciiFile`, with an instruction to use a plain playlist. Neither path decodes raw gzip. |

The host regression generates ordinary one-channel M3U and one-programme
XMLTV fixtures. It checks raw gzip, the same wire bytes decoded on the host
to model HTTP transport output, and plain files named `.gz`. The interpreter
uses a small staged-file prefix read adapter; the fixture verifies the app’s
prefix and text parser decisions, not Roku transfer, cancellation, disk or
memory behavior. Run `node --test scripts/direct-feed-gzip.test.mjs`.

The change leaves URL and request-header policy alone: no new authentication
or Referer forwarding, redirect handling, endpoint substitution, or host
fallback. The M3U prefix check reads two bytes only after the existing
2-MiB file check (30-second download, 4,096-character lines, 5,000 channels).
XMLTV retains its 72-MiB staged-file check (45-second download and a separate
45-second parse, cancellation and memory-pressure checks, up to 16-KiB reads,
16-KiB programme fragments, and 24,000 indexed programmes per three-hour
window). The transfers poll temporary-file size and recheck it before
parsing; these are not hard size quotas on a native transfer in progress.

**Native prerequisite for raw gzip:** identify a supported Roku Task-thread
API that can inflate an RFC 1952 file incrementally with caller-controlled
output, not just decode HTTP content. The pinned BrighterScript 0.73.5 Roku
API data describes `EnableEncodings` as a transfer feature and
`roByteArray.ReadFile` as a byte read; it does not establish such an inflater.
Before enabling raw support, validate a candidate on the supported Roku
hardware/firmware with small known-good files. Demonstrate independent
compressed-input and decoded-output budgets (decoded text stays within the
existing parser caps), bounded intermediate storage and per-step work,
end-of-stream/integrity reporting, and cancellation/deadline with cleanup.
Separately qualify what `AsyncGetToFile` stages for actual HTTP gzip using
the same feed fixtures. Do not treat a filename, MIME type, or host fixture
as evidence for either native capability.
