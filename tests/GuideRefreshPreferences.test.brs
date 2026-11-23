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
    ' e3e.34: holding OK on a group pill confirms, then saves the default group.
    m.groups = [{id: "all", name: "All channels"}, {id: "news", name: "News"}]
    m.settings.hiddenGroups = ["news"]
    m.navigator = {active: false, focused: false, setFocus: sub(value as boolean)
        m.focused = value
    end sub}
    prompt = groupDefaultPrompt("news")
    check(prompt.title = "Default group" and instr(1, prompt.message, "News") > 0 and prompt.buttons[0] = "Set as default" and prompt.buttons[1] = "Cancel", "confirmation names the held group")
    check(groupDefaultPrompt("missing") = invalid, "an unknown group cannot be confirmed")
    writes = m.fixtureWrites
    finishGroupDefault("news", false)
    check(m.settings.startupGroup = "all" and m.fixtureWrites = writes and m.navigator.active, "Cancel leaves the default and returns to the groups")
    m.navigator.active = false
    finishGroupDefault("news", true)
    check(m.settings.startupGroup = "news" and m.settings.hiddenGroups.count() = 0 and m.fixtureWrites = writes + 1, "confirmed group becomes the visible default and is saved")
    check(m.navigator.active, "focus returns to the groups after confirming")
    finishGroupDefault("news", false)
    check(m.navigator.focused, "an already active navigator takes focus back explicitly")
    m.navigator.callFunc = function(name as string, model as object) as dynamic
        m.presented = model
        return invalid
    end function
    m.groupIndex = 0
    applied = applyHubGuideSetting("sidebarLayout", "overlay")
    check(applied <> invalid and applied.sidebarLayout = "overlay" and m.navigator.presented.overlay = true, "Settings can switch the sidebar to overlay")
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

sub keepAnchorVisible()
end sub
