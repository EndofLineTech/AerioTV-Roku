sub main()
    testVodDisplayScaleGeometry()
    for focused = 0 to 19
        shown = 0
        for i = 0 to 19
            position = vodVisualTile(i, focused, 20, false)
            if position.visible
                shown++
                if position.x < 96 or position.x + 336 > 1824 or position.y < 200 or position.y + 380 > 980 then stop
            end if
        end for
        if shown <> 10 or not vodVisualTile(focused, focused, 20, false).visible then stop
    end for
    if not vodVisualTile(0, 0, 1, false).visible then stop
    if vodVisualTile(1, 0, 1, false).visible then stop
    if not vodVisualTile(19, 0, 20, true).visible then stop
    for focused = 0 to 19
        for each statusExtra in [0, 60]
            if not vodVisualTile(focused, focused, 20, false, 150, statusExtra).visible then stop
            for i = 0 to 19
                scaled = vodVisualTile(i, focused, 20, false, 150, statusExtra)
                if scaled.visible and (scaled.y < 278 + statusExtra or scaled.y + vodCatalogTileHeight(150, statusExtra) > 970) then stop
            end for
        end for
    end for
    art = vodNormalize({id: 42, uuid: "episode", name: "Episode", series: {id: 1, name: "Series", logo: {id: 5}}}, "episode")
    if art.seriesTitle <> "Series" or art.seriesLogoId <> "5" then stop
    if vodArtworkUrl("https://host.test", art) <> "https://host.test/api/vod/episodes/42/image/?kind=movie_image" then stop
    raw = {id: 2, uuid: "safe-uuid", name: "Movie", duration_secs: 3600, direct_source: "secret", logo: {id: 8, url: "secret"}}
    item = vodNormalize(raw, "movie")
    if item.key <> "movie:safe-uuid" or item.logoId <> "8" then stop
    if item.doesExist("direct_source") or item.doesExist("logo") then stop
    if vodNormalize({id: 2, uuid: "../bad"}, "movie") <> invalid then stop
    page = vodPage({count: 120000, next: "/api/vod/movies/?page=2", results: [raw]}, "movie", "https://host.test")
    if not page.ok or page.items.count() <> 1 then stop
    if vodPage({count: 1, results: [raw], next: "https://evil.test/"}, "movie", "https://host.test").ok then stop
    if vodPage({count: 2, results: [raw, raw]}, "movie", "https://host.test", 1).ok then stop
    if not vodPage({count: 0, results: []}, "movie", "https://host.test").ok then stop
    if vodPlaybackUrl("https://host.test", item, "roku_session") <> "https://host.test/proxy/vod/movie/safe-uuid/roku_session" then stop
    categories = []
    for i = 1 to 25
        categories.push({id: i, name: "Category " + i.toStr(), m3u_accounts: [{password: "private"}]})
    end for
    page = vodCategoryPage(categories, 2, "https://host.test")
    if not page.ok or page.items.count() <> 5 or page.total <> 25 or page.next <> "" then stop
    if instr(1, FormatJson(page), "private") > 0 then stop
    providers = vodEnabledProviders([
        {id: 1, is_active: true, enable_vod: true, password: "private"}
        {id: 2, is_active: true, enable_vod: false}
        {id: 3, is_active: false, enable_vod: true}
        {id: 4, is_active: true}
        {id: 5, is_active: true, enable_vod: false}
    ])
    if providers.count() <> 1 or not providers.doesExist("1") then stop
    categories = []
    for i = 1 to 30
        categories.push({id: i, name: "Disabled", category_type: "movie", m3u_accounts: [{m3u_account: 2, enabled: true}]})
    end for
    for i = 31 to 40
        categories.push({id: i, name: "Enabled", category_type: "movie", m3u_accounts: [{m3u_account: 1, enabled: true}, {m3u_account: 1, enabled: true}]})
    end for
    categories.push({id: 41, name: "Disabled category", category_type: "movie", m3u_accounts: [{m3u_account: 1, enabled: false}]})
    categories.push({id: 42, name: "Inactive provider", category_type: "movie", m3u_accounts: [{m3u_account: 3, enabled: true}]})
    categories.push({id: 43, name: "Show", category_type: "series", m3u_accounts: [{m3u_account: 1, enabled: true}]})
    visible = vodEnabledCategories(categories, providers, "movie")
    page = vodCategoryPage(visible, 1, "https://host.test")
    if page.total <> 10 or page.items.count() <> 10 or page.next <> "" then stop
    if vodEnabledCategories(categories, providers, "series").count() <> 1 then stop
    if vodEnabledCategories(categories, providers, "movie", "2").count() <> 0 then stop
    if instr(1, FormatJson(visible), "m3u_account") > 0 then stop
    item.tmdbId = "603"
    item.trailerId = "abcdefghijk"
    if vodExternalLinks(item).count() <> 2 then stop
    item.kind = "episode"
    item.trailerId = ""
    if vodExternalLinks(item).count() <> 0 then stop
    item.seriesTmdbId = "1396"
    item.season = "1"
    item.episode = "2"
    if vodExternalLinks(item)[0] <> "https://www.themoviedb.org/tv/1396/season/1/episode/2" then stop
    versions = vodVersionPage([{id: 9, m3u_account: {id: 19, name: "Provider", username: "private", password: "secret"}}], 1)
    if not versions.ok or versions.items[0].providerId <> "19" then stop
    if instr(1, FormatJson(versions), "secret") > 0 or instr(1, FormatJson(versions), "private") > 0 then stop
    if vodStreamFormat("mpegts") <> "ts" then stop
    sort = vodCatalogSortChoices("-year", "catalog", "movie")
    if sort.count() <> 3 then stop
    if sort[0].value <> "name" or sort[1].value <> "-created_at" or sort[2].value <> "-year" then stop
    if instr(1, sort[2].title, "[Selected]") <> 1 then stop
    if instr(1, sort[0].title, "[Selected]") > 0 then stop
    if vodCatalogSortChoices("name", "watchlist", "movie").count() <> 0 then stop
    if vodCatalogSortChoices("name", "catalog", "episode").count() <> 0 then stop
    if instr(1, vodCatalogSortChoices("invalid", "catalog", "series")[0].title, "[Selected]") <> 1 then stop
    print "ALL TESTS PASSED"
end sub

sub testVodDisplayScaleGeometry()
    stock = vodTextLayout(100, 100, 24, 18)
    if stock.posterHeight <> 288 or stock.posterWidth <> 192 or stock.posterX <> 72 then stop
    if stock.titleY <> 304 or stock.titleHeight <> 52 or stock.factY <> 354 or stock.factHeight <> 26 then stop
    large = vodTextLayout(100, 120, 29, 26)
    if large.posterHeight <> 264 or large.posterWidth <> 176 or large.posterX <> 80 then stop
    if large.titleY <> 282 or large.titleHeight <> 68 or large.factY <> 354 or large.factHeight <> 26 then stop
    a11y = {textSize: 120, subtextSize: 120}
    if uiScaledFontSize(24, 0, false, a11y, 150) <> 43 then stop
    if uiScaledFontSize(18, 0, true, a11y, 150) <> 39 then stop
    if uiScaledFontSize(18, 0, true, a11y, 100) <> 26 then stop
    if uiScaledFontSize(24, 0, false, {}, 85) <> 20 then stop
    if uiScaledFontSize(24, 32, false, a11y, 150) <> 28 then stop
    for each scale in [85, 115, 125, 135, 150]
        for each primary in [90, 100, 110, 120]
            for each secondary in [90, 100, 110, 120]
                prefs = {textSize: primary, subtextSize: secondary}
                title = uiScaledFontSize(24, 0, false, prefs, scale)
                fact = uiScaledFontSize(18, 0, true, prefs, scale)
                layout = vodTextLayout(scale, primary, title, fact)
                if layout.posterHeight + 8 > layout.titleY or layout.posterX * 2 + layout.posterWidth <> 336 then stop
                if layout.titleHeight < 2 * title * 1.12 or layout.factY < layout.titleY + layout.titleHeight then stop
                if layout.factHeight < fact * 1.12 or layout.factY + layout.factHeight > vodCatalogTileHeight(scale) then stop
            end for
        end for
    end for
end sub
