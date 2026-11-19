# Movies & TV Shows display scale

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

The same pin exposes a [Guide control][guide-settings] with steps 85%, 92%,
100%, 115%, 125%, and 150%, but its [tvOS Guide][guide-render] uses fixed
channel-column width and pixels per hour, with row and header size driven by
global text scaling. The local Guide scale is read by the non-tvOS grid, where
it scales geometry and cell text together. The Roku Guide control is not
included pending a decision on whether it should scale the TV grid or only
the text within that grid. The pinned [Sync schema][sync] lists a Guide scale
on the shared Live TV axis; no new field was added to the Roku Sync mapping.

## Native acceptance still needed

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
