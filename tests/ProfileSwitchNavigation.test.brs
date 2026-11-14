sub main()
    switchRollbackFixture()
    oldSession = m.profileSwitchContext.outgoing.sessionId
    rollbackUserProfileSwitch("Rejected own key")
    check(m.profileSwitchContext = invalid and not m.profileGateCover.visible and not m.global.profilegateclosed and m.guide.active, "ordinary cancellation returns to previous guide without autoplay")
    check(m.activeUserScope.profileId = "00000000-0000-4000-8000-000000000001" and m.activeUserScope.sessionId <> oldSession and m.guide.config.aeriosession = m.activeUserScope.sessionId, "rollback rebuilds previous scope with a fresh UUID and rebinds its view")
    switchRollbackFixture()
    m.userProfileRecoveryRequired = true
    rollbackUserProfileSwitch("Registry rollback failed")
    check(m.profileGateCover.visible and m.global.profilegateclosed and not m.guide.active and m.activeUserScope = invalid and m.global.activeusersession = "", "failed registry rollback must stay covered, never revive potentially stale protection")
    switchRollbackFixture()
    m.profileSwitchContext.unavailableChild = true
    m.profileSwitchContext.outgoing = invalid
    m.activeUserScope = invalid
    rollbackUserProfileSwitch("Target key rejected")
    check(m.profileSwitchContext = invalid and m.activeUserScope = invalid and m.global.activeusersession = "" and m.global.profilegateclosed and m.profileGateCover.visible and not m.guide.active, "unavailable Child cancellation stays unavailable without fabricating an outgoing authenticated session")
    check(m.page = "profile-unavailable" and not m.busy and not m.global.profileswitchpending and m.childSurfaceRestored, "unavailable escape failure restores only the Child surface, never default setup or guide")
    print "ALL TESTS PASSED"
end sub

sub showUnavailableChildProfile()
    m.childSurfaceRestored = true
end sub

sub switchRollbackFixture()
    connection = {id: "slot-a", provider: "dispatcharr", url: "https://example.test"}
    outgoing = userProfileSessionScope(connection, "00000000-0000-4000-8000-000000000001", 7, "old-generation", "00000000-0000-4000-8000-000000000090")
    m.profileSwitchContext = {connection: connection, outgoing: outgoing}
    m.selectedConnectionId = "slot-a"
    m.global = {profilegateclosed: false, profileswitchpending: true, activeusersession: "staging-session"}
    m.profileGateCover = {visible: true}
    m.guide = {active: false, config: {aeriosession: outgoing.sessionId}}
    m.capabilityClock = {control: "stop"}
    m.reminderClock = {control: "stop"}
    m.top = {label: {}, findNode: function(id as string) as object
        return m.label
    end function}
    m.activeUserScope = outgoing
    m.userProfileRecoveryRequired = false
end sub

sub showNotice(message as string)
    m.notice = message
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
