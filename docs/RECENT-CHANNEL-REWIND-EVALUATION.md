# Recent-channel rewind evaluation — 34y.14

Conclusion for the approved34y scope: **do not retain inactive media ingests**.
Maximum inactive readers/sessions is0; changing channel, stopping or changing
account closes the old local reader and releases any owned archive session.
Returning to an old channel establishes a new since-tune range. Its older programs
remain discoverable through the existing guide/catch-up workflow.

## Basis

- The actual hour-long native TS test could not rewind one hour. Adding background
  readers would not turn that unsupported native transport into retained history.
- The approved path requests history already held by the provider. Keeping a live
  reader open on an inactive channel does not create or guarantee that archive.
- Single-reader experiments measured client cleanup0→1→0 in the pause test,19%
  app memory after the live hour, and23-24% sampled peak during provider-rewind
  controller path. These are single-reader observations, not multiview capacity.
- Additional distinct channel ingests would add downstream bandwidth and may add
  provider slots. At1Mbps, local storage for an hour is450MB per channel before
  overhead; two channels would need900MB. This is an estimate, not a measured
  multi-reader run, and exceeds the271-289MB available-memory samples already seen.
- Roku's evictable RAM-backed cache is not a retention guarantee; this device has
  no demonstrated writable external media-spool path.

No additional concurrent-ingest experiment was run or extra slots reserved. That
would require a new PO scope decision and device/provider capacity measurements.
The existing recent-channel navigation remains; automatic preservation of a
previous channel's rewind session is excluded rather than represented as working.

References: `REWIND-ARCHITECTURE.md`, `RESTART-POSITION-0.3.26.md`,
`PROVIDER-REWIND-0.3.28.md`. This completes the evaluation; it is not an implementation
or acceptance claim for multi-channel retention.
