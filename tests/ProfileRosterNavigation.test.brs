sub main()
    scope = {playlistId: "slot-a", profileId: "profile-a", accountId: "7", preferenceIdentity: "server|7|slot-a", authorizationGeneration: "generation", sessionId: "session-a"}
    m.activeUserScope = scope
    m.userProfileStore = {active: "profile-a"}
    m.apiKey = "own-key"
    grant = {slot: "slot-a", profile: "profile-a", key: "own-key", scope: scope, authorizationSignature: dispatcharrAuthorizationSignature({id: 7, username: "Alice", user_level: 1})}
    m.profileRosterGrant = grant
    check(consumeProfileRosterGrant({id: "slot-a"}), "own authenticated read permits one lineup continuation")
    check(not consumeProfileRosterGrant({id: "slot-a"}), "authorization is consumed once, not reused on refresh")
    for each field in ["slot", "profile", "key"]
        m.profileRosterGrant = copyPreferenceValue(grant)
        m.profileRosterGrant[field] = "different"
        check(not consumeProfileRosterGrant({id: "slot-a"}), "another slot/profile/credential cannot borrow early-read authorization")
    end for
    m.profileRosterGrant = copyPreferenceValue(grant)
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
    finishAuthenticatedRosterRead(rosterControllerRead())
    check(m.pullCommits = 1 and not m.enabledForPull and m.connectCalls = 1, "Profiles-Off is passed to atomic pull instead of applying rows")
    rosterControllerFixture(scope)
    m.testGate = {allowed: false, reason: "pin"}
    finishAuthenticatedRosterRead({ok: false, state: "missing"})
    check(m.pinCalls = 1 and m.connectCalls = 0, "retained/imported PIN gates before lineup continuation")
    rosterControllerFixture(scope)
    m.pullFailure = true
    finishAuthenticatedRosterRead(rosterControllerRead())
    check(m.connectCalls = 0 and m.setupCalls = 1 and m.profileRosterGrant = invalid, "failed atomic protection commit cannot authorize channel access")
    for each change in ["level", "staff", "superuser", "assignments", "stream-limit", "permissions", "identity", "username", "address", "missing-authority", "staff-string", "permission-string", "level-float", "id-float"]
        rosterControllerFixture(scope)
        read = rosterControllerRead()
        if change = "level" then m.profileRosterContext.verified.verifiedUser.user_level = 10
        if change = "staff" then read.verifiedUser.is_staff = true
        if change = "superuser" then read.verifiedUser.is_superuser = true
        if change = "assignments" then read.verifiedUser.channel_profiles = [2]
        if change = "stream-limit" then read.verifiedUser.stream_limit = 3
        if change = "permissions" then read.verifiedUser.custom_properties.vod_movies_enabled = false
        if change = "identity" then read.verifiedUser.id = 80
        if change = "username" then read.verifiedUser.username = "foreign"
        if change = "address" then read.verifiedBaseUrl = "https://foreign.test"
        if change = "missing-authority" then read.verifiedUser = invalid
        if change = "staff-string" then read.verifiedUser.is_staff = "false"
        if change = "permission-string" then read.verifiedUser.custom_properties.vod_movies_enabled = "false"
        if change = "level-float" then read.verifiedUser.user_level = 1.0
        if change = "id-float" then read.verifiedUser.id = 7.0
        finishAuthenticatedRosterRead(read)
        check(m.pullCommits = 0 and m.connectCalls = 0 and m.setupCalls = 0 and m.profileRosterGrant = invalid and m.activeUserScope = invalid and m.global.profilegateclosed and m.profileGateCover.visible and m.userProfileRecoveryRequired, "changed own-read " + change + " cannot apply protection under older authority or authorize a lineup/setup fallback")
        check(m.preserved = 1 and m.cancelled = 1 and m.preservedWithScope and m.apiKey = "own-key", "authority retirement preserves submitted observation before closing actor/input gates without deleting the own credential")
    end for
    for each state in ["missing", "legacy"]
        rosterControllerFixture(scope)
        read = rosterControllerRead()
        read.state = state
        m.profileRosterContext.verified.verifiedUser.user_level = 10
        finishAuthenticatedRosterRead(read)
        check(m.pullCommits = 0 and m.connectCalls = 0 and m.activeUserScope = invalid and m.global.profilegateclosed, "successful missing/legacy discovery still cannot bless a changed own authority")
    end for
    rosterControllerFixture(scope)
    read = rosterControllerRead()
    read.accountUsername = "ALICE"
    read.verifiedUser.username = "ALICE"
    read.verifiedUser.private_token = "never-used"
    finishAuthenticatedRosterRead(read)
    check(m.connectCalls = 1 and m.pullCommits = 1 and m.profileRosterGrant.authorizationSignature = dispatcharrAuthorizationSignature(read.verifiedUser), "same semantic authority/case-insensitive own name hands off only a one-shot bound authorization signature")
    m.profileRosterGrant.authorizationSignature = ""
    check(not consumeProfileRosterGrant({id: "slot-a"}), "an early read with no bound authority signature cannot authorize a full reload")
    rosterControllerFixture(scope)
    check(not profileRosterConnectionCallbackCurrent(m.task) and m.profileRosterContext <> invalid and m.pullCommits = 0, "a queued generic connection timer cannot reinterpret the dedicated own-roster Task as a full lineup result")
    m.profileRosterContext = invalid
    check(profileRosterConnectionCallbackCurrent(m.task), "a current connection Task is eligible only outside the dedicated own-roster phase")
    m.global.activeusersession = "successor"
    check(not profileRosterConnectionCallbackCurrent(m.task) and not m.global.profilegateclosed and m.activeUserScope <> invalid, "stale connection polling has no effects on a successor request lifecycle")
    rosterControllerFixture(scope)
    expected = dispatcharrAuthorizationSignature(m.profileRosterContext.verified.verifiedUser)
    m.task.expectedAuthorizationSignature = expected
    result = {ok: true, verifiedUser: copyPreferenceValue(m.profileRosterContext.verified.verifiedUser)}
    m.profileRosterContext = invalid
    check(acceptProfileRosterLineupAuthority(result, m.task) and m.activeUserScope <> invalid and not m.global.profilegateclosed, "matching final Task authority leaves its own one-shot admission intact")
    result.verifiedUser.user_level = 10
    check(not acceptProfileRosterLineupAuthority(result, m.task) and m.activeUserScope = invalid and m.global.profilegateclosed and m.profileRosterGrant = invalid and m.task = invalid, "Scene independently refuses a nominally successful final result under different protection authority")
    rosterControllerFixture(scope)
    m.profileRosterContext = invalid
    m.task.expectedAuthorizationSignature = expected
    check(not acceptProfileRosterLineupAuthority({ok: false, protectionAuthorityChanged: true, relogin: false}, m.task) and m.setupCalls = 0 and m.connectCalls = 0 and m.global.profilegateclosed and m.activeUserScope = invalid, "Task authority-change failure stays covered, never opens generic setup or a credential-rejection path")
    rosterControllerFixture(scope)
    m.profileRosterContext = invalid
    m.task.expectedAuthorizationSignature = expected
    m.activeUserScope = setCanonicalPreference(scope, "sessionId", "successor-actor")
    check(not acceptProfileRosterLineupAuthority({ok: false, protectionAuthorityChanged: true}, m.task) and m.activeUserScope.sessionId = "successor-actor" and not m.global.profilegateclosed and m.preserved = 0 and m.cancelled = 0, "an old final-result flag cannot cover or retire a different actual actor even if the global nonce has not yet changed")
    print "ALL TESTS PASSED"
end sub

sub rosterControllerFixture(scope as object)
    m.activeUserScope = scope
    m.selectedConnectionId = "slot-a"
    m.userProfileStore = {active: "profile-a", profiles: [{id: "profile-a"}]}
    user = {id: 7, username: "Alice", user_level: 1, stream_limit: 2, channel_profiles: [1], custom_properties: {vod_movies_enabled: true}}
    m.profileRosterContext = {scope: scope, connection: {id: "slot-a", url: "https://example.test"}, verified: {apiKey: "own-key", accountId: "7", accountUsername: "Alice", verifiedUser: user}}
    m.task = {aeriosession: scope.sessionId, unobserveField: sub(field as string)
    end sub}
    m.testGate = {allowed: true}
    m.profileRosterGrant = invalid
    m.profileRosterEnabled = true
    m.pullCommits = 0
    m.connectCalls = 0
    m.pinCalls = 0
    m.setupCalls = 0
    m.pullFailure = false
    m.global = {activeusersession: scope.sessionId, profilegateclosed: false, profileswitchpending: false}
    m.profileGateCover = {visible: false}
    m.guide = {active: false}
    m.top = {label: {}, findNode: function(id as string) as object
        return m.label
    end function, hasField: function(field as string) as boolean
        return false
    end function, getChildren: function(count as integer, first as integer) as object
        return []
    end function}
    m.userProfileRecoveryRequired = false
    m.playingChannel = invalid
    m.preserved = 0
    m.cancelled = 0
    m.apiKey = "own-key"
end sub

function rosterControllerRead() as object
    return {ok: true, state: "ready", profilesState: "ready", accountId: "7", accountUsername: "Alice", verifiedBaseUrl: "https://example.test", verifiedUser: copyJson(m.profileRosterContext.verified.verifiedUser), data: {categories: {profiles: {data: {}}}}}
end function

sub preserveSubmittedRecording()
    m.preserved++
    m.preservedWithScope = m.activeUserScope <> invalid
end sub

sub cancelRecordFlow()
    m.cancelled++
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
