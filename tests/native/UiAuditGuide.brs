' Configure the real GuideView, then seed its real cache. No duplicate renderer.
sub seedUiAuditGuide(scenario as string)
    m.loadDelay.unobserveField("fire")
    m.detailDelay.unobserveField("fire")
    prefs = normalizeAccountPreferences({})
    prefs.guide.groupLayout = "pills"
    prefs.favoriteIds = ["1", "2"]
    prefs.recent = ["audit-1", "audit-2"]
    if scenario = "guide-sidebar" or scenario = "guide-sidebar-focus" then prefs.guide.groupLayout = "sidebar"
    if scenario = "guide-basic" then prefs.guide.guideDensity = "basic"
    channels = uiAuditChannels()
    if scenario = "guide-empty" then channels = []
    m.top.config = {channels: channels, groups: uiAuditGroups(), preferences: prefs, scope: "ui-audit", generation: "synthetic", baseUrl: "", apiKey: "", providerType: "xtream", guideUrl: "", tmdbKey: "", warning: ""}
    m.top.moviesPermission = "allowed"
    m.top.seriesPermission = "allowed"
    m.top.dvrPermission = "manage"
    index = guideDictionary()
    now = uiNow()
    for each channel in channels
        index[channel.epgKey] = uiAuditPrograms(channel, now)
    end for
    if scenario = "guide-gap" then index = guideDictionary()
    startAt = guideWindowStart(now)
    for i = -1 to 1
        guideCachePut(m.cache, startAt + i * 10800, index, now, 3600)
    end for
    m.top.visible = true
    m.top.active = true
    if scenario = "guide-options-real" then openOptions()
    if scenario = "guide-more-real" then openOptions(true)
    if scenario = "guide-layout-choices" then openNavigationLayout()
    if scenario = "guide-settings-real" then openGuideSetting("guideSettings")
    menus = {"guide-manage-groups": "manageGroups", "guide-startup": "startup", "guide-collections": "collections", "guide-favorites": "favoriteOrder", "guide-reminders": "reminders", "guide-badges": "badges", "guide-tmdb": "tmdb"}
    if menus.doesExist(scenario) then openGuideSetting(menus[scenario])
    if scenario = "guide-date" then openDatePicker()
    if scenario = "guide-groups-real" then executeGuideRemoteAction("openGroups")
    if scenario = "guide-sidebar-focus" then executeGuideRemoteAction("openGroups")
    if scenario = "guide-details-real" or scenario = "guide-gap" then showDetails()
end sub

function uiAuditGuideState() as object
    state = {selected: m.selected, rowStart: m.rowStart, count: m.filtered.count(), primary: m.primaryNavigation.active, groups: m.navigator.active, details: m.details.active, picker: "", titles: [], focused: -1}
    if m.picker <> invalid
        state.picker = m.pickerKind
        state.focused = m.pickerList.itemFocused
        for each item in m.pickerItems
            state.titles.push(item.title)
        end for
    end if
    return state
end function
