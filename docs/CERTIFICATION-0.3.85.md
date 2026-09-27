# Roku Store certification candidate — 0.3.85

This candidate branches from the signed 0.3.84 testing release. It is not a
Store-approved release. The historical 0.3.84 `.pkg` and its signing identity
must be kept for subsequent updates; this candidate uses the same identity.

## Implementation evidence

The manifest now uses the AerioTV title, RSG 1.3, and input-launch support.
The app receives cold and warm input requests and resolves only bounded,
opaque `liveFeed` channel identifiers against the **current authorized lineup**.
Malformed, URL-shaped, unrecognized, or unavailable requests do not start a
stream. Movie, episode, and series direct-to-play are not implemented by this
live-only resolver; no Roku Search content feed or VOD deep-link IDs are claimed.

The 11 legacy keyboard-dialog constructions are replaced by
`StandardKeyboardDialog` with voice-capable text boxes. Credentials keep secure
display and password dictation mode; account-name entry offers email mode.
The app invokes Roku's consent-based ChannelStore `getUserData` for an email in
authenticated manual sign-in flows. Declining the request leaves manual entry
available; the Roku email is not persisted separately and is only sent to a
configured source if submitted as its account name. The public privacy policy
describes this conditional behavior.

The app emits launch/dialog timing beacons, and subscribes to app memory alerts
with an OS memory-level fallback. Memory pressure evicts unused guide windows,
detail metadata, and inactive browser logo caches while retaining the current
and selected guide windows. Neither a synthetic code path nor a static-analysis
warning alone establishes resource behavior on every Roku model.

## Device boundary

The 3820RW2 / Roku OS 15.3 target launched the candidate with the approved
manifest title and rendered the welcome/setup and standard keyboard screens.
The initial Welcome render produced a native `AppLaunchComplete` beacon with
1,641 ms reported; this is one run on the target, not an all-device performance
claim. The app's memory monitor reported a foreground limit on that device.
After issuing a Roku email-sharing request, Back returned to the secure API-key
keyboard; the prompt's displayed content was not retained. A malformed ECP input
request and a malformed cold launch did not exit the app. A one-off 0.3.85
candidate was signed with the existing Store key; its private `.pkg` has SHA-256
`3fb9689aec14486b76c777a95fe350508d9b6abe86f5284e751509792e431a33`.
The first signing key was generated for the prior 0.3.84 Store submission; on
the test device, the existing saved connection did not appear under the newly
keyed development installation.
Connected guide, actual live direct-to-play, voice dictation, and playback have
not been retested with a signed-in account in this candidate.

## External certification evidence

The Developer Dashboard's minimum-firmware setting must be set to 15.1 for RSG
1.3. Its Customer Account Requirement and Roku Partner Payouts warning depends
on the owner confirming the intended free bring-your-own-source classification.
The two “extraneous file” findings supplied no file paths; attribution and
license files remain in the package until the Static Analysis JSON identifies
which entries Roku rejected. A subsequent signed candidate and fresh static
analysis are needed before any of those findings can be marked clear. Beads is
the authoritative record for individual finding status.
