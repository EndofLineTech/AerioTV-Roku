' Native-only fixture. Temporarily import and call after validation.
sub installSettingsProbe()
    m.settingsProbeStage = 0
    m.settingsProbeTimer = m.top.createChild("Timer")
    m.settingsProbeTimer.duration = 1
    m.settingsProbeTimer.repeat = true
    m.settingsProbeTimer.observeField("fire", "settingsProbeTick")
    m.settingsProbeTimer.control = "start"
end sub

sub settingsProbeTick()
    if m.settingsProbeStage = 0
        if m.page <> "guide" then return
        m.settingsProbeDevice = copyJson(m.devicePreferences)
        m.settingsProbeAccount = copyJson(m.accountPreferences)
        openSettingsHub()
        m.settingsProbeStage = 1
    else if m.settingsProbeStage = 1
        m.settingsHub.callFunc("selectSetting", 3) ' General
        m.settingsProbeStage = 2
    else if m.settingsProbeStage = 2
        m.settingsHub.callFunc("selectSetting", 2) ' Guide Replay action
        m.settingsProbeStage = 3
    else if m.settingsProbeStage = 3
        m.settingsHub.callFunc("selectSetting", 1) ' Open guide options
        m.settingsProbeStage = 4
    else if m.settingsProbeStage = 4
        m.settingsHub.callFunc("selectSetting", 3) ' Network request timeout
        m.settingsProbeStage = 5
    else if m.settingsProbeStage = 5
        m.settingsHub.callFunc("selectSetting", 0) ' 10 seconds
        m.settingsProbeStage = 6
    else if m.settingsProbeStage = 6
        entries = settingsHubEntries("general", m.settingsHub.model)
        m.settingsHub.callFunc("selectSetting", entries.count() - 1) ' About
        m.settingsProbeStage = 7
    else if m.settingsProbeStage = 7
        m.settingsHub.callFunc("selectSetting", 2) ' License notices
        m.settingsProbeStage = 8
    else if m.settingsProbeStage = 8
        list = m.settingsHub.findNode("list")
        print "[settings-probe] licenses="; list.content.getChildCount(); " timeout="; m.global.networkTimeoutMs; " replay="; m.devicePreferences.guideReplayAction
        m.devicePreferences = m.settingsProbeDevice
        m.accountPreferences = m.settingsProbeAccount
        m.preferenceStore.device = m.devicePreferences
        m.preferenceStore.accounts[preferenceScope(m.accountIdentity)] = m.accountPreferences
        persistPreferences()
        applyDevicePreferences()
        closeSettingsHub()
        m.settingsProbeTimer.control = "stop"
        print "[settings-probe] complete"
    end if
end sub
