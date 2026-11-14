sub main()
    switchRosterFixture()
    before = FormatJson(m.store)
    plan = switchRosterPlan(m.remote)
    check(plan.ok and plan.applied and plan.store.active = m.store.active and plan.target.pinType = "numbers" and plan.pinChanged, "target own roster can stage new protection without adopting its session or active selection")
    check(FormatJson(m.store) = before and not plan.outgoingProtectionChanged, "staging leaves the captured outgoing store and authority immutable")
    check(plan.suggestions.count() = 1 and plan.store.profiles.count() = 2 and plan.apiKey = invalid, "staging offers unknown users without auto-adding or returning credentials")
    switchRosterFixture()
    m.verified.verifiedUser.id = 80
    check(not switchRosterPlan(m.remote).ok, "foreign own-user proof cannot stage another target's PIN")
    switchRosterFixture()
    m.verified.verifiedBaseUrl = "https://other.test"
    check(not switchRosterPlan(m.remote).ok, "staging cannot borrow proof from another current address")
    switchRosterFixture()
    m.verified.phase = "lineup"
    check(not switchRosterPlan(m.remote).ok, "only explicit authentication-stage proof enters early protection staging")
    switchRosterFixture()
    m.activeNonce = "00000000-0000-4000-8000-000000000099"
    check(not switchRosterPlan(m.remote).ok, "retired incoming nonce rejects a delayed own roster")
    switchRosterFixture()
    m.nonce = m.outgoing.sessionId
    m.activeNonce = m.nonce
    check(not switchRosterPlan(m.remote).ok, "an outgoing session ID is not an incoming switch admission nonce")
    switchRosterFixture()
    m.activeOutgoing = setCanonicalPreference(m.outgoing, "sessionId", "00000000-0000-4000-8000-000000000098")
    check(not switchRosterPlan(m.remote).ok, "A/B/A outgoing replacement rejects old roster staging")
    switchRosterFixture()
    m.store.profiles[1].role = "child"
    plan = switchRosterPlan(m.remote)
    check(plan.ok and not plan.applied and plan.target.role = "child" and plan.target.pinType = "none" and plan.suggestions.count() = 0, "fresh Child authority never applies remote roles PINs or suggestions")
    m.verified.verifiedUser.user_level = 10
    plan = switchRosterPlan(m.remote)
    check(plan.ok and plan.applied and plan.target.role = "admin", "verified upstream Admin facts cannot be demoted by a stale local Child choice")
    switchRosterFixture()
    m.store.profiles[0].role = "child"
    plan = switchRosterPlan(m.remote)
    check(plan.ok and plan.applied and plan.target.pinType = "numbers", "staging uses the authenticated adult target's import policy, never fabricates an active adult session for the outgoing Child")
    switchRosterFixture()
    m.enabled = false
    plan = switchRosterPlan(m.remote)
    check(plan.ok and not plan.applied and plan.target.pinType = "none", "Profiles-Off never imports protection during target staging")
    switchRosterFixture()
    m.store.pendingRoster = true
    plan = switchRosterPlan(m.remote)
    check(not plan.ok and plan.reason = "outgoing-pending", "early staging cannot silently discard an outgoing roster edit before writer settlement exists")
    switchRosterFixture()
    m.store.profiles[0].addressHeld = false
    m.store.profiles[1].addressHeld = true
    check(not switchRosterPlan(m.remote).ok, "address-held target requires its own recovery before roster staging")
    switchRosterFixture()
    c = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000003", {id: 9, username: "held", user_level: 1}, 1)
    c.isDefault = false
    c.addressHeld = true
    m.store.profiles.push(c)
    plan = switchRosterPlan(m.remote)
    check(plan.ok and not plan.applied and plan.suggestions.count() = 0 and plan.target.pinType = "none", "another held profile pauses the category rather than making target staging an import escape")
    switchRosterFixture()
    remote = dispatcharrSyncRosterDecode({rows: [[80, "bob", "Foreign Bob", "none", "", "", "user", 500]]})
    check(not switchRosterPlan(remote).ok, "same-username wire row with a foreign numeric identity cannot donate protection")
    check(not switchRosterPlan({ok: false}).ok, "malformed target roster remains unapplied for explicit controller failure policy")
    switchRosterFixture()
    remote = dispatcharrSyncRosterDecode({rows: [], removed: [["bob", 500]]})
    plan = switchRosterPlan(remote)
    check(not plan.ok and plan.reason = "target-removed" and FormatJson(plan.store) = FormatJson(m.store), "target tombstone cannot be adopted or delete a running target during staging")
    switchRosterFixture()
    m.store.active = m.store.profiles[1].id
    m.targetId = m.store.profiles[0].id
    m.outgoing = userProfileSessionScope(m.connection, m.store.active, "8", "old", "00000000-0000-4000-8000-000000000090")
    m.activeOutgoing = m.outgoing
    m.verified = {ok: true, phase: "verified", apiKey: "synthetic-a", accountId: "7", accountUsername: "alice", verifiedBaseUrl: m.connection.url, verifiedUser: {id: 7, username: "alice", user_level: 1}}
    plan = switchRosterPlan(remote)
    check(not plan.ok and plan.needsDefaultSwitch and plan.reason = "outgoing-removal", "outgoing tombstone requires explicit authenticated default-retirement integration, not incidental cleanup")
    switchRosterFixture()
    remote = dispatcharrSyncRosterDecode({rows: [[7, "alice", "Alice", "none", "", "", "child", 500]]})
    plan = switchRosterPlan(remote)
    check(plan.ok and plan.outgoingProtectionChanged and plan.store.active = m.store.active, "changed outgoing protection is surfaced rather than blessed as a new rollback snapshot")
    print "ALL TESTS PASSED"
end sub

sub switchRosterFixture()
    m.connection = normalizeConnectionEntry({id: "slot-a", name: "Fixture", provider: "dispatcharr", url: "https://example.test", remember: true})
    a = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "alice", user_level: 1}, 1)
    b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "bob", user_level: 1}, 1)
    b.isDefault = false
    m.store = defaultUserProfileStore("slot-a")
    m.store.profiles = [a, b]
    m.store.active = a.id
    m.targetId = b.id
    m.outgoing = userProfileSessionScope(m.connection, a.id, "7", "old", "00000000-0000-4000-8000-000000000090")
    m.activeOutgoing = m.outgoing
    m.nonce = "00000000-0000-4000-8000-000000000091"
    m.activeNonce = m.nonce
    m.enabled = true
    m.verified = {ok: true, phase: "verified", apiKey: "synthetic-b", accountId: "8", accountUsername: "bob", verifiedBaseUrl: m.connection.url, verifiedUser: {id: 8, username: "bob", user_level: 1}}
    m.remote = dispatcharrSyncRosterDecode({rows: [[8, "bob", "Bob remote", "numbers", string(64, "a"), string(32, "b"), "user", 500], [9, "new", "New", "none", "", "", "user", 500]]})
end sub

function switchRosterPlan(decoded as object) as object
    return dispatcharrSyncSwitchRosterPlan(m.connection, m.store, m.targetId, m.verified, decoded, m.enabled, 600, m.nonce, m.activeNonce, m.outgoing, m.activeOutgoing)
end function

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
