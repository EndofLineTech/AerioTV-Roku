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
        if m.page <> "guide" then return
        if m.visualProbeScreen = "settings"
            openSettingsHub()
            m.settingsHub.callFunc("selectSettingsCategory", 2)
        else if m.visualProbeScreen = "vod"
            if m.capabilities.movies <> "allowed" then return
            openVodLibrary("movie")
        else if m.visualProbeScreen = "pills"
            m.guide.callFunc("applyHubGuideSetting", "groupLayout", "pills")
            m.guide.findNode("primaryNavigation").active = true
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
