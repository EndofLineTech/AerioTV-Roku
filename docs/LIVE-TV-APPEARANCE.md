# Live TV appearance verification

The guide and player Channels/Recently Watched lists share the selected Logo
Size (10% keeps the stock dimensions). Roku keeps the Guide's Basic and two
Preview row pools and the player's eight-row list; large choices use the
available room rather than adding rows or increasing logo decode dimensions.
Rounded guide logos and program cells reuse the four packaged corner images;
they do not create a second channel texture or an offscreen mask. The shared
dark palette uses opaque `#000000` for page backgrounds and `#0A0A0A` for
cards, preserving focus and theme accent colors. The Roku system UI and video
picture are unchanged.

Host checks cover stored preferences, profile isolation, layout bounds,
palette and focus colors, and sync [mapping metadata](DISPATCHARR-SYNC-MAPPING.md#settings-lanes).
Live cross-client application still requires an enabled settings adapter.

## Native acceptance

Native screenshots and rendered focus checks were not performed. For a later
authorized Roku session, build the isolated UI gallery from the verified ZIP
with `python3 scripts/build-ui-audit-probe.py --output out/e3e19-appearance-probe.zip`.
Use the gallery runner with its required verified restore ZIP and the cases
`guide-appearance-logos`, `guide-appearance-cells`,
`large-guide-appearance-oled`, `light-guide-appearance-oled`, and
`live-browser-appearance`. The gallery uses bundled logos and synthetic
programs, and its focus checks do not submit settings or start media.

Review the captures for logo-only and cell-only rounding, long labels and
focus after scrolling, pure black in Dark mode with visible controls, and
unchanged Light mode. On an authorized app install, also verify persistence
across restart/profile switch and compare repeated scrolls against the stock
logo size on a supported device; host tests do not measure native textures.
