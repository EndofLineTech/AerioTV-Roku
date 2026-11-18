# AerioTV for Roku v0.3.102 — development prerelease

Download **`aeriotv-roku-v0.3.102.zip`** from this release's **Assets** to install
through Roku Developer Mode. Keep it zipped. GitHub's generated **Source code
(zip)** is the repository, **not** the installable Roku application.

## Install the development ZIP

1. Enable Developer Mode using Roku's
   [official setup instructions](https://developer.roku.com/docs/developer-program/getting-started/developer-setup.md).
2. From a computer on the Roku's local network, open `http://<Roku IP>` in a
   browser. Sign in as `rokudev` using the developer password you set on the Roku.
3. Upload **`aeriotv-roku-v0.3.102.zip`**, then choose **Install**.
4. After **Install Success**, AerioTV launches on the TV. Connect to a Dispatcharr
   server reachable by the Roku, or use the supported phone-setup flow.

**Roku has one sideloaded development-app slot. Installing this ZIP replaces
whatever development app is already in that slot.** No compiler, npm or signing
credentials are needed. Do not share your developer password or provider keys.

Verify the ZIP using the attached **`aeriotv-roku-v0.3.102.zip.sha256`**:

```sh
shasum -a 256 -c aeriotv-roku-v0.3.102.zip.sha256
```

ZIP SHA-256:
`68ad35da6a076259aacf413be181dcce64af3db08d790d5d6d0d5af08f5ffaab`

## Profiles, phone setup and Sync

- Multiple Dispatcharr profiles with their own sign-ins, permissions, favorites,
  appearance and supported player preferences.
- Profile picker, quick switching, avatars, reordering and optional “Who is
  watching?” at launch.
- Existing/imported numeric and Directions PINs, protected adult management,
  Child restrictions and native PIN entry, including supported voice input.
- Direct encrypted phone setup now works in the normal build. Scan the Roku QR
  using a compatible AerioTV phone app and send a playlist and selected profiles.
- Fresh imports preserve valid sender profile IDs without changing an existing
  Roku default-profile ID; an empty optional proof no longer prevents fresh
  account verification.
- Opt-in Profiles-only Dispatcharr Sync. Receiving a phone payload never turns
  Sync on. Switching, cancellation, credential recovery and address-change
  protections remain in place.

## UI/UX and guide improvements included

- Better-centered labels, balanced navigation/icon spacing and consistent pill
  controls across navigation, browser groups, search and compact library selectors.
- Fixed pill seams/cap artifacts and oversized confirmation dialogs.
- More readable large-text tabs; bounded category/provider/source labels and
  headings that avoid collisions.
- Correct light-mode/appearance updates for backgrounds, guide subtitles, DVR
  colors/captions and channel-browser surfaces.
- Clear stale programme details when entering empty channel groups, and show
  consistent search-footer remote hints.
- Detail-first EPG mapping for smaller lineups and larger bounded logo/metadata
  caches.

These cumulative changes include work from earlier development builds; they
were not all first implemented in v0.3.102.

## Verification and limitations

The exact 380-file ZIP passed release preparation and matches all shipping-file
bytes exercised in four native Apple/Android encoder flows (adult and Child
variants) against approved **live Dispatcharr** accounts. Native checks cover
real encrypted receipt, wrong-code/replay refusal, own-account/UUID/key/PIN
preservation, default/Child PIN gates and explicit Sync decline. The UI audit
inspected 409 captures in isolated production renderers.

These checks do **not** establish physical phone UI or same-network Bonjour
discovery acceptance. Multicast discovery does not traverse the test VPN.
Physical Android testing remains a Beta-user check.

Existing/imported PINs are supported; creating new PINs or Device Admin PINs is
not included. Only Profiles Sync is supported. Some affected-account guide/logo,
reliability and Roku cloud/certification findings remain open. The device-key
material source has functional native qualification, not a claimed
vendor-documented CSPRNG guarantee.

This is a **development prerelease**, not a Roku Store submission or certification
claim. Current native qualification uses a Streaming Stick 4K; other models and
firmware are not universally qualified. See the
[detailed Beta notes](https://github.com/EndofLineTech/AerioTV-Roku/blob/dev/docs/BETA-CANDIDATE-0.3.102.md)
for evidence boundaries and known issues.

## Other ways to follow or test

- [Repository](https://github.com/EndofLineTech/AerioTV-Roku)
- **Beta channel code:** `GQMQGQL` —
  [join the Beta](https://my.roku.com/account/add/GQMQGQL).
- [Full sideloading guide](https://github.com/EndofLineTech/AerioTV-Roku#install-on-your-roku)

The signed Beta package and Developer Mode ZIP are different installation
formats. This development release provides the ZIP for self-installation; it
does not upload or submit the signed package to Roku.
