# Catch-up channel indicators — 0.3.21

Requested by the PO; tracked as `AerioTV-Roku-6i6`.

Guide channel headers now show a compact **CATCH-UP** text badge above the channel
name, alongside the number and existing FAV badge. This is readable without relying
on an unfamiliar icon or color alone. Channel names/logos retain their space.

The selected-channel summary and program details show **Catch-up: 1 day** or
**Catch-up: N days (provider advertised)** using Dispatcharr's actual channel
retention. This is channel-level information, including for current/future programs;
the existing completed-program eligibility rules still control Play archive.

Indicators require both account catch-up permission `allowed` and positive known
channel retention. Unknown/denied permission, missing facts and zero/negative
retention hide them. Capability refresh updates visible guide rows and an open
details view. Reused guide rows recompute the badge for their current channel.

## Verification

- Model regression: allowed/denied/unknown permissions, missing channel/facts,
  positive/zero/negative retention, singular/plural labels.
- Native scripted GuideView fixture on Streaming Stick 4K: badge present in modal,
  sidebar and pills layouts; actual sampled details retention **3 days**.
- Native permission revocation hid the badge and cleared the detail retention;
  clearing channel facts hid the badge. Fixture restored permission/facts/layout
  and selection, and did not start playback or write preferences.
- Fixture retained at `tests/native/CatchupBadgeProbe.brs`; temporary production
  hooks removed after verification.

Physical visual check: compare supported and unsupported channels, including a
favorite; open program details and confirm the displayed retention. The label
advertises channel support, not a guarantee that an individual archive is ready.
