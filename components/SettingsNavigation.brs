sub refreshSettingsHub()
    m.settingsHub.model = {account: m.accountIdentity, device: m.devicePreferences, guide: m.accountPreferences.guide, vodEnabled: m.accountPreferences.vodEnabled <> false, vodTmdbEnabled: m.accountPreferences.vodTmdbEnabled = true, movies: m.capabilities.movies, series: m.capabilities.series, catchup: m.capabilities.catchup}
end sub

sub openSettingsHub()
    if m.page <> "guide" then return
    m.guide.active = false
    m.page = "settings"
    refreshSettingsHub()
    m.settingsHub.active = true
end sub

sub closeSettingsHub()
    m.settingsHub.active = false
    if m.page <> "settings" then return
    m.page = "guide"
    m.guide.visible = true
    m.guide.active = true
end sub

sub onSettingsHubSelection(event as object)
    if not m.settingsHub.isSameNode(event.getRoSGNode()) or m.page <> "settings" then return
    item = event.getData()
    if item.account <> m.accountIdentity then return
    if item.action = "connection"
        closeSettingsHub()
        showConnection()
        return
    end if
    allowed = settingsHubChangeAllowed(m.settingsHub.model, item.scope, item.key, item.value)
    if not allowed then return
    if item.scope = "device"
        m.devicePreferences[lcase(item.key)] = item.value
        m.devicePreferences = normalizeDevicePreferences(m.devicePreferences)
        persistPreferences()
        if item.key = "clockFormat" then applyClockFormat()
        if item.key = "videoScale" and m.playingChannel <> invalid then applyVideoLayout()
    else if item.scope = "guide"
        settings = m.guide.callFunc("applyHubGuideSetting", item.key, item.value)
        if settings <> invalid then m.accountPreferences.guide = settings
        persistAccountPreferences()
    else if item.scope = "account"
        m.accountPreferences[lcase(item.key)] = item.value
        persistAccountPreferences()
        updateLibraryPermissions()
    end if
    refreshSettingsHub()
end sub
