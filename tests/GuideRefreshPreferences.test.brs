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
