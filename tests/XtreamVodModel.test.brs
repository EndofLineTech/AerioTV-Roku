sub main()
    base = "https://example.test"
    assertEqual(xtreamVodApiUrl(base, "viewer", "test-only", "get_vod_streams", "7"), base + "/player_api.php?username=viewer&password=test-only&action=get_vod_streams&category_id=7", "category-scoped request")
    assertEqual(xtreamVodApiUrl(base, "viewer", "test-only", "get_vod_streams", "7&password=oops"), "", "invalid category rejected")
    assertEqual(xtreamVodApiUrl(base, "viewer", "test-only", "get_vod_streams"), "", "whole catalog forbidden")
    assertEqual(xtreamVodApiUrl(base, "viewer", "test-only", "get_series_info", "14"), base + "/player_api.php?username=viewer&password=test-only&action=get_series_info&series_id=14", "series detail request")
    categories = xtreamVodCategories([{category_id: 7, category_name: "Drama"}, {category_id: 8, category_name: "Comedy"}], 1)
    assertEqual(categories.ok, true, "category list")
    assertEqual(categories.items[0].value, "7", "category identifier preserved")
    assertEqual(xtreamVodCategories(invalid, 1).ok, false, "failed list is not empty list")
    assertEqual(xtreamVodCategories([], 1).ok, true, "empty list")
    rows = []
    for i = 1 to 24
        rows.push({stream_id: i, name: "Movie " + i.toStr(), container_extension: "mp4", stream_icon: "https://other.test/secret", category_id: "7"})
    end for
    page = xtreamVodPage(rows, "movie", 2, "", "7", "xc-slot")
    assertEqual(page.ok, true, "second page normalized")
    assertEqual(page.items.count(), 4, "20 items per page")
    assertEqual(page.items[0].id, "21", "stable movie ID")
    assertEqual(page.items[0].uuid, "xc-movie-21", "Xtream identity")
    assertEqual(page.items[0].streamFormat, "mp4", "container format")
    assertEqual(instr(1, FormatJson(page), "other.test"), 0, "remote artwork excluded")
    assertEqual(xtreamVodPage(rows, "movie", 1, "Movie 22", "7", "xc-slot").items.count(), 1, "local category search")
    assertEqual(xtreamVodPage(rows, "movie", 1, "", "8", "xc-slot").items.count(), 0, "category mismatch")
    assertEqual(xtreamVodPage([{stream_id: "../21", name: "Bad"}], "movie", 1, "", "7", "xc-slot").ok, false, "invalid IDs fail closed")
    detail = xtreamVodDetail({info: {name: "Movie", plot: "Synopsis", genre: "Drama", duration_secs: 3900}, movie_data: {stream_id: 21, container_extension: "mp4"}}, "movie", "21", "xc-slot")
    assertEqual(detail.id, "21", "detail matches requested movie")
    assertEqual(detail.description, "Synopsis", "provider synopsis")
    assertEqual(detail.duration, 3900, "duration normalized")
    assertEqual(xtreamVodDetail({movie_data: {stream_id: 22}}, "movie", "21", "xc-slot"), invalid, "mismatched detail rejected")
    series = xtreamVodDetail({info: {name: "Series", series_id: 14, plot: "Series plot"}}, "series", "14", "xc-slot")
    assertEqual(series.kind, "series", "series metadata")
    episodes = xtreamVodEpisodes({episodes: {"1": [{id: 34, title: "Pilot", episode_num: 1, container_extension: "mkv", info: {plot: "Pilot plot", duration_secs: 2700}}]}}, "14", 1, "xc-slot")
    assertEqual(episodes.ok, true, "series episodes")
    assertEqual(episodes.items[0].seriesId, "14", "series relation")
    assertEqual(episodes.items[0].season, "1", "season number")
    assertEqual(episodes.items[0].description, "Pilot plot", "episode plot")
    assertEqual(episodes.items[0].streamFormat, "mkv", "episode container")
    assertEqual(xtreamVodEpisodes({episodes: {"0": [{id: 35, title: "Special", episode_num: 1, info: {overview: "Special synopsis"}}]}}, "14", 1, "xc-slot").items[0].description, "Special synopsis", "season zero and upstream episode overview")
    assertEqual(xtreamVodEpisodes({episodes: {"1": []}}, "14", 1, "xc-slot").ok, true, "no episodes")
    assertEqual(xtreamVodEpisodes({episodes: []}, "14", 1, "xc-slot").ok, false, "unexpected episode shape")
    assertEqual(xtreamVodStreamUrl(base, "viewer", "test-only", episodes.items[0]), base + "/series/viewer/test-only/34.mkv", "episode playback URL")
    assertEqual(xtreamVodStreamUrl(base, "viewer", "test-only", page.items[0]), base + "/movie/viewer/test-only/21.mp4", "movie playback URL")
    assertEqual(xtreamVodStreamUrl(base, "viewer", "test-only", {kind: "movie", id: "21", streamFormat: "unknown"}), "", "unknown container refused")
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
