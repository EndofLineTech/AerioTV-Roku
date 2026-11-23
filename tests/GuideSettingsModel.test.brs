sub main()
    testGuideDisplayScale()
    numbered = channelOrderedGroups([{id: "a", name: "Alpha"}, {id: "z", name: "Zulu"}, {id: "e", name: "Empty"}], [{groupId: "a", number: "100"}, {groupId: "z", number: "2.1"}, {groupId: "a", number: "3"}])
    assertEqual(numbered[0].id, "z", "default groups use minimum numeric channel, not name")
    assertEqual(numbered[1].id, "a", "minimum member beats first member")
    assertEqual(numbered[2].id, "e", "empty groups last")
    numbered = channelOrderedGroups([{id: "a", name: "Alpha"}, {id: "z", name: "Zulu"}], [{groupId: "a", number: "N/A"}, {groupId: "z", number: " 02.1 "}])
    assertEqual(numbered[0].id, "z", "invalid channel numbers do not sort ahead of numbered groups")
    numbered = channelOrderedGroups([{id: "z", name: "Zulu"}, {id: "a", name: "Alpha"}], [{groupId: "a", number: "2.10"}, {groupId: "z", number: "2.1"}])
    assertEqual(numbered[0].id, "a", "equal decimal minima use deterministic name tie-break")
    assertEqual(guideHoldStep(0), 1, "single step")
    assertEqual(guideHoldStep(1600), 3, "held guide accelerates")
    assertEqual(guideHoldStep(3200), 7, "long hold pages")
    options = [{title: "Details", action: "details"}, {title: "Groups", action: "groups"}, {title: "Search", action: "search"}, {title: "Manage", action: "manageGroups"}, {title: "Settings", action: "settingsHub"}]
    common = guideOptionItems(options, false)
    advanced = guideOptionItems(options, true)
    assertEqual(common.count(), 4, "common menu stays short with a More entry")
    assertEqual(common[3].action, "moreOptions", "advanced actions are discoverable")
    assertEqual(advanced.count(), 3, "advanced menu retains less common actions and a return route")
    assertEqual(advanced[0].action, "mainOptions", "advanced menu can return")
    settings = normalizeGuideSettings(invalid)
    assertEqual(settings.guideDensity, "preview", "subtitle-rich preview is the default density")
    assertEqual(settings.showSubtitles, true, "subtitle-rich preview defaults on")
    assertEqual(settings.channelLogoSize, 100, "upgraded guide keeps the stock logo size")
    assertEqual(settings.roundedGuideLogos, false, "guide logos default to square")
    assertEqual(settings.roundedProgramCells, false, "program cells default to square")
    assertEqual(normalizeGuideSettings({channelLogoSize: "250"}).channelLogoSize, 100, "reject text in numeric logo size")
    assertEqual(normalizeGuideSettings({channelLogoSize: 999}).channelLogoSize, 100, "reject logo size above the wire range")
    assertEqual(normalizeGuideSettings({channelLogoSize: 122}).channelLogoSize, 100, "snap a valid peer setting to the nearest supported stop")
    for each size in [25, 50, 100, 150, 200, 250]
        for each logosRounded in [true, false]
            for each cellsRounded in [true, false]
                restored = normalizeAccountPreferences(ParseJson(FormatJson({guide: {channelLogoSize: size, roundedGuideLogos: logosRounded, roundedProgramCells: cellsRounded}}))).guide
                assertEqual(restored.channelLogoSize, size, "logo size survives stored account round trip")
                assertEqual(restored.roundedGuideLogos, logosRounded, "logo corners survive independently")
                assertEqual(restored.roundedProgramCells, cellsRounded, "program corners survive independently")
            end for
        end for
    end for
    for each mode in [
        {density: "basic", subtitles: false, logoY: 27, nameX: 54, nameY: 26, nameWidth: 150, nameHeight: 32}
        {density: "preview", subtitles: false, logoY: 37, nameX: 80, nameY: 40, nameWidth: 150, nameHeight: 55}
        {density: "preview", subtitles: true, logoY: 40, nameX: 80, nameY: 40, nameWidth: 150, nameHeight: 62}
    ]
        geometry = guidePresentationGeometry(mode.density, mode.subtitles)
        stock = guideChannelGeometry(geometry, {showLogos: true, showNumbers: true, showNames: true, channelLogoSize: 100})
        assertEqual(stock.logo.x, 12, "default logo keeps its stock x")
        assertEqual(stock.logo.y, mode.logoY, "default logo keeps its stock y except where it crosses the row edge")
        assertEqual(stock.numberX, 12, "default number stays at the stock x")
        assertEqual(stock.numberWidth, 170, "default number keeps its stock width")
        assertEqual(stock.textX, mode.nameX, "default name keeps its stock x")
        assertEqual(stock.nameY, mode.nameY, "default name keeps its stock y")
        assertEqual(stock.nameWidth, mode.nameWidth, "default name keeps its stock width")
        assertEqual(stock.nameHeight, mode.nameHeight, "default name only loses height when it crosses the row edge")
        for each size in [25, 50, 100, 150, 200, 250]
            layout = guideChannelGeometry(geometry, {showLogos: true, showNumbers: true, showNames: true, channelLogoSize: size})
            assertEqual(layout.logo.y >= 0 and layout.logo.y + layout.logo.h <= geometry.tileHeight, true, "logo stays inside all guide row modes")
            assertEqual(layout.logo.x + layout.logo.w < layout.textX, true, "logo cannot overlap the name")
            assertEqual(layout.textX + layout.nameWidth <= 230, true, "even the widest logo retains a text gutter")
            assertEqual(layout.nameY + layout.nameHeight <= geometry.tileHeight, true, "label fits in the tile")
            if size > 100 and layout.logo.y < 31 then assertEqual(layout.logo.x + layout.logo.w < layout.numberX, true, "grown logos clear the number and indicator lane")
            for each scale in [90, 100, 110, 120]
                font = uiScaledFontSize(21, layout.nameHeight / layout.nameLines, false, {textSize: scale})
                assertEqual(font * 1.12 * layout.nameLines <= layout.nameHeight, true, "scaled channel name fits the line box")
            end for
            for each showLogo in [true, false]
                noNumber = guideChannelGeometry(geometry, {showLogos: showLogo, showNumbers: false, showNames: true, channelLogoSize: size})
                assertEqual(noNumber.nameY >= 4 + 27, true, "long names cannot enter the catch-up and FAV lane without numbers")
                assertEqual(noNumber.nameY + noNumber.nameHeight <= geometry.tileHeight, true, "names below the indicator lane still fit")
                font = uiScaledFontSize(21, noNumber.nameHeight / noNumber.nameLines, false, {textSize: 120})
                assertEqual(font * 1.12 * noNumber.nameLines <= noNumber.nameHeight, true, "largest channel name stays inside the reserved row area")
            end for
        end for
        small = guideChannelGeometry(geometry, {showLogos: true, showNumbers: true, showNames: true, channelLogoSize: 25})
        large = guideChannelGeometry(geometry, {showLogos: true, showNumbers: true, showNames: true, channelLogoSize: 250})
        hidden = guideChannelGeometry(geometry, {showLogos: false, showNumbers: true, showNames: true, channelLogoSize: 250})
        assertEqual(small.logo.h < stock.logo.h and stock.logo.h < large.logo.h, true, "all guide modes can shrink and grow from stock")
        assertEqual(hidden.textX, 12, "hidden logos return their column to text")
    end for
    browser = browserChannelGeometry(250, true)
    browserStock = browserChannelGeometry(100, true)
    assertEqual(browserStock.logo.x, 10, "player list keeps the original stock logo x")
    assertEqual(browserStock.logo.y, 14, "player list keeps the original stock logo y")
    assertEqual(browserStock.textX, 105, "player list keeps the original stock text x")
    assertEqual(browser.logo.y + browser.logo.h < 84, true, "browser logo fits the recycled row")
    assertEqual(browser.logo.x + browser.logo.w < browser.textX and browser.textX < 614, true, "browser logo clears text and WATCHING label")
    assertEqual(browserChannelGeometry(250, false).textX, 10, "hidden browser logos return their column to text")
    wide = uiFittedImageBounds({x: 12, y: 6, w: 80, h: 60}, 200, 50)
    assertEqual(wide.y, 26, "round the vertically centered image, not the fit box")
    assertEqual(wide.h, 20, "wide logo preserves aspect")
    tall = uiFittedImageBounds({x: 12, y: 6, w: 80, h: 60}, 50, 100)
    assertEqual(tall.x, 37, "round the horizontally centered image, not the fit box")
    assertEqual(tall.w, 30, "tall logo preserves aspect")
    assertEqual(uiFittedImageBounds(wide, 0, 50), invalid, "unknown bitmap size does not produce a cutout")
    assertEqual(uiCutoutRadius(1, 60), 0, "one-pixel focus target stays square")
    assertEqual(uiCutoutRadius(12, 60), 3, "narrow cells limit radius to a quarter of their width")
    assertEqual(uiCutoutRadius(80, 60), 8, "normal cells use modest rounded corners")
    assertEqual(normalizeGuideSettings({showSubtitles: false}).showSubtitles, false, "subtitle Off survives normalization")
    parsed = {}
    parsed.setModeCaseSensitive()
    parsed["grouplayout"] = "modal"
    parsed["groupLayout"] = "pills"
    assertEqual(normalizeGuideSettings(parsed).groupLayout, "pills", "migrate case-sensitive dynamic layout selection")
    ' e3e.34: the sidebar shifts the grid by default and can overlay it instead.
    assertEqual(normalizeGuideSettings(invalid).sidebarLayout, "shift", "sidebar keeps shifting the grid by default")
    assertEqual(normalizeGuideSettings({sidebarLayout: "overlay"}).sidebarLayout, "overlay", "overlay choice persists")
    assertEqual(normalizeGuideSettings({sidebarlayout: "overlay"}).sidebarLayout, "overlay", "lowercased alias persists")
    assertEqual(normalizeGuideSettings({sidebarLayout: "float"}).sidebarLayout, "shift", "unknown sidebar style falls back")
    overlayParsed = ParseJson("{}")
    overlayParsed["sidebarLayout"] = "overlay"
    assertEqual(normalizeGuideSettings(overlayParsed).sidebarLayout, "overlay", "case-sensitive map keeps the overlay choice")
    assertEqual(guideGridX({groupLayout: "sidebar", sidebarLayout: "shift"}), 400, "shifted sidebar moves the grid")
    assertEqual(guideGridX({groupLayout: "sidebar", sidebarLayout: "overlay"}), 96, "overlay sidebar keeps the full-width grid")
    assertEqual(guideGridX({groupLayout: "pills", sidebarLayout: "shift"}), 96, "pills never shift the grid")
    legacyColors = normalizeGuideSettings({categoryColors: true, categoryRules: {news: ["news"]}, palette: {news: "43A047"}, showLogos: false})
    assertEqual(legacyColors.doesExist("categoryColors"), false, "retired category switch removed from saved preferences")
    assertEqual(legacyColors.doesExist("categoryRules"), false, "retired matching rules removed from saved preferences")
    assertEqual(legacyColors.doesExist("palette"), false, "retired category palette removed from saved preferences")
    assertEqual(legacyColors.showLogos, false, "logo preference survives retired color migration")
    basic = guidePresentationGeometry("basic")
    preview = guidePresentationGeometry("preview", settings.showSubtitles)
    compact = guidePresentationGeometry("preview", false)
    assertEqual(basic.rowCount * basic.rowHeight <= 692, true, "basic rows fit above guide footer")
    assertEqual(basic.tileHeight < basic.rowHeight, true, "basic rows do not overlap")
    assertEqual(basic.timeY + basic.timeHeight <= basic.tileHeight, true, "basic time fits tile")
    assertEqual(basic.badgeY + 24 <= basic.tileHeight, true, "basic badges fit tile")
    assertEqual(preview.rowCount, 6, "preview shows six taller rows")
    assertEqual(preview.rowCount * preview.rowHeight, 672, "preview uses the same bounded guide viewport")
    assertEqual(compact.rowCount, 7, "subtitle Off restores seven preview rows")
    assertEqual(compact.rowHeight, 96, "subtitle Off restores original preview height")
    assertEqual(compact.tileHeight, 95, "subtitle Off restores compact tile bounds")
    assertEqual(compact.rowCount * compact.rowHeight, 672, "Off keeps the same guide viewport")
    assertEqual(compact.withSubtitle, invalid, "Off does not reserve an empty subtitle slot")
    assertEqual(compact.badgeY + 24 <= compact.tileHeight, true, "compact pills remain within the tile")
    assertEqual(guidePresentationGeometry("basic", false).rowCount, 10, "Basic stays at ten rows when Off")
    assertEqual(preview.tileHeight < preview.rowHeight, true, "tall preview rows retain a gap")
    assertEqual(basic.withSubtitle, invalid, "basic density does not reserve subtitle space")
    subtitleLayout = preview.withSubtitle
    assertEqual(subtitleLayout.subtitleY + subtitleLayout.subtitleHeight < subtitleLayout.badgeY, true, "subtitle clears flag row")
    assertEqual(subtitleLayout.badgeY + 24 <= preview.tileHeight - 4, true, "subtitle flags stay inside selected inset")
    assertEqual(subtitleLayout.badgeY + 24 <= preview.tileHeight - 10, true, "subtitle flags leave a visible bottom gutter")
    assertEqual(subtitleLayout.timeY + subtitleLayout.timeHeight <= preview.tileHeight - 4, true, "subtitle clock stays inside selected inset")
    server = [{id: "1", name: "Sports"}, {id: "2", name: "News"}]
    settings.hiddenGroups = ["group:1"]
    groups = organizedGroups(server, [], settings)
    assertEqual(groups.count(), 4, "hidden group filtered; recent builtin present")
    settings.hiddenGroups = ["all", "favorites", "recent", "group:1", "group:2"]
    assertEqual(organizedGroups(server, [], settings)[0].id, "all", "all-hidden cannot trap guide")
    settings.groupSort = "manual"
    settings.groupOrder = ["group:2", "deleted", "group:2"]
    settings.hiddenGroups = []
    assertEqual(organizedGroups(server, [], settings)[0].id, "group:2", "manual order reconciles deleted groups")
    channels = [{id: "1", uuid: "a", name: "Zoo", number: "2.1", groupId: "1"}, {id: "2", uuid: "b", name: "Alpha", number: "2.2", groupId: "2"}]
    assertEqual(organizedChannels(channels, "group:1", {}, [], [], settings, "Alpha")[0].uuid, "b", "search across groups")
    assertEqual(organizedChannels(channels, "group:1", {}, [], [], settings, "")[0].uuid, "a", "clear restores group")
    settings.channelSort = "name"
    assertEqual(organizedChannels(channels, "all", {}, [], [], settings, "")[0].uuid, "b", "name sort")
    settings.favoriteOrder = ["b", "gone", "a"]
    assertEqual(organizedChannels(channels, "favorites", {a: true, b: true}, [], [], settings, "")[0].uuid, "b", "manual favorites")
    assertEqual(organizedChannels(channels, "recent", {}, ["a", "b"], [], settings, "")[0].uuid, "a", "recent not resorted")
    collections = normalizeCollections([{id: "c", name: "Mine", channels: ["2", "gone", "1", "1"]}])
    assertEqual(organizedGroups(server, collections, settings)[0].id, "collection:c", "collections first is absolute")
    settings.collectionsPosition = "last"
    allGroups = organizedGroups(server, collections, settings)
    assertEqual(allGroups[allGroups.count() - 1].id, "collection:c", "collections last respects manual group sort")
    assertEqual(organizedChannels(channels, "collection:c", {}, [], collections, settings, "").count(), 2, "collection restricted to current lineup")
    settings.hiddenGroups = ["group:1"]
    assertEqual(organizedChannels(channels, "all", {}, [], collections, settings, "").count(), 1, "hidden group removed from All Channels")
    assertEqual(organizedChannels(channels, "all", {}, [], collections, settings, "Alpha").count(), 1, "search still finds visible groups")
    assertEqual(organizedChannels(channels, "all", {}, [], collections, settings, "Zoo").count(), 0, "search cannot reveal hidden channel")
    assertEqual(organizedChannels(channels, "favorites", {a: true, b: true}, [], collections, settings, "").count(), 1, "hidden group removed from Favorites")
    assertEqual(organizedChannels(channels, "recent", {}, ["a", "b"], collections, settings, "").count(), 1, "hidden group removed from Recently Watched")
    assertEqual(organizedChannels(channels, "collection:c", {}, [], collections, settings, "").count(), 1, "hidden group removed from custom collection")
    restoredSettings = normalizeGuideSettings(ParseJson(FormatJson(settings)))
    assertEqual(organizedChannels(channels, "all", {}, [], collections, restoredSettings, "").count(), 1, "hidden-group filter persists through a registry-shaped reload")
    settings.hiddenGroups = []
    assertEqual(organizedChannels(channels, "all", {}, [], collections, settings, "").count(), 2, "show group restores channels")
    assertEqual(channelNumberIndex(channels, "02.20"), 1, "decimal number equivalence")
    assertEqual(channelNumberIndex(channels, "bad"), -1, "invalid number feedback")
    assertEqual(channelNumberIndex([{number: ""}], "0"), -1, "missing number is not zero")
    assertEqual(channelNumberSortKey("2.10"), channelNumberSortKey("02.1"), "decimal stable numeric identity")
    assertEqual(normalizeGuideSettings({historyDays: "bad"}).historyDays, 3, "malformed depth fallback")
    assertEqual(guideResumeAnchor(1000000, true, 1000000 + 3600, settings), 1000000 + 3600, "return from playback follows current time after an hour")
    assertEqual(guideResumeAnchor(1000000, false, 1000000 + 3600, settings), 1000000, "explicit historical browsing stays anchored")
    now = guideEpoch("2026-09-18T12:00:00Z")
    for days = 1 to 14
        restored = normalizeAccountPreferences(ParseJson(FormatJson({guide: {futureDays: days, historyDays: days}})))
        assertEqual(restored.guide.historyDays, days, "exact history horizon survives a registry-shaped reload")
        assertEqual(restored.guide.futureDays, days, "exact future horizon survives a registry-shaped reload")
        assertEqual(guideTimeClamp(now - 31 * 86400, now, restored.guide), now - days * 86400, "guide navigation clamps to configured history horizon")
        assertEqual(guideTimeClamp(now + 31 * 86400, now, restored.guide), now + days * 86400 - 1, "guide navigation clamps to configured future horizon")
    end for
    assertEqual(normalizeGuideSettings({futureDays: 30}).futureDays, 30, "existing 30-day setting still loads")
    assertEqual(normalizeGuideSettings({futureDays: 0}).futureDays, 7, "wire sentinel is not a persisted zero-day window")
    assertEqual(normalizeGuideSettings({futureDays: 15}).futureDays, 7, "unknown preference retains default")
    settings.historyDays = 30
    assertEqual(guideTimeClamp(now - 31 * 86400, now, settings), now - 30 * 86400, "bounded all-available horizon")
    p = normalizeProgram({id: 1, title: "Test", start_time: now, end_time: now + 600, is_live: "true", is_new: true, season: 2, episode: 3, categories: ["Kids", "Sports"]})
    assertEqual(p.is_live, invalid, "malformed live flag is unknown")
    assertEqual(p.categories[0], "Kids", "program categories remain available for details")
    assertEqual(programBadges(p, settings), "NEW S2E3", "truthful badges and episode")
    enriched = mergeProgramFacts(p, {title: "Enriched", startsAt: now + 60, endsAt: now + 999, key: "wrong"})
    assertEqual(enriched.startsAt, now, "detail metadata cannot move guide focus")
    print "ALL TESTS PASSED"
end sub

sub testGuideDisplayScale()
    assertEqual(normalizeGuideSettings(invalid).guideDisplayScale, 100, "missing scale keeps stock")
    assertEqual(normalizeGuideSettings({guideDisplayScale: "120"}).guideDisplayScale, 100, "reject strings")
    assertEqual(normalizeGuideSettings({guideDisplayScale: 115}).guideDisplayScale, 100, "do not accept VOD-only stops")
    assertEqual(normalizeGuideSettings({guideDisplayScale: 110.9}).guideDisplayScale, 100, "reject fractional values")
    for each mode in [
        {density: "basic", subtitles: true, row: 64, count: 10, viewport: 640}
        {density: "preview", subtitles: false, row: 96, count: 7, viewport: 672}
        {density: "preview", subtitles: true, row: 112, count: 6, viewport: 672}
    ]
        for each scale in [90, 100, 110, 120]
            saved = {guide: {guideDisplayScale: scale, guideDensity: mode.density, showSubtitles: mode.subtitles}}
            settings = normalizeAccountPreferences(ParseJson(FormatJson(saved))).guide
            assertEqual(settings.guideDisplayScale, scale, "account round trip")
            row = guidePresentationGeometry(settings.guideDensity, settings.showSubtitles, settings.guideDisplayScale)
            assertEqual(row.rowHeight, int(mode.row * scale / 100.0 + 0.5), "density-specific row pitch scales")
            assertEqual(row.rowCount, mode.viewport \ row.rowHeight, "whole rows fit in density viewport")
            if scale = 100 then assertEqual(row.rowCount, mode.count, "stock count")
            assertEqual(row.rowCount * row.rowHeight <= mode.viewport and row.tileHeight < row.rowHeight, true, "now line/rows remain above footer")
            assertEqual(row.rowCount <= guideRowPoolSize(), true, "pool covers visible rows")
            channels = []
            for i = 1 to 25
                channels.push({logoId: i.toStr()})
            end for
            logoIds = guideInitialLogoIds(channels, 24, row.rowCount)
            assertEqual(logoIds.count(), row.rowCount, "initial logo batch follows layout count at end of lineup")
            assertEqual(logoIds[logoIds.count() - 1], "25", "initial logo batch includes focused channel")
            for each index in [0, 7, 21, 24]
                first = guideVisibleRowStart(10, index, row.rowCount, 25)
                assertEqual(first <= index and index < first + row.rowCount and first + row.rowCount <= 25, true, "focus stays visible after changing scale")
            end for
            for each textSize in [90, 100, 110, 120]
                for each subtextSize in [90, 100, 110, 120]
                    prefs = {textSize: textSize, subtextSize: subtextSize}
                    for each cell in [row, row.withSubtitle]
                        if cell <> invalid
                            assertEqual(cell.titleY + cell.titleHeight <= cell.timeY, true, "title and metadata lanes do not overlap")
                            assertEqual(cell.badgeY + row.badgeHeight <= row.tileHeight, true, "pill fits row")
                            assertEqual(cell.timeY + cell.timeHeight <= row.tileHeight, true, "clock fits row")
                            if cell.subtitleHeight <> invalid
                                assertEqual(cell.titleY + cell.titleHeight <= cell.subtitleY and cell.subtitleY + cell.subtitleHeight <= cell.timeY, true, "subtitle lane remains separate")
                            end if
                            font = uiScaledFontSize(20, cell.timeHeight, true, prefs, scale)
                            assertEqual(font * 1.12 <= cell.timeHeight, true, "clock fits with both accessibility settings")
                            badgeBox = row.badgeHeight - guideScalePixels(4, scale)
                            badgeFont = uiScaledFontSize(16, badgeBox, false, prefs, scale)
                            assertEqual(badgeFont * 1.12 <= badgeBox, true, "badge type fits its inset box")
                        end if
                    end for
                    for each logoSize in [25, 100, 250]
                        settings.channelLogoSize = logoSize
                        settings.showNumbers = false
                        channel = guideChannelGeometry(row, settings)
                        assertEqual(channel.nameY >= channel.indicatorY + channel.indicatorHeight, true, "name clears indicators")
                        assertEqual(channel.nameY + channel.nameHeight <= row.tileHeight and channel.logo.y + channel.logo.h <= row.tileHeight, true, "channel content fits in tile")
                    end for
                end for
            end for
        end for
    end for
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
