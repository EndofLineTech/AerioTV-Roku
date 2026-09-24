# Direct M3U / XMLTV on the target Roku — isolated probe

The Product Owner selected **direct Roku connection types** for the existing
Dispatcharr M3U, XMLTV and Xtream outputs. This supersedes the earlier plan
to use Dispatcharr APIs for every client-side guide request. The supplied
M3U/EPG feeds are exports of that same server; importing them back into it
would form a loop. The ordinary Dispatcharr connection and MPEG-TS playback
remain the working baseline.

Read-only examination of the same-server exports found a 294,172-byte M3U
with 953 live entries, all using same-origin TS proxy URLs. Its 953 `tvg-id`
values matched the 953 `<channel id>` values in the XMLTV export. The XMLTV
response was 61,159,877 bytes uncompressed and did not honor HTTP byte Range.
The existing 16-MB JSON request boundary cannot parse this feed in memory.

`XmltvModel.brs` now bounds a 72-MiB temporary file, reads up to 16-KiB slices
on a Task thread without cutting UTF-8 code points, and indexes only programmes
for a requested three-hour window. Programme fragments are bounded to 16 KiB,
the window to 24,000 programmes, and the scan to 45 seconds. The common XMLTV
fields use a fast text extractor with entity decoding; unfamiliar nested or
malformed fields use the native fragment parser. Native `roFileSystem` must
not run on the Scene render thread: the first isolated probe demonstrated the
runtime error, and the Task-thread probe fixed it.

The isolated ZIP `out/xmltv-probe.zip` is assembled by
`scripts/build-xmltv-probe.py` and does not affect the ordinary channel ZIP.
It checked a package fixture via native `roXMLElement`/`roByteArray` and a
full read-only copy of the real feed on Streaming Stick 4K (OS 15.3.4). A
953-channel live three-hour window indexed 1,751 programmes in **17 seconds**
after download, within the probe's 45-second scan bound. This established a
native parser path before it was wired into selectable direct connections in
0.3.76; see [device checks](DIRECT-CONNECTIONS-0.3.76.md). The ignored probe ZIP
may contain the private test endpoint; no URL, credential, channel name or
programme title is committed here.

The supplied XMLTV response is plain XML; asking it for HTTP gzip returned an
identity-encoded response. The Roku transport enables HTTP compression, so a
server that responds with `Content-Encoding: gzip` can be handled after
transparent decoding. A native package fixture verified that a **raw gzip
file** is detected and rejected before UTF-8/XML parsing, rather than causing
a Task runtime error. Raw `.xml.gz` decompression is not yet implemented or
claimed; no matching provider fixture was supplied.

A later public `.xml.gz`-named candidate returned plain `<?xml` bytes with
identity Content-Encoding, despite an application/gzip MIME type. Its HTTP
Content-Range advertised roughly 312 MB, above the Roku's 72-MiB staging cap.
Only bounded HEAD/Range/full-GET header samples were read; this endpoint
cannot establish raw gzip decoding or a feasible full-device guide load.
