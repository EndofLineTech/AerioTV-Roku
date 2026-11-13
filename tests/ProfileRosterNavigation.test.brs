sub main()
    scope = {playlistId: "slot-a", profileId: "profile-a", accountId: "7", preferenceIdentity: "server|7|slot-a", authorizationGeneration: "generation", sessionId: "session-a"}
    m.activeUserScope = scope
    m.userProfileStore = {active: "profile-a"}
    m.apiKey = "own-key"
    grant = {slot: "slot-a", profile: "profile-a", key: "own-key", scope: scope}
    m.profileRosterGrant = grant
    check(consumeProfileRosterGrant({id: "slot-a"}), "own authenticated read permits one lineup continuation")
    check(not consumeProfileRosterGrant({id: "slot-a"}), "authorization is consumed once, not reused on refresh")
    for each field in ["slot", "profile", "key"]
        m.profileRosterGrant = copyJson(grant)
        m.profileRosterGrant[field] = "different"
        check(not consumeProfileRosterGrant({id: "slot-a"}), "another slot/profile/credential cannot borrow early-read authorization")
    end for
    m.profileRosterGrant = copyJson(grant)
    m.profileRosterGrant.scope.sessionId = "retired-a"
    check(not consumeProfileRosterGrant({id: "slot-a"}), "A/B/A retirement rejects old early-read continuation")
    m.profileRosterContext = {scope: scope, connection: {id: "slot-a"}}
    m.selectedConnectionId = "slot-b"
    finishAuthenticatedRosterRead({ok: true})
    check(m.profileRosterContext <> invalid and m.task = invalid, "late read for outgoing slot has no effects")
    rosterControllerFixture(scope)
    finishAuthenticatedRosterRead({ok: false, state: "unavailable"})
    check(m.pullCommits = 0 and m.connectCalls = 1 and m.profileRosterGrant <> invalid, "unavailable read preserves known protection and never manufactures a roster")
    rosterControllerFixture(scope)
    m.profileRosterEnabled = false
    finishAuthenticatedRosterRead({ok: true, state: "ready", profilesState: "ready", data: {categories: {profiles: {data: {}}}}})
    check(m.pullCommits = 1 and not m.enabledForPull and m.connectCalls = 1, "Profiles-Off is passed to atomic pull instead of applying rows")
    rosterControllerFixture(scope)
    m.testGate = {allowed: false, reason: "pin"}
    finishAuthenticatedRosterRead({ok: false, state: "missing"})
    check(m.pinCalls = 1 and m.connectCalls = 0, "retained/imported PIN gates before lineup continuation")
    rosterControllerFixture(scope)
    m.pullFailure = true
    finishAuthenticatedRosterRead({ok: true, state: "ready", profilesState: "ready", data: {categories: {profiles: {data: {}}}}})
    check(m.connectCalls = 0 and m.setupCalls = 1 and m.profileRosterGrant = invalid, "failed atomic protection commit cannot authorize channel access")
    print "ALL TESTS PASSED"
end sub

sub rosterControllerFixture(scope as object)
    m.activeUserScope = scope
    m.selectedConnectionId = "slot-a"
    m.userProfileStore = {active: "profile-a", profiles: [{id: "profile-a"}]}
    m.profileRosterContext = {scope: scope, connection: {id: "slot-a"}, verified: {apiKey: "own-key"}}
    m.task = {unobserveField: sub(field as string)
    end sub}
    m.testGate = {allowed: true}
    m.profileRosterGrant = invalid
    m.profileRosterEnabled = true
    m.pullCommits = 0
    m.connectCalls = 0
    m.pinCalls = 0
    m.setupCalls = 0
    m.pullFailure = false
end sub

function dispatcharrSyncRosterDecode(data as object) as object
    return {ok: true}
end function

function commitDispatcharrRosterPull(registry as dynamic, connection as object, previous as object, decoded as object, enabled as boolean, now as integer, captured as object, active as object) as object
    m.pullCommits++
    m.enabledForPull = enabled
    return {ok: not m.pullFailure, applied: false, recoveryRequired: false}
end function

function selectedUserProfileGate() as object
    return m.testGate
end function

function beginProfilePinGate(profile as object, continuation as string) as boolean
    m.pinCalls++
    return true
end function

sub connectServer(skipRfi as boolean)
    m.connectCalls++
end sub

sub drawSetup()
    m.setupCalls++
end sub

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
