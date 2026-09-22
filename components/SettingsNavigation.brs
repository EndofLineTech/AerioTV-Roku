sub refreshSettingsHub()
    info = CreateObject("roAppInfo")
    version = info.getValue("major_version") + "." + info.getValue("minor_version") + "." + info.getValue("build_version")
    m.settingsHub.model = {account: m.accountIdentity, version: version, device: m.devicePreferences, guide: m.accountPreferences.guide, vodEnabled: m.accountPreferences.vodEnabled <> false, vodTmdbEnabled: m.accountPreferences.vodTmdbEnabled = true, startupBehavior: m.accountPreferences.startupBehavior, whatsNewVersion: m.accountPreferences.whatsNewVersion, movies: m.capabilities.movies, series: m.capabilities.series, catchup: m.capabilities.catchup}
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
    if item.action = "markWhatsNew"
        m.accountPreferences.whatsNewVersion = textValue(item.value)
        if not persistAccountPreferences() then showNotice("What's New will be shown again because this choice could not be saved.")
        refreshSettingsHub()
        return
    end if
    if item.action = "setRemoteAction"
        persistRemoteMap(setRemoteAction(m.devicePreferences.remoteMap, item.context, item.slot, item.value))
        refreshSettingsHub()
        return
    end if
    if item.action = "resetRemoteMap"
        persistRemoteMap(resetRemoteMap())
        refreshSettingsHub()
        return
    end if
    if item.action = "resetAppearance"
        before = copyJson(m.devicePreferences)
        m.devicePreferences.themePreset = "aerio"
        m.devicePreferences.appearanceMode = "dark"
        m.devicePreferences.customAccent = ""
        m.devicePreferences.panelStyle = "translucent"
        m.devicePreferences.textSize = 100
        m.devicePreferences.subtextSize = 100
        m.devicePreferences.contrastMode = "standard"
        if not persistPreferences()
            m.devicePreferences = before
            m.preferenceStore.device = before
        end if
        applyDevicePreferences()
        refreshSettingsHub()
        return
    end if
    allowed = settingsHubChangeAllowed(m.settingsHub.model, item.scope, item.key, item.value)
    if not allowed then return
    if item.scope = "device"
        before = copyJson(m.devicePreferences)
        m.devicePreferences[lcase(item.key)] = item.value
        m.devicePreferences = normalizeDevicePreferences(m.devicePreferences)
        if not persistPreferences()
            m.devicePreferences = before
            m.preferenceStore.device = before
            applyDevicePreferences()
            refreshSettingsHub()
            return
        end if
        applyDevicePreferences()
        if item.key = "clockFormat" then applyClockFormat()
        if item.key = "videoScale" and m.playingChannel <> invalid then applyVideoLayout()
    else if item.scope = "guide"
        before = copyJson(m.accountPreferences.guide)
        settings = m.guide.callFunc("applyHubGuideSetting", item.key, item.value)
        if settings <> invalid then m.accountPreferences.guide = settings
        if not persistAccountPreferences()
            m.accountPreferences.guide = before
            m.guide.callFunc("applyHubGuideSetting", item.key, before[lcase(item.key)])
            m.preferenceStore.accounts[preferenceScope(m.accountIdentity)] = m.accountPreferences
            refreshSettingsHub()
            return
        end if
    else if item.scope = "account"
        before = copyJson(m.accountPreferences)
        m.accountPreferences[lcase(item.key)] = item.value
        if not persistAccountPreferences()
            m.accountPreferences = before
            m.preferenceStore.accounts[preferenceScope(m.accountIdentity)] = before
            refreshSettingsHub()
            return
        end if
        updateLibraryPermissions()
    end if
    refreshSettingsHub()
end sub

function persistRemoteMap(map as object) as boolean
    before = copyJson(m.devicePreferences)
    m.devicePreferences.remoteMap = map
    m.devicePreferences = normalizeDevicePreferences(m.devicePreferences)
    saved = persistPreferences()
    if not saved
        m.devicePreferences = before
        m.preferenceStore.device = before
    end if
    ' SceneGraph fields are copies: Guide must receive the effective map again,
    ' including the restored map after a failed write.
    applyDevicePreferences()
    return saved
end function
