sub main()
    for each fault in ["", "write", "flush", "rollback"]
        syncAckFixture()
        m.registry.fault = fault
        before = FormatJson(m.registry.values)
        result = commitDispatcharrSyncRosterAck(m.registry, m.connection, m.store, m.receipt, m.scope, m.key, {})
        if fault = ""
            check(result.ok and not result.store.pendingRoster and m.registry.flushes = 1, "successful own 200 clears pending and stores highwater in one atomic transaction")
            ack = loadDispatcharrSyncRosterAck(m.registry, m.connection)
            check(ack.ok and ack.stamp = 100 and instr(1, m.registry.read(userProfileSyncAckKey("slot-a")), "synthetic-own") = 0 and m.registry.read("connKey_slot-a") = "synthetic-own", "ack records metadata only, never credentials, and retains the own key")
        else
            check(not result.ok and result.recoveryRequired = (fault = "rollback") and FormatJson(m.registry.values) = before, "ack transaction faults restore exact dirty root and previous ack")
        end if
    end for
    for each change in ["scope", "generation", "root", "connection", "key", "held", "status", "not-submitted", "digest", "future-ack", "malformed-ack"]
        syncAckFixture()
        if change = "scope" then m.scope = setCanonicalPreference(m.scope, "sessionId", "00000000-0000-4000-8000-000000000091")
        if change = "generation" then m.scope = setCanonicalPreference(m.scope, "authorizationGeneration", "successor-generation")
        if change = "root" then m.registry.values[userProfileStoreKey("slot-a")] += " "
        if change = "connection" then m.registry.values["connectionsV1"] += " "
        if change = "key"
            m.registry.values["connKey_slot-a"] = "successor-key"
            m.key = "successor-key"
        end if
        if change = "held" then m.held = true
        if change = "status" then m.receipt.ok = false
        if change = "not-submitted" then m.receipt.submitted = false
        if change = "digest" then m.receipt.credentialHash = string(64, "b")
        if change = "future-ack" then m.registry.values[userProfileSyncAckKey("slot-a")] = "{""schema"":2}"
        if change = "malformed-ack" then m.registry.values[userProfileSyncAckKey("slot-a")] = ""
        before = FormatJson(m.registry.values)
        result = commitDispatcharrSyncRosterAck(m.registry, m.connection, m.store, m.receipt, m.scope, m.key, {})
        check(not result.ok and m.registry.flushes = 0 and FormatJson(m.registry.values) = before, "late acknowledgement cannot clear pending after changed " + change)
    end for
    syncAckFixture()
    m.registry.values[userProfileSyncAckKey("slot-a")] = "{""schema"":1,""playlistId"":""slot-a"",""baseUrl"":""https://example.test"",""maximumSentStamp"":200}"
    result = commitDispatcharrSyncRosterAck(m.registry, m.connection, m.store, m.receipt, m.scope, m.key, {})
    check(result.ok and loadDispatcharrSyncRosterAck(m.registry, m.connection).stamp = 200, "late lower highwater cannot regress an existing successful acknowledgement")
    print "ALL TESTS PASSED"
end sub

sub syncAckFixture()
    connections = connectionStoreAdd(defaultConnectionStore(), "slot-a", "Synthetic")
    connections = connectionStoreUpdate(connections, "slot-a", {url: "https://example.test", accountId: "7", remember: true})
    m.connection = connectionStoreEntry(connections, "slot-a")
    profile = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "Alice", user_level: 1}, 1)
    m.store = defaultUserProfileStore("slot-a")
    m.store.profiles = [profile]
    m.store.active = profile.id
    m.store.pendingRoster = true
    m.scope = userProfileSessionScope(m.connection, profile.id, 7, "own-generation", "00000000-0000-4000-8000-000000000090")
    m.key = "synthetic-own"
    m.held = false
    values = {connectionsV1: FormatJson(connections)}
    values["connKey_slot-a"] = m.key
    values[userProfileStoreKey("slot-a")] = FormatJson(m.store)
    m.receipt = {ok: true, state: "written", submitted: true, scope: m.scope, storeRoot: values[userProfileStoreKey("slot-a")], connectionRoot: values.connectionsV1, credentialHash: string(64, "a"), maximumSentStamp: 100}
    m.registry = {values: values, fault: "", failed: false, flushes: 0
        exists: function(key as string) as boolean
            return m.values.doesExist(key)
        end function
        read: function(key as string) as string
            if not m.values.doesExist(key) then return ""
            return m.values[key]
        end function
        write: function(key as string, value as string) as boolean
            if m.fault = "write" and not m.failed then m.failed = true : return false
            m.values[key] = value
            return true
        end function
        delete: function(key as string) as boolean
            m.values.delete(key)
            return true
        end function
        flush: function() as boolean
            m.flushes++
            if m.fault = "rollback" then return false
            if m.fault = "flush" and not m.failed then m.failed = true : return false
            return true
        end function
    }
end sub

function requestGateCredentialHash(key as string) as string
    if key = "synthetic-own" then return string(64, "a")
    return string(64, "b")
end function

function requestGateAccessAllowed(url as string, key as string) as boolean
    return not m.held
end function

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
