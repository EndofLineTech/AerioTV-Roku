# Approved provider-backed rewind — 0.3.28

Implements34y.11 under the PO's explicit decision in `REWIND-ARCHITECTURE.md`.
This is existing-provider catch-up history, not a local one-hour recording buffer.

## Entry and bounds

While watching live, press **Rew**, or hold OK → **Rewind history (provider)**.
Entry requires current account permission, authorized channel membership, positive
advertised retention and a requestable whole-minute timestamp since this tune.
Unsupported/too-early entry leaves live playback running and explains why.

The earliest requestable minute is the ceiling of the later of tune time and
now minus3600seconds. The latest is a whole minute that has already begun airing.
Thus usable history can be slightly less than an hour, and provider lag/gaps may
make any request unavailable. Minute arithmetic stays integer to preserve UTC.

Tap/hold seek controls and configured1/2/5-minute intervals reuse the verified
archive controller. Held preview is local only; commit revalidates the moving
bounds before replacing the owned session. Pending previews also move into the
current range if their target ages out.

The Task revalidates the window again after fresh account verification, immediately
before creation, so cleanup/auth delays do not preserve an obsolete target. It
rejects a mismatched returned UTC start and revokes the minted session. The player
uses the Task's actual requested start when calculating its reopened offset.

## Clocks, pause and cleanup

- The panel labels **REWIND (provider)**, estimated broadcast time, delay and
  **requestable** history. It does not label a nonexistent native/cache buffer.
- The historical guide window is loaded through the bounded, account-scoped guide
  cache. Metadata follows the playhead across programs; missing/cached data remains
  explicit. The existing cache limits and real-wall-time freshness apply.
- While paused, the current reader is preserved. If its position ages out of the
  request window, an explicit warning appears; a subsequent seek clamps into the
  new range. A provider may continue serving the existing reader, but older new
  seeks are not allowed. There is no forced silent jump to live.
- One local media reader, sequential owner deletion/replacement, no local media
  spool and no additional background channel ingestion.
- Go Live restores the same authorized channel and original tune epoch, including
  an AAC-profile wait. A different channel/intentional new tune starts a new range.
- Back/account changes cancel creation and release context/session ownership.

## Native verification

Production-controller fixture on channels3.3 and57.5, with actual provider media.
The fixture **injects a two-hour-old tune epoch** to exercise the hour boundary
without another warmup. This is a boundary/controller test, not a claim that this
app retained two hours. The separate actual hour-long native experiment is recorded
in `REWIND-ARCHITECTURE.md`.

Observed oldest requested ages included3551,3575,3561,3593,3577,3599 and3579seconds;
native playback advanced beyond5seconds. Requested UTC echo matched. Native checks:

- unsupported entry kept live playing;
- provider mode and account/tune scope were preserved;
- owner DELETE204 before replacement;
-70seconds paused at the oldest edge produced the explicit aged-out warning;
- an expired target clamped forward into the current hour and stayed paused;
- a newer window opened paused; held preview did not reopen a session;
- Go Live preserved channel and tune epoch;
- cancel during a new request produced no late open and cleared context/session.

One57.5 replacement returned native HTTP503. That failed media attempt is retained
as evidence, not counted as successful playback. A later native run verified the
unavailable message, no automatic live substitution, explicit Go Live and cleanup.
Subsequent full-path verification also passed. Historical program metadata became
available after adding playhead-targeted background guide loading.

Sampled peak app memory was23-24% during complete paths; the fixture's60%
guard did not fire. `tests/native/ProviderRewindProbe.brs` retains the experiment.
Temporary hooks and manifest selectors are removed from the normal package.

44 suites cover bounds, minute rounding, since-tune/future rejection, aged targets,
outside-window clocks, generic seek state and AAC-wait tune-epoch preservation.
Native scripted checks are distinct from physical remote/content acceptance.
