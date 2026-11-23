sub main()
    m.groups = [{id: "all"}]
    m.groupIndex = 0
    m.serverGroups = []
    m.collections = []
    m.channels = []
    m.settings = normalizeGuideSettings(invalid)
    m.fixtureWrites = 0
    rebuildGuideGroups(false)
    check(m.fixtureWrites = 0, "internal lineup rebinding does not publish a synthetic user preference edit")
    rebuildGuideGroups()
    check(m.fixtureWrites = 1, "explicit guide edits still persist through ordinary rebuilds")
    m.ready = true
    m.top = {active: true}
    m.details = {active: false}
    m.selected = 4
    m.anchor = 1800
    m.viewStart = 600
    applied = applyHubGuideSetting("roundedGuideLogos", true)
    check(applied.roundedGuideLogos and not applied.roundedProgramCells, "appearance-only switch only updates the requested corner setting")
    applied = applyHubGuideSetting("channelLogoSize", 150)
    check(applied.channelLogoSize = 150 and applied.roundedGuideLogos, "settings can change size without resetting logo corners")
    check(m.selected = 4 and m.anchor = 1800 and m.viewStart = 600, "appearance changes do not move channel or time focus")
    check(m.fixtureWrites = 1, "Settings Hub owns this transaction; no asynchronous duplicate save")
    check(m.fixtureDraws = 4, "appearance-only settings refresh the guide in place")
    m.channels = [{id: "11", uuid: "u-a", name: "A"}, {id: "12", uuid: "u-b", name: "B"}]
    m.savedFavoriteIds = ["11"]
    m.favorites = guideFavoriteSelection(m.savedFavoriteIds, m.channels)
    m.userSessionId = "session-a"
    m.providerType = "dispatcharr"
    lineup = syncFavoritesLineup()
    check(lineup.aeriosession = "session-a" and lineup.channels.count() = 2 and lineup.channels[1].id = "12" and lineup.channels[1].uuid = "u-b" and lineup.channels[0].doesExist("name") = false, "Sync sees only this session's lineup ids and UUIDs")
    m.providerType = "xtream"
    check(syncFavoritesLineup().channels.count() = 0, "non-Dispatcharr lineups never translate Sync favorites")
    m.providerType = "dispatcharr"
    writes = m.fixtureWrites
    draws = m.fixtureDraws
    check(not applySyncedFavorites({favoriteIds: ["12"], aeriosession: "session-b"}) and m.savedFavoriteIds[0] = "11", "a pull for another session cannot change this Guide")
    check(applySyncedFavorites({favoriteIds: ["12", "500"], aeriosession: "session-a"}), "a current pull is applied to the Guide")
    check(FormatJson(m.savedFavoriteIds) = "[""12"",""500""]" and m.favorites.doesExist("u-b") and not m.favorites.doesExist("u-a"), "favorites group and FAV badges follow the applied list, keeping off-lineup ids")
    check(m.fixtureWrites = writes and m.fixtureDraws = draws + 1, "applied Sync favorites redraw without publishing a new local edit")
    print "ALL TESTS PASSED"
end sub

sub filterLineup()
end sub

sub savePreferences()
    m.fixtureWrites++
end sub

sub drawGuide()
    if m.fixtureDraws = invalid then m.fixtureDraws = 0
    m.fixtureDraws++
end sub

sub updateRichDetails()
end sub

sub scheduleLoad()
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
