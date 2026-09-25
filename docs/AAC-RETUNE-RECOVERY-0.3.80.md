# Automatic AAC decoder-start recovery — 0.3.80 development candidate

`AerioTV-Roku-ssq` was found during final-build resource measurements. On the
target 3820RW2 / Roku OS 15.3.4, one authorized live sample reported Roku
error -5 `Unsupported AAC stream` **before** the Video reached `playing`.
The saved Player setting was confirmed **Auto** in Settings, and the existing
active copy-video/AAC output profile was discovered. The previous missing-
audio check ran only after `playing`, so it could not respond to a decoder
startup refusal. No profile or provider setting was changed for this fix.

The client now permits one local replacement for that exact native error when
Auto is selected, the Dispatcharr connection is still current, and its
existing AAC profile is available. It preserves the intentional tune/startup
retry budget, cannot recursively fall back after an AAC replacement, and
does not silently override Direct mode or affect direct M3U/Xtream sources.
The old Video reader can emit a queued `finished` event just after a new
ContentNode is assigned. For this AAC replacement only, one such early event
is ignored; if the replacement never reaches playback, the existing bounded
startup watchdog still retries/fails. No shared channel or other viewer is
stopped by the local switch.

## Verification and limits

- Unit/controller coverage exercises the exact decoder error, Direct/Always
  AAC exclusions, missing profile, already-ready stream, pending tune,
  once-only replacement and the early outgoing-reader `finished` event.
- A disposable native probe (excluded from the normal ZIP) tuned an already
  working authorized source and retuned to the failing source. It recorded
  direct decoder refusal, **one** existing-profile fallback, then native
  `playing` with `aac_adts` audio and `mpeg4_10b` video. After three seconds
  of confirmed state it stopped this Roku's playback; the Video ContentNode
  was cleared, guide returned and the memory monitor reported 6% app-limit
  usage. The normal development app was reinstalled afterward.
- A bounded read-only Dispatcharr sample of the affected source reported
  HE-AAC in the direct TS and AAC-LC in the existing output-profile TS.
  Samples were processed in memory; no playable URL or media bytes were
  stored in public evidence.
- The PO physically confirmed **moving picture and audible sound** on the
  installed normal app after the automatic retry. This is evidence for the
  tested source on this target, not a universal codec/provider guarantee.

Private native captures remain in ignored `out/`. Media names, account
secrets, provider URLs and raw diagnostics are not part of this document.
