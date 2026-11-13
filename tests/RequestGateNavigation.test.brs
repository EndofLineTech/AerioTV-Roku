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
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
