sub main()
    for each failure in ["key-write", "key-flush", "roster-write", ""]
        registry = importRegistry()
        old = registry.read("connectionsV1")
        before = normalizeConnectionStore(parseJson(old))
        staged = copyJson(before)
        staged.entries[0].name = "Replacement"
        registry.failure = failure
        result = phoneSetupCommitConnection(registry, before, staged, "new-key")
        if failure = ""
            check(result.ok, "successful atomic credential/roster commit")
            check(registry.flushes = 1 and registry.transactions.count() = 1, "key and roster use exactly one atomic Flush")
            transaction = registry.transactions[0]
            check(transaction["connKey_saved"] = "new-key" and instr(1, transaction["connectionsV1"], "Replacement") > 0, "same durable snapshot contains both changes")
            check(instr(1, registry.read("connectionsV1"), "new-key") = 0, "roster contains no credential")
        else
            check(not result.ok and not result.recoveryRequired, "transient write/flush failures are rolled back")
            check(registry.read("connectionsV1") = old, "failed write/flush restores cached roster")
            check(registry.read("connKey_saved") = "old-key", "failed write/flush restores cached credential")
            check(registry.durable["connectionsV1"] = old and registry.durable["connKey_saved"] = "old-key", "durable state never contains a mixed old/new pair")
        end if
        check(before.entries[0].name = "Original" and staged.entries[0].name = "Replacement", "commit does not mutate caller stores")
    end for
    registry = importRegistry()
    before = normalizeConnectionStore(parseJson(registry.read("connectionsV1")))
    registry.failure = "rollback"
    recovery = phoneSetupCommitConnection(registry, before, before, "new-key")
    check(not recovery.ok and recovery.recoveryRequired, "failed rollback explicitly requires recovery")
    registry = importRegistry()
    before = normalizeConnectionStore(parseJson(registry.read("connectionsV1")))
    check(not phoneSetupCommitConnection(registry, before, before, "").ok and registry.flushes = 0, "missing verified key cannot be committed")
    staged = copyJson(before)
    staged.entries[0].remember = false
    check(phoneSetupCommitConnection(registry, before, staged, "").ok, "session-only choice commits roster and key removal atomically")
    check(registry.flushes = 1 and registry.read("connKey_saved") = "", "session-only commit removes old credential in same transaction")
    registry = importRegistry()
    before = normalizeConnectionStore(parseJson(registry.read("connectionsV1")))
    changed = copyJson(before)
    changed.entries[0].name = "Concurrent edit"
    registry.write("connectionsV1", formatJson(changed))
    check(not phoneSetupCommitConnection(registry, before, before, "new-key").ok and registry.flushes = 0, "stale roster snapshot cannot overwrite another edit")
    registry = importRegistry()
    before = normalizeConnectionStore(parseJson(registry.read("connectionsV1")))
    before.entries[0].id = "legacy"
    before.selected = "legacy"
    registry.values = {apiKey: "legacy-key"}
    registry.write("connKey_legacy", "old-key")
    registry.write("connectionsV1", formatJson(before))
    registry.durable = {}
    registry.durable.append(registry.values)
    registry.failure = "key-flush"
    check(not phoneSetupCommitConnection(registry, before, before, "new-key").ok, "legacy failed commit reported")
    check(registry.read("apiKey") = "legacy-key" and registry.read("connKey_legacy") = "old-key", "legacy aliases restored together on failure")
    check(phoneSetupCommitConnection(registry, before, before, "new-key").ok, "legacy import can commit after recovery")
    check(registry.read("apiKey") = "" and registry.read("connKey_legacy") = "new-key", "legacy fallback removed in successful transaction")
    print "ALL TESTS PASSED"
end sub

function importRegistry() as object
    entry = normalizeConnectionEntry({id: "saved", name: "Original", provider: "dispatcharr", url: "https://example.test", accountId: "7", remember: true})
    registry = {values: {}, failure: "", flushes: 0, transactions: []
        read: function(key as string) as string
            if not m.values.doesExist(key) then return ""
            return m.values[key]
        end function
        write: function(key as string, value as string) as boolean
            if (m.failure = "key-write" and left(key, 8) = "connKey_") or (m.failure = "roster-write" and key = "connectionsV1")
                m.failure = ""
                return false
            end if
            m.values[key] = value
            return true
        end function
        delete: function(key as string) as boolean
            m.values.delete(key)
            return true
        end function
        flush: function() as boolean
            m.flushes++
            if m.failure = "rollback" then return false
            if m.failure = "key-flush"
                m.failure = ""
                return false
            end if
            m.durable = {}
            m.durable.append(m.values)
            snapshot = {}
            snapshot.append(m.values)
            m.transactions.push(snapshot)
            return true
        end function
    }
    registry.write("connKey_saved", "old-key")
    registry.write("connectionsV1", formatJson({schema: 1, selected: "saved", entries: [entry]}))
    registry.durable = {}
    registry.durable.append(registry.values)
    return registry
end function

sub check(condition as boolean, message as string)
    if not condition
        print "FAIL: "; message
        stop
    end if
end sub
