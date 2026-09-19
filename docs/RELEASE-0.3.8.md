# AerioTV Roku v0.3.8 — public testing preview

An independent BrightScript/SceneGraph Roku port of AerioTV, focused on
**Dispatcharr live TV and the programme guide**. This is a **prerelease for
testing**, not a Roku Streaming Store app or full Apple TV/Android TV parity.

## Download and install

Download **aeriotv-roku-v0.3.8.zip** from this release's Assets. Keep it zipped.
Do not use GitHub's automatic **Source code (zip)** as the install package.

1. From Roku Home, press **Home ×3, Up ×2, Right, Left, Right, Left, Right**.
2. Enable the Development Application Installer, accept Roku's developer license,
   choose a developer password, and let the Roku restart.
3. From a computer on the same network, open **`http://<your Roku IP>`**.
   Replace `<your Roku IP>` with the address shown by your Roku—for example,
   **`http://192.168.1.50`**. You can find it under **Settings → Network → About**.
4. Sign in as **rokudev**, using the developer password you chose.
5. Upload **aeriotv-roku-v0.3.8.zip** and choose **Install / Install with zip**.
6. In AerioTV, enter the reachable Dispatcharr base URL and your Dispatcharr
   dashboard credentials or API key. Select **Connect**.

Only one development app can be sideloaded; installing this replaces the existing
development-slot app. No Node.js/compiler is needed to install the provided ZIP.

[Full installation guide, troubleshooting and platform comparison](https://github.com/EndofLineTech/AerioTV-Roku/blob/dev/README.md)

## Included

- Live TV guide with search, favorites, group layouts/order, collections, artwork,
  programme details, foreground reminders and selectable clock formats.
- Mini-player, Channels/Recent overlays, last-channel toggle, sleep timer,
  foreground Hide picture, video scaling and stream information.
- Bounded logo caching and translucent browser presentation.
- Existing-server AAC compatibility with strict profile discovery, plus one
  bounded local retry for startup buffering stalls.
- Authorized Dispatcharr source switching and local frozen-picture recovery.
- AerioTV's upstream Apple TV icon adapted for Roku launcher/splash artwork.

## Known limitations

- **Fullscreen star is unresolved on the tested Stick.** Open app options with
  **OK → Up (or Down) → Options**, using Left/Right to select Options, then OK.
  The opt-in fullscreen-star diagnostic is included; it temporarily changes
  picture size, and Back exits/restores the normal layout.
- The original intermittent startup-stall report remains under acceptance testing.
  Recovery is bounded, not a guarantee that every provider stream will play.
- Held fullscreen channel-release behavior still has a pending physical check.
- AAC compatibility requires an existing active copy-video/AAC output profile
  visible to the account. This app does not create server profiles.
- Source switching affects all viewers of that shared Dispatcharr channel.
- No direct Xtream/M3U setup, VOD, DVR, multiview, cloud sync, or guaranteed live
  rewind/catch-up in this Roku preview. Hide picture is foreground-only.

Tested only using the **Roku Streaming Stick 4K 3820RW2 / OS 15.3.4 / 1080p**,
with **Dispatcharr 0.31.0**. Other models may work but have not been verified.

## Verification and source

23 automated suites and compiler/package checks pass. Previous playback fixes
have recorded native-device evidence; new launcher assets are checked against
Roku's documented dimensions and the packaged manifest. Automated tests do not
replace physical remote/media acceptance.

**SHA256SUMS** accompanies the installable ZIP. For example, on macOS:

```sh
shasum -a 256 -c SHA256SUMS
```

Keep both downloaded files in the same directory when checking the checksum.
Corresponding source, build instructions, upstream artwork and GPL-3.0-or-later
license/attribution are available at this release's **v0.3.8** tag. This preview
is independently maintained, not an official upstream AerioTV release.
