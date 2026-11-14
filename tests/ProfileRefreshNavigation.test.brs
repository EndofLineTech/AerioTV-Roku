sub main()
    refreshAuthorityFixture()
    result = {ok: true, verifiedUser: {id: 8, username: "Bob"}}
    m.profileAuthorizationSignature = dispatcharrAuthorizationSignature(result.verifiedUser)
    check(not handleManualProfileRefreshAuthority(result) and not m.fixtureParked and not m.fixtureCancelled and not m.fixtureConnected and m.activeUserScope <> invalid, "unchanged manual authority preserves playback/session and submitted result observation")
    m.profileAuthorizationSignature = "old-authority"
    check(handleManualProfileRefreshAuthority(result) and m.fixtureParked and m.fixtureCancelled and m.fixtureConnected and m.activeUserScope = invalid and m.global.activeusersession = "" and m.profileRefreshReload, "changed authority parks operation observation and closes unsubmitted forms before retiring old session and reconnecting")
    refreshAuthorityFixture()
    check(handleManualProfileRefreshAuthority({ok: false, identityChanged: true, message: "wrong holder"}) and m.fixtureParked and m.fixtureRelogin, "foreign manual verification routes to selected-holder recovery")
    refreshAuthorityFixture()
    check(not handleManualProfileRefreshAuthority({ok: false, message: "offline"}) and not m.fixtureParked and not m.fixtureRelogin, "transient manual refresh failure does not revoke credentials or interrupt playback")
    refreshAuthorityFixture()
    m.fixtureAuthorityValid = false
    check(handleManualProfileRefreshAuthority(result) and m.global.profilegateclosed and m.profileGateCover.visible and m.userProfileRecoveryRequired and not m.fixtureConnected, "unverifiable current authority fails covered without adopting a result")
    refreshAuthorityFixture()
    m.profileAuthorizationSignature = "old-authority"
    m.fixturePersist = false
    check(handleManualProfileRefreshAuthority(result) and m.fixtureParked and m.fixtureCancelled and m.global.profilegateclosed and not m.fixtureConnected and m.top.message.text <> "", "failed own-settings preservation covers content and retains the old data rather than reconnecting unsafely")
    print "ALL TESTS PASSED"
end sub

sub refreshAuthorityFixture()
    m.scopedPreferencesRequired = true
    m.activeUserScope = {profileId: "own"}
    m.global = {activeusersession: "old-session", profilegateclosed: false}
    m.guide = {active: true}
    m.profileGateCover = {visible: false}
    m.top = {message: {text: ""}, findNode: function(id as string) as object
        return m.message
    end function, hasField: function(field as string) as boolean
        return false
    end function, getChildren: function(count as integer, first as integer) as object
        return []
    end function}
    m.playingChannel = {id: "8"}
    m.fixtureAuthorityValid = true
    m.fixturePersist = true
    m.fixtureParked = false
    m.fixtureCancelled = false
    m.fixtureConnected = false
    m.fixtureRelogin = false
end sub

function refreshActiveUserProfileAuthority(result as object, now as integer) as boolean
    return m.fixtureAuthorityValid
end function

function persistCurrentUserProfilePreferences() as boolean
    return m.fixturePersist
end function

sub preserveSubmittedRecording()
    m.fixtureParked = true
end sub

sub cancelRecordFlow()
    m.fixtureCancelled = true
end sub

sub requireConnectionRelogin(message as string)
    m.fixtureRelogin = true
end sub

sub stopPlayback()
    m.playingChannel = invalid
end sub

sub resetMediaNavigation()
end sub

sub cancelCapabilityRefresh()
end sub

sub connectServer(skipRfi as boolean)
    m.fixtureConnected = true
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
