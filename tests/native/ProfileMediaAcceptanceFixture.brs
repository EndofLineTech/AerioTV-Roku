' One read-only DVR/profile success journey in the disposable baseline registry.
' Uses real components, own credentials and existing completed recordings only.
sub onProfileMediaAcceptanceTick()
    stage = m.pickerProbeBaselineStage
    if stage = invalid then stage = 0
    if m.mediaAcceptanceStage <> stage
        m.mediaAcceptanceStage = stage
        print "[picker-launch] "; FormatJson({kind: "profile-media-state", stage: stage, page: m.page})
    end if
    if stage = 0
        if m.busy or m.page <> "guide" or m.activeUserScope = invalid then return
        if not profileMediaLibraryReady() then return
        m.mediaAcceptanceSourceScope = m.activeUserScope
        openDvrLibrary()
        if m.page <> "dvr" then finishProfileMediaAcceptance(false, "library-admission") : return
        m.pickerProbeBaselineStage = 1
    else if stage = 1 or stage = 6
        if m.page <> "dvr" then return
        row = m.dvr.callFunc("profileMediaAcceptanceRow")
        if row = invalid then return
        if not row.ready
            if row.loaded then finishProfileMediaAcceptance(false, "no-playable-recording")
            return
        end if
        if m.dvr.config.aeriosession <> currentUserSessionId() or m.dvr.config.apiKey <> m.apiKey then finishProfileMediaAcceptance(false, "library-scope") : return
        onDvrPlayRequested(baselineProbeEvent(m.dvr, userViewEvent({scope: m.accountIdentity, accountId: m.serverAccountId, recordingId: row.id, fromBeginning: true}, currentUserSessionId())))
        m.pickerProbeBaselineStage = stage + 1
    else if stage = 2 or stage = 7
        if m.page <> "onDemand" then return
        video = m.mediaPlayer.findNode("mediaVideo")
        if video.state = "error" then finishProfileMediaAcceptance(false, "playback-error") : return
        if video.state <> "playing" or video.position < 2 then return
        if stage = 2 then m.mediaAcceptanceSourcePlayed = true else m.mediaAcceptanceTargetPlayed = true
        m.mediaPlayer.callFunc("closeMedia")
        m.pickerProbeBaselineStage = stage + 1
    else if stage = 3
        if m.page <> "dvr" then return
        closeDvrLibrary()
        if not persistCurrentUserProfilePreferences() then finishProfileMediaAcceptance(false, "source-save") : return
        preferences = loadPreferenceStore(m.registry, true)
        m.mediaAcceptanceSourceSettings = FormatJson(preferences.accounts[m.mediaAcceptanceSourceScope.preferenceIdentity])
        beginProfileBaselineAdd()
        m.pickerProbeBaselineStage = 4
    else if stage = 4
        if m.profileOwnSignInContext = invalid or m.profileOwnSignInDialog = invalid then return
        m.profileOwnSignInContext.username = "Synthetic8"
        m.profileOwnSignInContext.password = "synthetic-password"
        onProfileOwnSignInChoice(baselineProbeEvent(m.profileOwnSignInDialog, 2))
        m.pickerProbeBaselineStage = 5
    else if stage = 5
        if m.profileOwnSignInContext <> invalid or m.profileSwitchContext <> invalid or m.busy then return
        if m.activeUserScope.accountId = "8"
            if not profileMediaLibraryReady() then return
            if userProfileSameSession(m.mediaAcceptanceSourceScope, m.activeUserScope) then finishProfileMediaAcceptance(false, "unchanged-scope") : return
            preferences = loadPreferenceStore(m.registry, true)
            if FormatJson(preferences.accounts[m.mediaAcceptanceSourceScope.preferenceIdentity]) <> m.mediaAcceptanceSourceSettings then finishProfileMediaAcceptance(false, "source-preferences") : return
            openDvrLibrary()
            if m.page <> "dvr" then finishProfileMediaAcceptance(false, "library-admission") : return
            m.pickerProbeBaselineStage = 6
            return
        end if
        store = loadUserProfileStore(m.registry, "slot-a")
        for each profile in store.profiles
            if profile.userId = 8
                closeProfileBaselineMenu()
                if not beginUserProfileSwitch(profile.id) then finishProfileMediaAcceptance(false, "switch-admission")
                return
            end if
        end for
    else if stage = 8
        if m.page <> "dvr" then return
        closeDvrLibrary()
        finishProfileMediaAcceptance(m.mediaAcceptanceSourcePlayed = true and m.mediaAcceptanceTargetPlayed = true, "completed")
    end if
end sub

function profileMediaLibraryReady() as boolean
    if m.capabilityTask <> invalid then return false
    if m.capabilities.dvr = "unknown"
        if m.mediaCapabilityScope = currentUserSessionId()
            finishProfileMediaAcceptance(false, "capability-unavailable")
        else
            m.mediaCapabilityScope = currentUserSessionId()
            refreshCapabilities()
        end if
        return false
    end if
    if m.capabilities.dvr <> "view" and m.capabilities.dvr <> "manage"
        finishProfileMediaAcceptance(false, "recording-permission")
        return false
    end if
    return true
end function

sub finishProfileMediaAcceptance(passed as boolean, reason as string)
    m.pickerProbeClock.control = "stop"
    print "[picker-launch] "; FormatJson({kind: "result", baseline: true, profileMedia: true, passed: passed, reason: reason, sourcePlayed: m.mediaAcceptanceSourcePlayed = true, targetPlayed: m.mediaAcceptanceTargetPlayed = true})
end sub
