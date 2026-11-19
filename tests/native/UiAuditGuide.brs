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
    appearanceCase = left(scenario, 17) = "guide-appearance-"
    if appearanceCase
        prefs.guide.channelLogoSize = 250
        prefs.guide.roundedGuideLogos = scenario <> "guide-appearance-cells"
        prefs.guide.roundedProgramCells = scenario <> "guide-appearance-logos"
        if scenario = "guide-appearance-logos" then prefs.guide.channelLogoSize = 25
        if scenario = "guide-appearance-cells" then prefs.guide.showSubtitles = false
        if scenario = "guide-appearance-oled" then prefs.guide.guideDensity = "basic"
    end if
    channels = uiAuditChannels()
    if scenario = "guide-empty" then channels = []
    ' The gallery's pkg:/ URI is not a downloaded cache file. Drop fixture
    ' references before reconfiguration so they never enter the cleanup task.
    m.guideLogoFiles = {}
    if appearanceCase
        for each channel in channels
            channel.logoId = channel.id
        end for
    end if
    m.top.config = {channels: channels, groups: uiAuditGroups(), preferences: prefs, scope: "ui-audit", generation: "synthetic", baseUrl: "", apiKey: "", providerType: "xtream", guideUrl: "", tmdbKey: "", warning: ""}
    m.top.moviesPermission = "allowed"
    m.top.seriesPermission = "allowed"
    m.top.dvrPermission = "manage"
    index = guideDictionary()
    now = uiNow()
    for each channel in channels
        index[channel.epgKey] = uiAuditPrograms(channel, now)
        if appearanceCase then m.guideLogoFiles[channel.logoId] = {uri: "pkg:/images/channel-icon-hd.png", bytes: 0}
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
    state = {selected: m.selected, rowStart: m.rowStart, count: m.filtered.count(), primary: m.primaryNavigation.active, groups: m.navigator.active, details: m.details.active, picker: "", titles: [], focused: -1, subtitle: m.subtitle.text, subtitleVisible: m.subtitle.visible, descriptionY: m.description.translation[1]}
    if m.picker <> invalid
        state.picker = m.pickerKind
        state.focused = m.pickerList.itemFocused
        for each item in m.pickerItems
            state.titles.push(item.title)
        end for
    end if
    if m.settings <> invalid
        state.appearance = {logoSize: m.settings.channelLogoSize, roundedLogos: m.settings.roundedGuideLogos, roundedCells: m.settings.roundedProgramCells, trueBlack: uiResolvedPalette(uiAppearance()).trueBlack}
    end if
    return state
end function
