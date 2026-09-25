' Scripted screen selection for capture only. Excluded from the normal package.
' No media is started and no settings are persisted by this fixture.
sub installVisualProbe()
    m.visualProbeStage = 0
    m.visualProbeTicks = 0
    m.visualProbeTimer = m.top.createChild("Timer")
    m.visualProbeTimer.duration = 1
    m.visualProbeTimer.repeat = true
    m.visualProbeTimer.observeField("fire", "visualProbeTick")
    m.visualProbeTimer.control = "start"
end sub

sub visualProbeTick()
    if m.visualProbeStage = 0
        if m.visualProbeTicks = 0 then print "[visual-probe] waiting for page="; m.page
        m.visualProbeTicks++
        if m.visualProbeScreen = "welcome"
            if m.page <> "guide" and m.page <> "setup" then return
            if m.page = "setup" and m.busy then return
        else if m.page <> "guide"
            return
        end if
        if m.visualProbeScreen = "settings"
            openSettingsHub()
            m.settingsHub.callFunc("selectSettingsCategory", 2)
        else if m.visualProbeScreen = "vod"
            if m.capabilities.movies <> "allowed" then return
            openVodLibrary("movie")
        else if m.visualProbeScreen = "pills"
            m.guide.callFunc("applyHubGuideSetting", "groupLayout", "pills")
            m.guide.findNode("primaryNavigation").active = true
        else if m.visualProbeScreen = "welcome"
            ' Render first-run artwork without touching a saved connection or
            ' installing a different account fixture on the shared Roku.
            m.guide.active = false
            m.guide.visible = false
            m.screen.visible = true
            m.page = "welcome"
            drawWelcome()
            m.top.setFocus(true)
        else if m.visualProbeScreen = "lavender" or m.visualProbeScreen = "light"
            m.devicePreferences = copyJson(m.devicePreferences)
            m.devicePreferences.themePreset = "lavender"
            m.devicePreferences.customAccent = ""
            m.devicePreferences.appearanceMode = "dark"
            if m.visualProbeScreen = "light" then m.devicePreferences.appearanceMode = "light"
            applyDevicePreferences()
            openSettingsHub()
            m.settingsHub.callFunc("selectSettingsCategory", 3)
        else if m.visualProbeScreen = "large" or m.visualProbeScreen = "large-vod" or m.visualProbeScreen = "large-guide-options"
            m.devicePreferences = copyJson(m.devicePreferences)
            m.devicePreferences.textSize = 120
            m.devicePreferences.subtextSize = 120
            m.devicePreferences.contrastMode = "high"
            applyDevicePreferences()
            if m.visualProbeScreen = "large-guide-options"
                m.guide.callFunc("handleOptionsShortcut")
            else if m.visualProbeScreen = "large-vod"
                if m.capabilities.movies <> "allowed" then return
                openVodLibrary("movie")
            else
                openSettingsHub()
                m.settingsHub.callFunc("selectSettingsCategory", 3)
            end if
        end if
        m.visualProbeStage = 1
        return
    end if
    m.visualProbeTicks++
    if m.visualProbeTicks >= 8
        m.visualProbeTimer.control = "stop"
        hideNotice()
        print "[visual-probe] ready "; m.visualProbeScreen
    end if
end sub
