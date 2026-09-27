# TV-accessible Roku diagnostics sharing — AerioTV-Roku-kqg

## Current boundary and goal

`components/Diagnostics.brs` already pages session events on the TV and prints
an explicit export to Developer Mode console port 8085. The shared
`diagnosticEvents` model retains **at most 80 events, one hour and 32 KiB** in
app memory; no event history is persisted across relaunch. Its redactor
replaces API keys, HTTP URLs and named credential fields. It is not a general
privacy scrub for arbitrary program/channel names in freeform messages.
Non-developers need a deliberate way to send useful support context without
Roku developer credentials, new external infrastructure or a listener that
keeps running after they exit Diagnostics.

## Platform and product constraints

Roku's documented [`roStreamSocket`](https://developer.roku.com/docs/references/brightscript/components/rostreamsocket.md)
supports TCP listening and accepted connections, so a **short-lived Task**
is technically plausible. The app has not yet proven listener availability on
the 3820RW2, nor a supported HTTPS server API. Roku's
[certification criteria](https://developer.roku.com/docs/developer-program/certification/certification.md)
require responsive navigation, correct Back behavior and review of features
that direct users to external webpages; a future Roku Streaming Store path
needs a platform/policy check before shipping a phone-browser flow. A
Developer Mode sideload is not evidence of Store approval. No always-on
runtime service or Dispatcharr endpoint is assumed.

## Recommended first design: on-TV support snapshot and short code

1. Keep the existing in-app Diagnostics event viewer for owner-visible,
   sanitized text. Its **Show support code** action presents a separate
   privacy-covered screen explaining that only whitelisted `stage`, numeric
   `code`, coarse elapsed-time bucket and relative age are shareable. Do not
   include raw messages, account identity, URLs, title/channel names or
   credentials in the encoded payload.
2. On explicit **Show support code**, encode up to the last eight filtered
   events into a bounded, versioned uppercase code with a checksum (target
   at most 120 characters, shown in grouped chunks). The owner can photograph
   the TV or dictate the code to support. A support-side decoder may be a
   documented offline script; it is not a hosted service. Clear the code on
   Back, account switch or 90-second timeout. Cover the underlying guide or
   player with an opaque privacy surface while it is displayed. The display
   expires; a previously photographed code remains decodable and is **not**
   an authentication token. No listener or background Task is needed.
3. Tag each captured event with the connected account *scope* in memory and
   construct snapshots only from the currently selected scope; clear it on
   account change. The code contains no scope value. Enforce strict bounds
   before encoding and reject corrupt versions/checksums in the decoder.
4. On the target Roku, verify readable/usable focus and Back, max-length
   truncation, expiry, account switch, permission downgrade, 120% text,
   Audio Guide-safe labels, and redaction with sentinel secrets/media names.

This is a supported-equivalent **manual transfer**, trading rich raw log text
for a smaller, privacy-preserving report. It avoids adding a service or
requiring a companion application. The existing console export remains for
developers. The PO selected this summary-level payload for implementation;
the owner can request richer data later through a separately reviewed design.

## Alternative if full-text transfer is required: one-use LAN pull

After a separate PO/platform decision, a SceneGraph Task could listen only
while an explicitly confirmed Diagnostics share panel is visible. Display
the Roku's LAN address and a random one-time pairing code; serve **one**
strictly filtered report (at most 4 KiB) through a bounded GET, then close
the socket. Limit to 90 seconds and three failed pairing attempts; deny other
methods/paths, oversized requests, non-private-network clients and concurrent
connections. Cancel on Back, app exit, account/permission change, or timeout;
never persist the token, client IP or response. Restrict shared fields to an
approved allowlist rather than exporting `diagnosticEvents` freeform text.
First establish that the target can bind and close a listening Task and that
the phone-browser flow is acceptable for the intended distribution tier.

## Security assessment and decision

| Finding | Inherent / residual risk | Evidence and control |
| --- | --- | --- |
| Freeform message disclosure | Medium (5.3) / Low (2.4) for the proposed short code | Current sanitizer covers URLs and named secrets but not every media/account label. Only allowlisted numeric event facts enter the transferable report; no raw text leaves the TV. |
| LAN report access or replay | Medium (5.0) / Medium (4.0) for an HTTP-only LAN option | A same-network client could request or observe sensitive content. One-use code, attempt cap, expiry and strict payload reduce exposure but cannot protect HTTP traffic on an untrusted Wi-Fi network. Prefer the no-listener design unless full-text transfer is required and risk explicitly accepted. |

Risk ratings reflect the tested single-household sideload context, local
network access requirements and the current one-hour in-memory limit; they
are not a claim of Roku Store certification or universal network safety.

**PO decision:** the owner selected the no-listener on-TV support code.
Implementation and native privacy evidence are tracked separately in
`AerioTV-Roku-e76` and [the support-code guide](ROKU-DIAGNOSTICS-SUPPORT-CODE.md).
The LAN listener remains an unapproved alternative, not a fallback that the
app starts automatically.
