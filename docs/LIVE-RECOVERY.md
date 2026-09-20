# Bounded live recovery and Retry — development 0.3.14

Implementation for `mxz.5` / `mxz.6`. Native controller/media evidence below does
not close their remaining physical/outage validation or the broader `mxz.7`
resource audit. Use `PHYSICAL-VALIDATION-CURRENT.txt` for all pending checks.

## Policy

- Existing startup recovery stays at one retry for a confirmed buffering stall
  or a 25-second startup deadline.
- After playback has actually reported `playing`, permit **one midstream local
  reconnect per intentional tune** for unexpected live `finished`, a confirmed
  buffering-stall/timeout error, or 20 continuous seconds in native `buffering`.
- Reconnect by stopping this local Video attempt and cloning the exact content,
  including MPEG-TS URL, authentication headers and audio profile. Do not open
  a diagnostic media client, switch the shared source, or stop the whole channel.
- The replacement gets a 25-second startup deadline with its extra startup retry
  already consumed. Successful playback does not replenish its midstream budget.
  This avoids nesting independent infinite retry loops.
- Paused playback is not stalled. No generic decoder-position heuristic is used;
  a frozen picture while native state remains `playing` is outside this policy.
  Existing post-source-switch picture recovery retains its separate guarded path;
  the general reconnect is suppressed during source operations/recovery.
- Reported 401/403, 429 and connection-limit refusals never enter automatic
  reconnect. Unknown codec/media errors reach the failure UI directly.
- Coalesced channel selection wins over recovery. Explicit Stop, account changes,
  retune and app exit cancel old work. **Back-to-mini continues the same session**
  and does not cancel recovery, consistent with the accepted player contract.

## UI and manual intent

Buffering hints show native state and monotonic elapsed seconds, without invented
byte counts or progress percentages. Final failures release local playback and
offer a native focusable dialog: **Retry channel / Return to guide**, with channel
context and sanitized native diagnostics. Retry is a new intentional attempt;
it uses the current accepted audio setting and preserves mini presentation when
appropriate. Repeated/stale dialog callbacks cannot enqueue duplicate retries.
Back/Return dismiss the failed context and restore guide focus. Account changes
and a successful lineup refresh invalidate saved retry context.

## Verification

`npm test`: **30 suites**. Actual recovery/controller tests cover:

- exact content URL/profile retention, one-attempt cap, exhausted startup budget;
- pause, startup, source-recovery and pending-retune exclusions;
- monotonic 20-second boundary and content replacement;
- refusal and unsupported-codec classification;
- manual Retry, Return/Back, old-dialog events, repeated selection, account change,
  mini restoration and sanitized error formatting (existing PlaybackModel suite).

Native 3820RW2 / OS 15.3.4 / Dispatcharr 0.31.0, 2026-09-20 UTC:

1. A temporary fixture tuned a working ESPN channel, waited for `playing`, and
   **injected the controller's unexpected-end signal**. It did not create a real
   network/provider outage.
2. Automatic reconnect succeeded with a replacement ContentNode and **same URL**;
   a second automatic reconnect was rejected.
3. A controlled final-failure dialog exposed two buttons. Programmatically selecting
   Retry returned the same channel to `playing` with a reset manual-attempt budget.
4. Mini retained the same ContentNode. Native pause remained paused with no stall
   watch/retry; resume and explicit Stop worked.
5. Read-only Dispatcharr status sampling began **before tuning**. The first status
   was unavailable and the fixture used an empty ID baseline; it did not prove
   absence of unrelated clients. Subsequent actual client counts were 1 normally,
   transiently **2 after automatic reconnect / 3 during an intentionally immediate
   subsequent manual retry**, then back to 1. After Stop, counts reached 0 and the
   idle channel status subsequently disappeared. Reported source URL remained the
   same while available (only equality was logged, never the URL).

Those transient counts are not a single-client-at-every-instant guarantee. They
show eventual cleanup in this sample, not upstream TCP/session counts, another
viewer's continuity, or an endurance result. No second viewer was deliberately
established. The retained fixture now records HTTP status and requires either a
valid client snapshot or a 404 before declaring its pre-tune baseline ready; that
additional fixture guard was not part of the captured run.
An earlier fixture attempted to classify clients by a version-specific User-Agent
while the media header still carried the previous development version. Its
ownership labels are discarded in favor of the corrected pre-tune identity
baseline; this is a fixture/version mismatch, not evidence that Roku ignores the
header. The normal build's header version is corrected to 0.3.14.

All temporary fixture imports/autoplay hooks are excluded from the normal package.
The final normal 0.3.14 package passed compiler/build and native installation;
its 25-second captured run populated three guide windows without runtime errors.
Real outage/server recovery, physical Retry focus, bursty retunes and Home with
another viewer remain required validation; the relevant beads stay open.
