# Media blocker fixes — 0.3.17

## Archive reader and seeking (`34y.15`)

Native ContentNode introspection identified the wrong reader hint:

| Requested | Native stored value |
| --- | --- |
| `mpegts`, `mpeg2ts`, `mpeg2`, `mpeg-ts`, `mp2t` | `NONE` |
| `ts` | `ts` |
| `mp4` / `mkv` | `mp4` / `mkv` |

Archives now explicitly use **`ts`**. The previous `mpegts` hint was being rejected,
leaving playback dependent on autodetection. The accepted live-TV path is not
altered in this change.

Archive seek uses a **one-minute server-window reopen**, not the unreliable native
seek field: clamp the requested program offset, stop this local reader, revoke its
owned session, then create a new session at original UTC start + offset with the
remaining duration. Original title/program identity remains pinned. Pause state is
restored after reopening. Requests are coalesced while a seek is pending; Back and
account changes cancel publication and clean up late successful creations.

Native production-controller verification, 3820RW2 / OS15.3.4 / Dispatcharr0.31:

- Initial archive `playing`, offset0, native duration still -1.
- Forward: `playing`, new session, **server-echoed UTC delta60**, old DELETE204.
- Backward: new session, **server-echoed UTC delta0**, old DELETE204, **paused**.
- Resume then exit: final DELETE204, returned to guide.

This supports minute-granular program-window navigation. It does not promise
frame-accurate native scrubbing or a retained60-minute live buffer. Physical content
alignment/audio remains in the consolidated worksheet.

A rejected experiment wrapped a complete archive in one local HLS segment. Roku
requested a332,985,088-byte reservation against a31,616,000-byte buffer. That approach
was removed, along with its render-thread filesystem cleanup attempt. It is not
part of the normal app. An early fixture also waited for Task state `done` instead
of checking its result; the final successful run checks the completed result.

## VOD source failures and recovery (`l4j.14`, `l4j.15`)

A controlled1-KiB Range reproduction, performed instead of concurrent playback,
extracted Dispatcharr's error: **upstream405 Method Not Allowed**, wrapped as HTTP500.
The failing request used a normal XC `/series/.../.../...mkv` path on an external
provider. The tested account/provider was active and VOD-enabled. This is not a
Roku codec diagnosis.

The series had36 source relations across three providers. The small enrichment
limit hid the larger provider list; version discovery now permits the existing
8-MiB raw-response ceiling while only20 normalized, credential-free choices enter
the UI. Explicit selection re-fetches metadata for the selected relation and
requires the **exact episode ID**. A metadata-only comparison confirmed the same
S03E01 database identity between the failing and working provider copies.

Admin-authorized title details now expose **Choose source version**. Library
options also offer **Choose source for selected title**, so a removed/unavailable
saved source cannot prevent choosing another. Valid selected relation IDs are
remembered in account/item state. **Use Auto source** clears the override.

Native results using the available alternative source:

- Episode S03E01: **MP4, duration2832, AAC**, playing; seek60 resumed at62.896;
  pause/resume continued to68.902 before Stop.
- Movie through actual production Tasks/player: **Matroska, duration8293**;
  seek progressed to67.693, saved resume67, reopened at63.605 (keyframe-granular),
  then exited. Sampled peak app memory14%.

The upstream provider returning405 has **not** been repaired by client code.
Source selection is the client-side resolution that permits the same title/episode
to play, seek and resume using a working rendition. No automatic source-swapping
loop or extra concurrent media probe was introduced.

## Authentication correction

Dispatcharr0.31's VOD connection manager forwards `Authorization` upstream. The
on-demand player now authenticates using **X-API-Key only**. This removes the
unnecessary duplicate credential header. Removing it alone did not resolve the
tested provider405; the source failure and header correction are separate findings.

## Verification and reproduction

- `npm test`:38 suites, including reader mapping, seek clamping, URL/scope rules,
  owner cleanup, saved-version validation and credential-free version normalization.
- `npm run check` / `npm run build` pass.
- `tests/native/ArchiveSeekProbe.brs`: actual archive controller lifecycle.
- `tests/native/VodAppProbe.brs`: actual version/detail/player/progress flow.
- `tests/media-probe`: parameterized provider sample and isolated HTTP/log diagnosis.
  Log inspection found recent catalog-refresh output rather than the older media
  errors; no conclusion was drawn from the absence of those log lines.
- All production probe hooks are removed before the normal package is restored.
