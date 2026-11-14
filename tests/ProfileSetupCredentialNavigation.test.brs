sub main()
    setupProofFixture()
    check(beginProfileSetupCredential(m.task, m.fixtureEntry), "default setup captures explicit password lifecycle")
    result = setupProofResult()
    check(resolveProfileSetupCredential(result) and m.profileSetupCredentialHold <> invalid and not m.fixtureCompleted, "same-key password proof waits before roster or adoption")
    ticket = m.profileSetupCredentialHold
    check(ticket.hash = string(64, "a") and ticket.holdVersion = 1 and ticket.apiKey = invalid, "broker mailbox contains only captured digest facts")
    onProfileSetupCredentialResolved(setupProofEvent(ticket, {allowed: true}))
    check(m.fixtureCompleted and m.profileSetupCredentialContext = invalid and m.global.profileownsigninnonce = "", "accepted proof retires credential lifecycle before ordinary roster continuation")
    setupProofFixture()
    beginProfileSetupCredential(m.task, m.fixtureEntry)
    result = setupProofResult()
    result.accountId = "99"
    check(resolveProfileSetupCredential(result) and m.fixtureFailed and m.profileSetupCredentialHold = invalid, "account replacement cannot clear an existing holder hash")
    setupProofFixture()
    beginProfileSetupCredential(m.task, m.fixtureEntry)
    m.registry.data = "changed-PIN"
    check(resolveProfileSetupCredential(setupProofResult()) and m.fixtureFailed, "changed roster or PIN refuses stale setup proof")
    setupProofFixture()
    beginProfileSetupCredential(m.task, m.fixtureEntry)
    resolveProfileSetupCredential(setupProofResult())
    ticket = m.profileSetupCredentialHold
    retireProfileSetupCredential()
    onProfileSetupCredentialResolved(setupProofEvent(ticket, {allowed: true}))
    check(not m.fixtureCompleted and m.global.profileownsigninnonce = "", "cancelled setup never adopts late broker acknowledgement")
    setupProofFixture()
    beginProfileSetupCredential(m.task, m.fixtureEntry)
    resolveProfileSetupCredential(setupProofResult())
    m.profileSetupCredentialClock = {totalMilliseconds: function() as integer
        return 6000
    end function}
    tickProfileSetupCredential()
    check(m.fixtureFailed and m.profileSetupCredentialContext = invalid, "lost setup acknowledgement has a bounded wait")
    setupProofFixture()
    m.fixtureStore.profiles[0].role = "child"
    check(not beginProfileSetupCredential(m.task, m.fixtureEntry), "Child never borrows general default setup")
    setupProofFixture()
    m.fixtureStore.profiles[0].isDefault = false
    check(not beginProfileSetupCredential(m.task, m.fixtureEntry), "non-default recovery remains on its own form")
    setupProofFixture()
    beginProfileSetupCredential(m.task, m.fixtureEntry)
    m.requestGate.snapshot.keys = {}
    result = setupProofResult()
    result.accountId = "99"
    check(not resolveProfileSetupCredential(result) and not m.fixtureFailed, "ordinary different-key default replacement stays with existing identity fences")
    setupProofFixture()
    beginProfileSetupCredential(m.task, m.fixtureEntry)
    m.requestGate.snapshot.keys[string(64, "a")].version = 2
    check(resolveProfileSetupCredential(setupProofResult()) and m.fixtureFailed, "new rejection generation refuses old setup password proof")
    setupProofFixture()
    beginProfileSetupCredential(m.task, m.fixtureEntry)
    m.fixtureEntry.url = "https://changed.test"
    check(resolveProfileSetupCredential(setupProofResult()) and m.fixtureFailed, "connection replacement cannot inherit credential admission")
    setupProofFixture()
    beginProfileSetupCredential(m.task, m.fixtureEntry)
    m.task = {id: "successor"}
    check(resolveProfileSetupCredential(setupProofResult()) and m.fixtureFailed, "replaced verification Task cannot donate a password proof")
    setupProofFixture()
    beginProfileSetupCredential(m.task, m.fixtureEntry)
    result = setupProofResult()
    result.verifiedBaseUrl = "https://elsewhere.test"
    check(resolveProfileSetupCredential(result) and m.fixtureFailed, "proof must come from submitted current address")
    print "ALL TESTS PASSED"
end sub

sub setupProofFixture()
    m.fixtureEntry = {id: "slot-a", provider: "dispatcharr", url: "https://example.test"}
    m.fixtureStore = {active: "default", readOnly: false, profiles: [{id: "default", isDefault: true, role: "user", userId: 7, username: "Alice"}]}
    m.connectionStore = {}
    m.selectedConnectionId = "slot-a"
    m.baseUrl = "https://example.test"
    m.authMode = "password"
    m.username = "Alice"
    m.password = "private-password"
    m.apiKey = ""
    m.activeUserScope = invalid
    m.page = "setup"
    m.global = {activeusersession: "", profileownsigninpending: false, profileownsigninnonce: ""}
    m.registry = {data: "roster-PIN", read: function(key as string) as string
        return m.data
    end function}
    m.requestGate = {snapshot: {keys: {} }}
    m.requestGate.snapshot.keys[string(64, "a")] = {version: 1}
    m.task = {id: "verify", isSameNode: function(other as object) as boolean
        return m.id = other.id
    end function}
    m.profileSetupCredentialContext = invalid
    m.profileSetupCredentialHold = invalid
    m.profileSetupCredentialTicketFactory = function() as object
        return {id: "proof", observeField: sub(field as string, callback as string)
        end sub, unobserveField: sub(field as string)
        end sub, isSameNode: function(other as object) as boolean
            return m.id = other.id
        end function}
    end function
    m.fixtureFailed = false
    m.fixtureCompleted = false
end sub

function setupProofResult() as object
    return {ok: true, phase: "verified", apiKey: "returned-key", accountId: "7", accountUsername: "Alice", verifiedBaseUrl: "https://example.test", verifiedUser: {id: 7, username: "Alice"}}
end function

function connectionStoreEntry(store as object, id as string) as object
    return m.fixtureEntry
end function

function loadUserProfileStore(registry as object, id as string) as object
    return m.fixtureStore
end function

function userProfileStoreKey(id as string) as string
    return "roster"
end function

function requestGateCredentialHash(key as string) as string
    return string(64, "a")
end function

sub failConnection(message as string)
    m.fixtureFailed = true
    retireProfileSetupCredential()
end sub

sub completeConnection(result as object)
    m.fixtureCompleted = true
end sub

function setupProofEvent(node as object, value as object) as object
    return {node: node, value: value, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as object
        return m.value
    end function}
end function

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
