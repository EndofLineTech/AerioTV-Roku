sub main()
    prompt = {unobserved: false, unobserveField: sub(field as string)
        m.unobserved = true
    end sub}
    recheck = {unobserved: false, cancelRequested: false, unobserveField: sub(field as string)
        m.unobserved = true
    end sub}
    m.requestGatePrompt = prompt
    m.requestGateRecheck = recheck
    m.requestGateBinding = {slot: "slot-a", key: "retired-key"}
    retireProfileRequestBinding()
    check(prompt.unobserved and recheck.unobserved and recheck.cancelRequested, "profile retirement detaches prompt and cancels owned recheck")
    check(m.requestGatePrompt = invalid and m.requestGateRecheck = invalid and m.requestGateBinding = invalid, "same-slot A/B/A cannot revive an outgoing raw-key binding")
    m.global = {profileswitchpending: true}
    rememberHeldRequestGateBinding()
    check(m.requestGateBinding = invalid, "broker snapshots cannot recreate an outgoing binding under the incoming staging session")
    m.global.profileswitchpending = false
    m.baseUrl = "https://example.test"
    m.selectedConnectionId = "slot-a"
    entry = {id: "slot-a", provider: "dispatcharr", url: m.baseUrl, accountId: "7"}
    m.scopedPreferencesRequired = true
    m.global.activeusersession = "session-b"
    m.activeUserScope = {playlistId: "slot-a", accountId: "8", profileId: "profile-b", sessionId: "session-b", preferenceIdentity: connectionPreferenceIdentity(entry, "8")}
    m.userProfileStore = {playlistId: "slot-a", active: "profile-b", profiles: [{id: "profile-b", userId: 8, username: "Bob"}]}
    owner = currentRequestGateOwner(entry)
    check(owner.account = "8" and owner.profile = "profile-b" and owner.username = "Bob", "held non-default key rechecks against its actual holder, never the slot default account")
    m.userProfileStore.active = "profile-a"
    check(currentRequestGateOwner(entry) = invalid, "changed roster active identity cannot borrow an outgoing profile's slow recheck")
    m.userProfileStore.active = "profile-b"
    m.userProfileStore.playlistId = "slot-b"
    check(currentRequestGateOwner(entry) = invalid, "a foreign slot roster cannot label an active key even with matching account and profile IDs")
    m.userProfileStore.playlistId = "slot-a"
    m.baseUrl = "https://other.test"
    check(currentRequestGateOwner(entry) = invalid, "a stale server binding cannot pair the current holder key with a different address")
    m.baseUrl = entry.url
    m.activeUserScope.sessionId = "old-session-b"
    check(currentRequestGateOwner(entry) = invalid, "retired authenticated scope cannot label a new held-key binding")
    m.activeUserScope = invalid
    check(currentRequestGateOwner(entry) = invalid, "missing scoped authority cannot create a default-account hold binding")
    m.scopedPreferencesRequired = false
    check(currentRequestGateOwner(entry).account = "7", "legacy default setup retains its explicit account expectation")
    nonce = "00000000-0000-4000-8000-000000000091"
    profileId = "00000000-0000-4000-8000-000000000002"
    held = {slot: entry.id, base: entry.url, key: "synthetic-held-own", hash: string(64, "a"), account: "8", username: "Bob", profile: profileId, session: "retired-authenticated-session"}
    store = {playlistId: entry.id, active: profileId, profiles: [{id: profileId, userId: 8, username: "BOB", role: "child", addressHeld: false}]}
    recovered = unavailableRequestGateBinding(held, entry, store, nonce)
    check(recovered <> invalid and recovered.recoveryNonce = nonce and recovered.profile = profileId and recovered.account = "8" and recovered.key = "synthetic-held-own" and not recovered.doesExist("session"), "same-holder recovery keeps an explicit memory-only probe binding without an authenticated outgoing session")
    store.profiles[0].addressHeld = true
    check(unavailableRequestGateBinding(held, entry, store, nonce) = invalid, "address-held Child never gains a rejected-key slow probe")
    store.profiles[0].addressHeld = false
    store.profiles[0].username = "OtherBob"
    check(unavailableRequestGateBinding(held, entry, store, nonce) = invalid, "same user ID with another username cannot inherit a recovery probe")
    store.profiles[0].username = "Bob"
    held.base = "https://old.test"
    check(unavailableRequestGateBinding(held, entry, store, nonce) = invalid, "changed-address holder cannot inherit an old credential probe")
    held.base = entry.url
    store.active = "other-profile"
    check(unavailableRequestGateBinding(held, entry, store, nonce) = invalid, "inactive holder cannot keep a background probe after a switch")
    store.active = profileId
    check(unavailableRequestGateBinding(held, entry, store, "") = invalid, "recovery probe requires its own fresh lifecycle identifier")
    m.global = {profilegateclosed: true, activeusersession: "", requestgaterecovery: nonce, profileswitchpending: false, profileownsigninpending: false}
    m.top = {recoveryNonce: nonce, aeriosession: "retired-session", baseUrl: entry.url, subtype: function() as string
        return "RequestGateRecheckTask"
    end function}
    check(requestGateTaskSessionCurrent() and requestGateRecoveryProbeCurrent(), "only the exact recovery probe can run behind a still-closed content gate without an authenticated session")
    check(not requestGateAcquire(entry.url + "/api/channels/channels/", "synthetic-held-own", true).allowed, "recovery nonce never authorizes a lineup or other account request")
    check(not requestGateAcquire(entry.url + "/api/accounts/users/me/", "synthetic-held-own", false).allowed, "recovery transport always requires the broker's slow-probe permit")
    m.top.recoveryNonce = "00000000-0000-4000-8000-000000000092"
    check(not requestGateTaskSessionCurrent(), "retired recovery nonce cannot reuse the closed-gate exception")
    m.top.recoveryNonce = nonce
    m.top.subtype = function() as string
        return "DispatcharrTask"
    end function
    check(not requestGateTaskSessionCurrent(), "a generic authentication Task cannot claim the recovery-probe exception")
    m.top.subtype = function() as string
        return "RequestGateRecheckTask"
    end function
    m.global.profileswitchpending = true
    check(not requestGateTaskSessionCurrent(), "switch staging retires the unavailable holder's in-flight recovery probe")
    m.global.profileswitchpending = false
    m.global.profileownsigninpending = true
    check(not requestGateTaskSessionCurrent(), "own credential form lifecycle also retires the old recovery probe")
    m.global.profileownsigninpending = false
    m.global.activeusersession = "new-authenticated-session"
    check(not requestGateTaskSessionCurrent(), "an authenticated successor session cannot inherit an unavailable-holder probe exception")
    m.global = {profilegateclosed: false, profileswitchpending: false}
    m.connectionStore = {schema: 1, selected: entry.id, entries: [entry]}
    m.selectedConnectionId = entry.id
    m.baseUrl = entry.url
    m.scopedPreferencesRequired = true
    m.activeUserScope = invalid
    m.apiKey = "synthetic-new-unheld-key"
    m.requestGate = {snapshot: requestGateDefault()}
    m.requestGateBinding = {slot: entry.id, base: entry.url, key: "synthetic-retired-key", hash: string(64, "a")}
    rememberHeldRequestGateBinding()
    check(m.requestGateBinding = invalid, "an unverified current holder cannot carry a previous raw-key binding across identity-error recovery")
    m.fixtureCachedRole = "child"
    m.fixtureSelectedChild = false
    m.fixtureChildRecovery = false
    m.fixtureGenericPrompt = false
    m.connectionStore.entries[0].name = "Synthetic"
    ticket = {id: "child-prompt", isSameNode: function(other as object) as boolean
        return m.id = other.id
    end function, unobserveField: sub(field as string)
    end sub}
    m.requestGatePrompt = ticket
    m.requestGateBinding = {slot: entry.id, base: entry.url, username: "Kid"}
    event = {node: ticket, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as object
        return {show: true}
    end function}
    onRequestGatePrompt(event)
    check(m.fixtureChildRecovery and not m.fixtureGenericPrompt, "a verified Child's cached authority still enters covered recovery when fresh roster metadata becomes unreadable")
    print "ALL TESTS PASSED"
end sub

function currentUserSettingsRole() as string
    return m.fixtureCachedRole
end function

function selectedUserProfileIsChild() as boolean
    return m.fixtureSelectedChild
end function

sub requireConnectionRelogin(message as string)
    m.fixtureChildRecovery = true
end sub

sub openConnectionDialog(title as string, message as string, choices as object)
    m.fixtureGenericPrompt = true
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
