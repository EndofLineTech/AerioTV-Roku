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
        if m.visualProbeScreen = "guide-return-hour"
            if m.guide = invalid then return
            seeded = m.guide.callFunc("seedGuideReturnHour", true)
            if type(seeded) <> "roAssociativeArray" or seeded.ready <> true then return
            m.guide.active = false
            m.guide.active = true
            following = m.guide.callFunc("readGuideReturnHour")
            seeded = m.guide.callFunc("seedGuideReturnHour", false)
            if type(seeded) <> "roAssociativeArray" or seeded.ready <> true then return
            m.guide.active = false
            m.guide.active = true
            historical = m.guide.callFunc("readGuideReturnHour")
            m.guide.callFunc("resetGuideReturnHour")
            if type(following) <> "roAssociativeArray" or type(historical) <> "roAssociativeArray" then return
            if abs(following.offsetSeconds) > 3 or following.title <> "Current fictional programme" or historical.offsetSeconds > -3595 or historical.offsetSeconds < -3605 or historical.title <> "Prior fictional programme"
                print "ERROR: guide-return-hour re-entry did not respect live/historical time"
                m.visualProbeTimer.control = "stop"
                return
            end if
            print "[guide-return-hour] PASS live offset="; following.offsetSeconds; " current fixture="; following.title; " historical offset="; historical.offsetSeconds; " prior fixture="; historical.title
        else if m.visualProbeScreen = "epg-details"
            details = m.guide.findNode("programDetails")
            startAt = uiNow() - 600
            description = ""
            for i = 1 to 18
                description += "A credential-free fictional programme explains the next turn in a long story. "
            end for
            program = {id: "fixture", title: "The Long Programme", subtitle: "Read the entire description", description: description, startsAt: startAt, endsAt: startAt + 3600, poster: "", categories: [], rating: "", year: "", quality: "", language: "", country: "", credits: ""}
            details.model = {channel: {id: "", name: "Synthetic channel"}, program: program, settings: m.accountPreferences.guide, baseUrl: "", apiKey: "", dvrPermission: "none", reminded: false, catchupAvailable: false, restartAvailable: false}
            details.active = true
        else if m.visualProbeScreen = "vod-data"
            if m.capabilities.movies <> "allowed" then return
            openVodLibrary("movie")
            m.visualProbeStage = 2
            return
        else if m.visualProbeScreen = "dvr-sections"
            if m.capabilities.dvr <> "manage" and m.capabilities.dvr <> "view" then return
            openDvrLibrary()
            m.visualProbeStage = 2
            return
        else if m.visualProbeScreen = "settings"
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
    if m.visualProbeStage = 2
        if m.visualProbeScreen = "vod-data" and m.page = "library"
            m.vod.callFunc("seedVisualProbe")
        else if m.visualProbeScreen = "dvr-sections" and m.page = "dvr"
            m.dvr.callFunc("seedVisualProbe")
        else
            return
        end if
        m.visualProbeStage = 1
    end if
    m.visualProbeTicks++
    if m.visualProbeTicks >= 8
        m.visualProbeTimer.control = "stop"
        hideNotice()
        print "[visual-probe] ready "; m.visualProbeScreen
    end if
end sub
