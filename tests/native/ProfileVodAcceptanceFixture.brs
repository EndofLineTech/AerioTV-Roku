' Populated own-account VOD main flow. Disposable registry; no server mutations.
sub finishProfileVodAcceptance(passed as boolean, reason as string)
    m.pickerProbeClock.control = "stop"
    print "[picker-launch] "; FormatJson({kind: "result", baseline: true, profileMedia: true, profileVod: true, passed: passed, reason: reason, sourcePlayed: m.vodAcceptanceSourcePlayed = true, targetPlayed: m.vodAcceptanceTargetPlayed = true})
end sub

function profileVodVisualDone(view as string) as boolean
    if m.vodAcceptanceVisualPending <> true
        m.vodAcceptanceVisualPending = true
        m.pickerProbeVisualCaptured = false
        print "[picker-launch] "; FormatJson({kind: "profile-vod-visual", view: view, account: m.vodAcceptanceAccount})
        return false
    end if
    if m.pickerProbeVisualCaptured <> true then return false
    m.vodAcceptanceVisualPending = false
    return true
end function

sub onProfileMediaAcceptanceTick()
    stage = m.pickerProbeBaselineStage
    if stage = invalid then stage = 0
    if m.vodAcceptanceStage <> stage
        m.vodAcceptanceStage = stage
        print "[picker-launch] "; FormatJson({kind: "profile-vod-stage", stage: stage, page: m.page})
    end if
    if stage = 0
        if m.busy or m.page <> "guide" or m.activeUserScope = invalid then return
        if m.capabilityTask <> invalid then return
        if m.capabilities.movies = "unknown" or m.capabilities.series = "unknown"
            if m.vodAcceptanceRefreshed = true then finishProfileVodAcceptance(false, "capability-unavailable") : return
            m.vodAcceptanceRefreshed = true
            refreshCapabilities()
            return
        end if
        if m.capabilities.movies <> "allowed" or m.capabilities.series <> "allowed" then finishProfileVodAcceptance(false, "vod-permission") : return
        if m.vodAcceptanceAccount = invalid
            m.vodAcceptanceAccount = 1
            m.vodAcceptanceSourceScope = m.activeUserScope
        end if
        openVodLibrary("movie")
        if m.page <> "library" then finishProfileVodAcceptance(false, "movie-library-admission") : return
        m.pickerProbeBaselineStage = 1
    else if stage = 1 or stage = 2
        state = m.vod.callFunc("profileVodAcceptanceState")
        if state.loading then return
        if state.count = 0 then finishProfileVodAcceptance(false, "empty-vod-library") : return
        if m.vod.config.aeriosession <> currentUserSessionId() or m.vod.config.apiKey <> m.apiKey then finishProfileVodAcceptance(false, "vod-library-scope") : return
        view = "movies"
        if stage = 2 then view = "series"
        if not profileVodVisualDone(view) then return
        print "[picker-launch] "; FormatJson({kind: "profile-vod-catalog", account: m.vodAcceptanceAccount, view: view, rows: state.count, total: state.total})
        closeVodLibrary()
        if stage = 1
            openVodLibrary("series")
        else
            openVodLibrary("movie")
        end if
        m.pickerProbeBaselineStage = stage + 1
    else if stage = 3
        state = m.vod.callFunc("profileVodAcceptanceState")
        if state.loading then return
        if not m.vod.callFunc("profileVodAcceptanceAction", "search") then finishProfileVodAcceptance(false, "movie-search") : return
        m.pickerProbeBaselineStage = 4
    else if stage = 4
        state = m.vod.callFunc("profileVodAcceptanceState")
        if state.loading then return
        if not m.vod.callFunc("profileVodAcceptanceAction", "detail") then finishProfileVodAcceptance(false, "representative-movie-unavailable") : return
        m.pickerProbeBaselineStage = 5
    else if stage = 5
        state = m.vod.callFunc("profileVodAcceptanceState")
        if state.loading then return
        if not state.detail then finishProfileVodAcceptance(false, "movie-detail-unavailable") : return
        if not m.vod.callFunc("profileVodAcceptanceAction", "play") then finishProfileVodAcceptance(false, "movie-play-unavailable") : return
        m.pickerProbeBaselineStage = 6
    else if stage = 6
        video = m.mediaPlayer.callFunc("profileMediaAcceptanceState")
        if video.state = "error" then finishProfileVodAcceptance(false, "movie-player-error") : return
        if m.page <> "onDemand" then finishProfileVodAcceptance(false, "movie-player-not-open") : return
        if video.state <> "playing" or video.position < 2 then return
        if not video.current or not video.allowed then finishProfileVodAcceptance(false, "movie-player-scope") : return
        if not profileVodVisualDone("playing") then return
        print "[picker-launch] "; FormatJson({kind: "profile-vod-progress", account: m.vodAcceptanceAccount, state: video.state, position: video.position, duration: video.duration, errorCode: video.errorCode})
        if m.vodAcceptanceAccount = 1 then m.vodAcceptanceSourcePlayed = true else m.vodAcceptanceTargetPlayed = true
        m.mediaPlayer.callFunc("closeMedia")
        m.pickerProbeBaselineStage = 7
    else if stage = 7
        if m.page <> "library" then return
        closeVodLibrary()
        if m.vodAcceptanceAccount = 2
            finishProfileVodAcceptance(m.vodAcceptanceSourcePlayed = true and m.vodAcceptanceTargetPlayed = true, "completed")
            return
        end if
        if not persistCurrentUserProfilePreferences() then finishProfileVodAcceptance(false, "source-save") : return
        preferences = loadPreferenceStore(m.registry, true)
        m.vodAcceptanceSourceSettings = FormatJson(preferences.accounts[m.vodAcceptanceSourceScope.preferenceIdentity])
        beginProfileBaselineAdd()
        m.pickerProbeBaselineStage = 8
    else if stage = 8
        if m.profileOwnSignInContext = invalid or m.profileOwnSignInDialog = invalid then return
        m.profileOwnSignInContext.username = ""
        m.profileOwnSignInContext.addKey = "synthetic-b"
        onProfileOwnSignInChoice(baselineProbeEvent(m.profileOwnSignInDialog, 2))
        m.pickerProbeBaselineStage = 9
    else if stage = 9
        if m.profileOwnSignInContext <> invalid or m.profileSwitchContext <> invalid or m.busy then return
        if m.activeUserScope.accountId = "8"
            if userProfileSameSession(m.vodAcceptanceSourceScope, m.activeUserScope) then finishProfileVodAcceptance(false, "unchanged-scope") : return
            preferences = loadPreferenceStore(m.registry, true)
            if FormatJson(preferences.accounts[m.vodAcceptanceSourceScope.preferenceIdentity]) <> m.vodAcceptanceSourceSettings then finishProfileVodAcceptance(false, "source-preferences") : return
            m.vodAcceptanceAccount = 2
            m.vodAcceptanceRefreshed = false
            m.pickerProbeBaselineStage = 0
            return
        end if
        store = loadUserProfileStore(m.registry, "slot-a")
        for each profile in store.profiles
            if profile.userId = 8
                closeProfileBaselineMenu()
                if not beginUserProfileSwitch(profile.id) then finishProfileVodAcceptance(false, "switch-admission")
                return
            end if
        end for
    end if
end sub
