# Guide and Movies & TV Shows display scales

In **Settings → Live TV**, use **Guide display scale** next to **Guide
density**. Choose 90%, 100%, 110%, or 120%. The scale changes row heights and
the size of text, artwork, and badges inside the guide grid; it does not
change the time axis, navigation, or density mode. The number of whole rows
that fit changes with scale. At 100%, Basic shows ten 64 px rows, Preview with
subtitles off shows seven 96 px rows, and taller Preview shows six 112 px rows.

The Guide choice is saved with the current account's Guide preferences on
this Roku. It combines with global text and secondary text size within the
available row space. It does not change the Movies & TV Shows scale, player
text, or other clients' settings.

In a development build containing `AerioTV-Roku-n8ie`'s Movies/Series change,
open **Settings → Movies & TV Shows → Movies & TV Shows display scale**.
Choose 85%, 100%, 115%, 125%, 135%, or 150%. The category is available where
the active account has a Movies or TV Shows library and can edit its settings.

100% keeps the existing library layout, including any changes from global
**Text size** and **Secondary text size**. Other values multiply those global
settings for library headings, status, and catalog tiles. The D-pad grid
keeps its column and page counts; larger text can reduce the poster footprint
to give titles and captions room. The change takes effect without restarting.
It is saved on this Roku, does not change Guide density or player text, and
does not sync to other clients. Details screens and shared navigation controls
continue to use the global appearance settings.

## Upstream evidence and Guide decision

The pinned Apple [Movies & TV Shows settings][vod-settings] expose these
steps, and the [VOD modifier][vod-render] multiplies the inherited text scale
on TV without changing its poster-grid column count. Roku retains its existing
large-text approach of making room inside the tile when needed.

The pinned Apple [Guide control][guide-settings] has steps 85%, 92%, 100%,
115%, 125%, and 150%, but its [tvOS Guide][guide-render] uses fixed
channel-column width and pixels per hour, with row and header size driven by
global text scaling. The non-tvOS grid scales geometry and cell text
together. Roku scales its vertical grid and cell text using the existing
Appearance percentages; the independent Movies & TV Shows control keeps
the Apple VOD steps. The pinned [Sync schema][sync] lists a Guide scale on
the shared Live TV axis; no new field was added to the Roku Sync mapping.

## Native acceptance still needed

With a fixture lineup, change Guide scale in Basic and both Preview modes.
Check 90% and 120% at the first and last channels with both global text sizes
at 120%. Verify the current channel/program stays selected, FF/Rew moves by
one visible page, the Now marker and program cells stay aligned, and long
titles, subtitles, channel names, badges, and logos stay within their rows.
Check that the 11th Basic logo can load at 90%. Return to 100% and verify all
three stock row layouts; then relaunch at a nondefault setting and confirm the
Guide and Movies & TV Shows scales can be changed independently.

On a Roku with test library data, compare Movies and TV Shows at 100% with
the unmodified build. Then select 85% and 150%, including with both global
text sizes at 120%. Move D-pad focus through both visible rows, to the last
tile, and back; verify the focused border, wrapped titles, and captions stay
visible without overlap. Also check text-only category/source cards, shelves,
and a long title. Return to 100%, and verify the default layout returns.
Relaunch with a nondefault choice to confirm persistence, and verify the Guide
and global appearance settings were not changed.

[vod-settings]: https://github.com/jonzey231/AerioTV/blob/fe7ad4c1968a193efb7a55d68b2b3bd32d03b17a/Features/Settings/MoviesTVSettingsView.swift#L326-L348
[vod-render]: https://github.com/jonzey231/AerioTV/blob/fe7ad4c1968a193efb7a55d68b2b3bd32d03b17a/Features/VOD/MoviesView.swift#L443-L453
[guide-settings]: https://github.com/jonzey231/AerioTV/blob/fe7ad4c1968a193efb7a55d68b2b3bd32d03b17a/Features/Settings/LiveTVSettingsView.swift#L789-L791
[guide-render]: https://github.com/jonzey231/AerioTV/blob/fe7ad4c1968a193efb7a55d68b2b3bd32d03b17a/Features/LiveTV/EPGGuideView.swift#L5757-L5799
[sync]: https://github.com/jonzey231/AerioTV/blob/fe7ad4c1968a193efb7a55d68b2b3bd32d03b17a/docs/DispatcharrSyncSchema.md#L287
