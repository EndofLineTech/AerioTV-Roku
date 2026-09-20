' Temporarily import into AerioScene. Exercises actual controllers on hardware;
' direct handler calls are not physical remote acceptance. Restores preferences.
sub installTimeshiftControlsProbe()
    m.controlsStage = 0
    m.controlsTicks = 0
    m.controlsFailed = false
    m.controlsTimer = m.top.createChild("Timer")
    m.controlsTimer.duration = 1
    m.controlsTimer.repeat = true
    m.controlsTimer.observeField("fire", "timeshiftControlsTick")
    m.controlsTimer.control = "start"
end sub

sub controlsCheck(ok as boolean, label as string)
    print "[controls-probe] "; label; "="; ok
    if not ok then m.controlsFailed = true
end sub

function controlsPreviewVisible() as boolean
    for each node in m.mediaPlayer.getChildren(-1, 0)
        if node.subtype() = "Label"
            if instr(1, node.text, "SEEK PREVIEW:") > 0 then return true
        end if
    end for
    return false
end function

sub timeshiftControlsTick()
    m.controlsTicks++
    if m.controlsTicks > 180 or m.controlsFailed
        print "[controls-probe] halted stage="; m.controlsStage
        m.controlsFailed = true
        finishTimeshiftControls()
        return
    end if
    if m.controlsStage = 0
        if m.page <> "guide" or m.capabilities.catchup <> "allowed" then return
        for each channel in m.guide.config.channels
            if instr(1, lcase(channel.name), "espn") > 0
                if catchupChannelDays(m.capabilities.catchup, m.channelFacts, channel.id) > 0
                    m.controlsChannel = channel
                    exit for
                end if
            end if
        end for
        if m.controlsChannel = invalid then return
        m.controlsSavedSkip = m.devicePreferences.archiveSkipSeconds
        m.controlsSavedVod = m.accountPreferences.vodEnabled <> false
        m.controlsSavedHistory = {recent: m.accountPreferences.recent, previous: m.accountPreferences.previous, lastWatched: m.accountPreferences.lastWatched}
        m.guide.playerRequest = "settingsHub"
        m.controlsStage = 1
    else if m.controlsStage = 1
        if m.page <> "settings" then return
        controlsCheck(m.settingsHub.findNode("list").content.getChildCount() = 5, "settings-five-categories")
        m.settingsHub.callFunc("selectSetting", 1)
        m.controlsStage = 2
    else if m.controlsStage = 2
        print "[controls-probe] heading="; m.settingsHub.findNode("heading").text; " first="; m.settingsHub.findNode("list").content.getChild(0).title
        m.settingsHub.callFunc("selectSetting", 0)
        m.controlsStage = 3
    else if m.controlsStage = 3
        print "[controls-probe] choice-heading="; m.settingsHub.findNode("heading").text; " count="; m.settingsHub.findNode("list").content.getChildCount()
        m.settingsHub.callFunc("selectSetting", 1)
        m.controlsStage = 4
    else if m.controlsStage = 4
        print "[controls-probe] page="; m.page; " selected-skip="; m.devicePreferences.archiveSkipSeconds
        controlsCheck(m.devicePreferences.archiveSkipSeconds = 120, "settings-skip-active")
        controlsCheck(loadPreferenceStore(m.registry).device.archiveSkipSeconds = 120, "settings-skip-persisted")
        m.settingsHub.callFunc("handleSettingsKey", "back", true)
        m.controlsStage = 5
    else if m.controlsStage = 5
        controlsCheck(m.settingsHub.findNode("list").itemFocused = 1, "settings-back-restores-category")
        m.settingsHub.callFunc("selectSetting", 2)
        m.controlsStage = 6
    else if m.controlsStage = 6
        m.settingsHub.callFunc("selectSetting", 0)
        m.controlsStage = 7
    else if m.controlsStage = 7
        index = 0
        if m.accountPreferences.guide.groupLayout = "pills" then index = 1
        if m.accountPreferences.guide.groupLayout = "sidebar" then index = 2
        m.settingsHub.callFunc("selectSetting", index)
        m.controlsStage = 8
    else if m.controlsStage = 8
        m.settingsHub.callFunc("handleSettingsKey", "back", true)
        m.controlsStage = 9
    else if m.controlsStage = 9
        controlsCheck(m.settingsHub.findNode("list").itemFocused = 2, "appearance-back-restores-category")
        m.settingsHub.callFunc("selectSetting", 3)
        m.controlsStage = 90
    else if m.controlsStage = 90
        if m.settingsHub.findNode("list").content.getChildCount() > 1
            m.settingsHub.callFunc("selectSetting", 1)
            m.controlsStage = 91
        else
            m.controlsStage = 95
        end if
    else if m.controlsStage = 91
        m.settingsHub.callFunc("selectSetting", 1)
        m.controlsStage = 92
    else if m.controlsStage = 92
        controlsCheck(m.accountPreferences.vodEnabled = false and m.guide.moviesPermission = "denied" and m.guide.seriesPermission = "denied", "account-vod-setting-gates-navigation")
        m.settingsHub.callFunc("selectSetting", 1)
        m.controlsStage = 93
    else if m.controlsStage = 93
        index = 0
        if not m.controlsSavedVod then index = 1
        m.settingsHub.callFunc("selectSetting", index)
        m.controlsStage = 94
    else if m.controlsStage = 94
        controlsCheck((m.accountPreferences.vodEnabled <> false) = m.controlsSavedVod, "account-vod-setting-restored")
        m.controlsStage = 95
    else if m.controlsStage = 95
        m.settingsHub.callFunc("handleSettingsKey", "back", true)
        m.controlsStage = 96
    else if m.controlsStage = 96
        m.settingsHub.callFunc("handleSettingsKey", "back", true)
        m.controlsStage = 10
    else if m.controlsStage = 10
        controlsCheck(m.page = "guide" and m.guide.isInFocusChain(), "settings-back-guide")
        start = uiNow() - 7200
        m.guide.archiveRequest = {channel: m.controlsChannel, program: {id: "controls-fixture", title: "Archive controls fixture", startsAt: start, endsAt: start + 900}, scope: m.guide.config.scope}
        m.controlsStage = 11
    else if m.controlsStage = 11
        video = m.mediaPlayer.findNode("mediaVideo")
        if m.page <> "onDemand" or video.state <> "playing" then return
        m.controlsSession = m.archiveSession
        m.mediaPlayer.callFunc("handleArchiveKey", "fastforward", true)
        m.controlsHoldAt = m.controlsTicks
        m.controlsStage = 12
    else if m.controlsStage = 12
        if m.controlsTicks - m.controlsHoldAt < 2 then return
        m.mediaPlayer.callFunc("handleArchiveKey", "fastforward", false)
        controlsCheck(m.archiveSession = m.controlsSession and m.archiveTask = invalid, "held-preview-no-session-reopen")
        controlsCheck(controlsPreviewVisible(), "held-preview-visible")
        m.mediaPlayer.callFunc("handleArchiveKey", "back", true)
        m.controlsStage = 13
    else if m.controlsStage = 13
        controlsCheck(m.archiveSession = m.controlsSession and m.mediaPlayer.findNode("mediaVideo").state = "playing", "preview-cancel-keeps-playback")
        m.mediaPlayer.callFunc("handleArchiveKey", "rewind", true)
        m.mediaPlayer.callFunc("handleArchiveKey", "rewind", false)
        m.controlsStage = 14
    else if m.controlsStage = 14
        if m.archiveSession = invalid or m.archiveSession = m.controlsSession then return
        if m.mediaPlayer.findNode("mediaVideo").state <> "playing" then return
        controlsCheck(m.archiveOffset = 0 and m.archiveCleanupTask.result.status = 204, "rewind-to-same-opening-offset")
        m.controlsSession = m.archiveSession
        m.mediaPlayer.findNode("mediaVideo").control = "pause"
        m.controlsStage = 15
    else if m.controlsStage = 15
        if m.mediaPlayer.findNode("mediaVideo").state <> "paused" then return
        m.mediaPlayer.callFunc("handleArchiveKey", "fastforward", true)
        m.mediaPlayer.callFunc("handleArchiveKey", "fastforward", false)
        m.controlsStage = 16
    else if m.controlsStage = 16
        if m.archiveSession = invalid or m.archiveSession = m.controlsSession then return
        if m.mediaPlayer.findNode("mediaVideo").state <> "paused" then return
        controlsCheck(m.archiveOffset = 120 and m.archiveCleanupTask.result.status = 204, "configured-tap-skip-preserves-pause")
        m.mediaPlayer.callFunc("openArchiveActions")
        m.top.dialog.buttonSelected = 2
        m.controlsStage = 17
    else if m.controlsStage = 17
        if m.top.dialog = invalid then return
        if m.top.dialog.title <> "Archive skip interval" then return
        m.top.dialog.buttonSelected = 0
        m.controlsStage = 18
    else if m.controlsStage = 18
        controlsCheck(m.devicePreferences.archiveSkipSeconds = 60 and m.mediaPlayer.skipSeconds = 60, "in-player-skip-setting")
        m.controlsSession = m.archiveSession
        m.mediaPlayer.callFunc("handleArchiveKey", "fastforward", true)
        m.controlsHoldAt = m.controlsTicks
        m.controlsStage = 19
    else if m.controlsStage = 19
        if m.controlsTicks - m.controlsHoldAt < 2 then return
        m.mediaPlayer.callFunc("handleArchiveKey", "fastforward", false)
        controlsCheck(m.archiveSession = m.controlsSession, "paused-preview-no-session-reopen")
        m.mediaPlayer.callFunc("handleArchiveKey", "OK", true)
        m.controlsStage = 20
    else if m.controlsStage = 20
        if m.archiveSession = invalid or m.archiveSession = m.controlsSession then return
        if m.mediaPlayer.findNode("mediaVideo").state <> "paused" then return
        controlsCheck(m.archiveOffset > 120 and m.archiveOffset <= 840 and m.archiveOffset mod 60 = 0, "held-preview-commit-bounded")
        m.mediaPlayer.callFunc("openArchiveActions")
        m.top.dialog.buttonSelected = 0
        m.controlsStage = 21
    else if m.controlsStage = 21
        if m.page <> "player" or m.video.state <> "playing" then return
        controlsCheck(m.playingChannel.uuid = m.controlsChannel.uuid and m.archiveSession = invalid, "go-live-same-channel")
        m.userInfoOpen = true
        showChannelBanner(m.playingChannel, playerInfoHint())
        m.video.control = "pause"
        m.controlsStage = 22
    else if m.controlsStage = 22
        if m.video.state <> "paused" or m.banner.playhead = invalid then return
        if not m.banner.playhead.known then return
        m.controlsPausedEpoch = m.banner.playhead.epoch
        m.controlsPauseAt = m.controlsTicks
        m.controlsStage = 23
    else if m.controlsStage = 23
        if m.controlsTicks - m.controlsPauseAt < 10 then return
        clock = m.banner.playhead
        print "[controls-probe] pause-clock="; FormatJson({clock: clock, pinned: m.controlsPausedEpoch, nativePosition: m.video.position, nativeInfo: m.video.positionInfo, clip: m.video.clipId, overflow: m.video.pauseBufferOverflow, anchor: m.liveSession.clockAnchor})
        controlsCheck(clock.known and clock.delayed and clock.epoch = m.controlsPausedEpoch and clock.delay >= 9, "live-pause-clock-fixed-delay-grows")
        m.video.control = "resume"
        m.controlsResumeAt = m.controlsTicks
        m.controlsStage = 24
    else if m.controlsStage = 24
        if m.controlsTicks - m.controlsResumeAt < 5 then return
        clock = m.banner.playhead
        controlsCheck(clock.known and clock.delayed and clock.epoch > m.controlsPausedEpoch, "resumed-delayed-clock-advances")
        stopPlayback()
        m.controlsStage = 25
    else if m.controlsStage = 25
        openSettingsHub()
        m.settingsHub.callFunc("selectSetting", 4)
        m.controlsStage = 26
    else if m.controlsStage = 26
        m.settingsHub.callFunc("selectSetting", 0)
        m.controlsStage = 27
    else if m.controlsStage = 27
        controlsCheck(m.page = "setup" and not m.settingsHub.active, "connection-opens-existing-editor")
        finishTimeshiftControls()
    end if
end sub

sub finishTimeshiftControls()
    m.controlsTimer.control = "stop"
    m.settingsHub.active = false
    m.mediaPlayer.callFunc("closeMedia")
    cancelArchiveLoad()
    releaseArchive()
    stopPlayback()
    if m.controlsSavedSkip <> invalid
        m.devicePreferences.archiveSkipSeconds = m.controlsSavedSkip
        persistPreferences()
    end if
    if m.controlsSavedHistory <> invalid
        m.accountPreferences.vodEnabled = m.controlsSavedVod
        for each key in m.controlsSavedHistory
            m.accountPreferences[key] = m.controlsSavedHistory[key]
        end for
        persistAccountPreferences()
        m.guide.recentIds = m.accountPreferences.recent
        updateLibraryPermissions()
    end if
    print "[controls-probe] finished passed="; not m.controlsFailed
end sub
