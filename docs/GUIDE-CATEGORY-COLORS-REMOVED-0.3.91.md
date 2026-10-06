# Removing program-category backgrounds from the Roku EPG

Beads `AerioTV-Roku-cug`. The PO chose a neutral program-cell background rather
than waiting for categories to arrive and tint some programs after the channel
lineup is already on screen. This change is in the local
`fix/guide-first-paint` candidate based on `dev` v0.3.91.

- Every unfocused program cell uses the same neutral card color. Focus retains
  its visible border and focus wash. Program titles, times, subtitles, episode
  details and LIVE/NEW/premiere/finale status pills remain; their status colors
  do not represent program categories.
- The `* > More guide actions > Guide settings > Category colors` branch,
  category matching-rule and palette editors, and the Appearance rail's
  category-colors setting are gone. An old `categoryColors` settings event is
  rejected. Legacy account guide preferences containing `categoryColors`,
  `categoryRules` or the retired category `palette` are discarded on
  normalization without changing other settings; the sanitized model will be
  persisted on the next account-preference save.
- EPG category data remains in normalized/cached programs for information
  surfaces and search. The authoritative EPG mapping/window loading pipeline
  and visible-logo prefetch do not depend on the removed tint classification.

`npm run verify` passes with regression coverage for legacy settings and both
settings entry points. After the network route recovered, the developer
installer accepted the exact verified 0.3.91 ZIP (SHA-256
`a90b1bfc2894e4f331241e6e61c314231c519b2c4becb42270c91e6f5cb332d0`)
on the Roku 3820RW2 / OS 15.3.4. With the authorized 36-channel EPG populated,
native captures confirmed neutral unfocused programs including previously
tinted news/drama titles, visible QVC focus styling, LIVE/NEW status pills and
the real channel logos. The Appearance rail showed no Category colors control;
Guide settings remained reachable. Home then cold-relaunched the same dev
build: the populated guide was still neutral with focus, badges and logos.
Private images stay under ignored `out/` and are not committed. The device
remained active with monotonically increasing uptime.

Earlier warm/cold color-latency measurements in
`GUIDE-FIRST-PAINT-0.3.91.md` are historical evidence from before this
removal, not current UI behavior. This local candidate is neither signed nor
uploaded for Dashboard analysis.
