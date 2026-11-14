' A manual lineup response proves current authority, just as the periodic /me.
' Unchanged authority keeps playback and operation observation uninterrupted.
function handleManualProfileRefreshAuthority(result as object) as boolean
    if result.ok <> true
        if result.relogin = true or result.identityChanged = true
            preserveSubmittedRecording()
            requireConnectionRelogin(textValue(result.message))
            return true
        end if
        return false
    end if
    if m.scopedPreferencesRequired <> true then return false
    if not refreshActiveUserProfileAuthority(result, CreateObject("roDateTime").asSeconds())
        preserveSubmittedRecording()
        coverManualProfileAuthorityFailure()
        return true
    end if
    signature = dispatcharrAuthorizationSignature(result.verifiedUser)
    if signature = m.profileAuthorizationSignature then return false
    preserveSubmittedRecording()
    cancelRecordFlow()
    if not persistCurrentUserProfilePreferences()
        coverManualProfileAuthorityFailure()
        return true
    end if
    m.profileAuthorizationSignature = signature
    if m.playingChannel <> invalid then stopPlayback()
    resetMediaNavigation()
    cancelCapabilityRefresh()
    m.activeUserScope = invalid
    m.global.activeusersession = ""
    m.global.cacheEpoch = CreateObject("roDeviceInfo").getRandomUUID()
    m.guide.active = false
    m.profileGateCover.visible = true
    m.profileRefreshReload = true
    m.status = "Profile access changed. Reloading authorized content."
    connectServer(true)
    return true
end function

sub coverManualProfileAuthorityFailure()
    cancelRecordFlow()
    if m.playingChannel <> invalid then stopPlayback()
    resetMediaNavigation()
    m.userProfileRecoveryRequired = true
    m.global.profilegateclosed = true
    m.profileGateCover.visible = true
    m.guide.active = false
    m.top.findNode("profileGateMessage").text = "Could not safely save current profile permissions. Saved data was retained. Back exits AerioTV."
    requestGateFenceRenderers(m.top)
end sub
