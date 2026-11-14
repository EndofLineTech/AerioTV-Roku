sub main()
    unavailableRosterFixture()
    before = FormatJson(m.store)
    result = unavailableRosterPlan()
    check(result.ok and result.applied and result.store.active = m.store.active and result.target.pinHash = string(64, "c") and result.pinChanged, "adult-purpose no-session admission can stage target own imported protection without activating it")
    check(FormatJson(m.store) = before and not result.outgoingProtectionChanged and result.apiKey = invalid and result.scope = invalid, "pure unavailable staging neither mutates its Child input nor fabricates a credential/scope")
    for each mismatch in ["scope", "key", "grant", "management-nonce", "incoming-nonce", "role", "identity", "address", "pending"]
        unavailableRosterFixture()
        if mismatch = "scope" then m.actor = userProfileSessionScope(m.connection, m.store.active, "7", "old", "00000000-0000-4000-8000-000000000090")
        if mismatch = "key" then m.actorKey = "retained-but-not-unavailable"
        if mismatch = "grant" then m.management.pinHash = string(64, "f")
        if mismatch = "management-nonce" then m.managementNonce = "00000000-0000-4000-8000-000000000099"
        if mismatch = "incoming-nonce" then m.activeNonce = "00000000-0000-4000-8000-000000000099"
        if mismatch = "role" then m.store.profiles[0].role = "user"
        if mismatch = "identity" then m.verified.verifiedUser.username = "foreign"
        if mismatch = "address" then m.verified.verifiedBaseUrl = "https://foreign.test"
        if mismatch = "pending" then m.store.pendingRoster = true
        before = FormatJson(m.store)
        result = unavailableRosterPlan()
        check(not result.ok and FormatJson(m.store) = before, "unavailable staging refuses changed " + mismatch + " without a synthetic actor or lost data")
    end for
    unavailableRosterFixture()
    m.store.profiles[0] = setCanonicalPreference(m.store.profiles[0], "isDefault", false)
    m.store.profiles[1] = setCanonicalPreference(m.store.profiles[1], "isDefault", true)
    m.store.profiles[0] = setCanonicalPreference(m.store.profiles[0], "addressHeld", true)
    result = unavailableRosterPlan()
    check(result.ok and not result.applied and result.target.pinHash = string(64, "a"), "an address-held Child still pauses every slot roster application instead of bypassing the hold through another target")
    unavailableRosterFixture()
    m.store.profiles[0] = setCanonicalPreference(m.store.profiles[0], "isDefault", false)
    m.store.profiles[1] = setCanonicalPreference(m.store.profiles[1], "isDefault", true)
    m.decoded = dispatcharrSyncRosterDecode({rows: [], removed: [["alice", 900]]})
    result = unavailableRosterPlan()
    check(not result.ok and result.needsDefaultSwitch, "unavailable active Child tombstone stays pending for explicit default retirement")
    unavailableRosterFixture()
    m.decoded = dispatcharrSyncRosterDecode({rows: [[7, "alice", "Alice", "none", "", "", "user", 900]]})
    result = unavailableRosterPlan()
    check(result.ok and result.outgoingProtectionChanged, "staged changes to unavailable Child protection are surfaced for current adult-purpose revalidation, never blessed as old admission")
    print "ALL TESTS PASSED"
end sub

sub unavailableRosterFixture()
    m.connection = normalizeConnectionEntry({id: "slot-a", name: "Fixture", provider: "dispatcharr", url: "https://example.test", remember: true})
    child = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "alice", user_level: 1}, 1)
    child.role = "child"
    adult = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "bob", user_level: 1}, 1)
    adult = setCanonicalPreference(adult, "isDefault", false)
    adult = setCanonicalPreference(adult, "pinType", "numbers")
    adult = setCanonicalPreference(adult, "pinHash", string(64, "a"))
    adult = setCanonicalPreference(adult, "pinSalt", string(32, "b"))
    m.store = defaultUserProfileStore("slot-a")
    m.store.profiles = [child, adult]
    m.store.active = child.id
    m.targetId = adult.id
    m.nonce = "00000000-0000-4000-8000-000000000091"
    m.activeNonce = m.nonce
    m.actor = invalid
    m.actorKey = ""
    m.managementNonce = "00000000-0000-4000-8000-000000000092"
    m.management = {slot: "slot-a", active: child.id, nonce: m.managementNonce, purpose: "manage-profiles", kind: "pin", id: adult.id, pinType: adult.pinType, pinHash: adult.pinHash, pinSalt: adult.pinSalt}
    m.verified = {ok: true, phase: "verified", verifiedBaseUrl: m.connection.url, apiKey: "synthetic-b", accountId: "8", accountUsername: "bob", verifiedUser: {id: 8, username: "bob", user_level: 1}}
    m.decoded = dispatcharrSyncRosterDecode({rows: [[8, "bob", "Bob", "numbers", string(64, "c"), string(32, "d"), "user", 500]]})
end sub

function unavailableRosterPlan() as object
    return dispatcharrSyncUnavailableChildRosterPlan(m.connection, m.store, m.targetId, m.verified, m.decoded, true, 600, m.nonce, m.activeNonce, m.actor, m.actorKey, invalid, m.management, m.managementNonce)
end function

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
