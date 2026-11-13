sub main()
    resetAutoAdd()
    showPhoneSetupConfirmation()
    check(m.completed and m.phoneDialog = invalid, "verified new account opens guide without a confirmation dialog")
    check(m.connectionStore.entries.count() = 1 and m.connectionStore.selected = "new", "new account automatically selected")
    check(m.registry.flushes = 1 and m.registry.read("connKey_new") = "fixture-key", "automatic add retains atomic key and roster commit")
    check(m.notices.count() = 1 and m.notice <> "", "credential persistence disclosed nonblockingly")
    resetAutoAdd()
    m.phonePending.multipleProfiles = true
    m.phonePending.notes = ["Multiple profiles aren't currently supported on Roku. Stay tuned."]
    showPhoneSetupConfirmation()
    check(m.completed and m.notice = "Multiple profiles aren't currently supported on Roku. Stay tuned.", "omission notice actually reaches screen after automatic guide handoff")
    resetAutoAdd()
    before = formatJson(m.connectionStore)
    m.phoneStoreSnapshot = "stale"
    showPhoneSetupConfirmation()
    check(not m.completed and m.registry.flushes = 0 and formatJson(m.connectionStore) = before, "stale roster prevents automatic commit")
    resetAutoAdd()
    m.registry.failWrite = true
    showPhoneSetupConfirmation()
    check(not m.completed and m.connectionStore.entries.count() = 0 and m.registry.read("connKey_new") = "", "failed automatic write rolls back without guide handoff")
    resetAutoAdd()
    for i = 1 to 4
        m.connectionStore.entries.push(normalizeConnectionEntry({id: "old" + i.toStr(), name: "Old", provider: "dispatcharr", url: "https://other.test", accountId: i.toStr()}))
    end for
    showPhoneSetupConfirmation()
    check(not m.completed and m.registry.flushes = 0 and not m.phoneSetup.retryAvailable, "full roster refuses auto-add before any write")
    notes = phoneSetupImportNotices({entry: {provider: "xtream"}, notes: ["Household profiles and PINs will not be imported.", "Dispatcharr Sync will not be enabled."]})
    check(notes.count() = 3 and instr(1, notes[0], "session-only") > 0, "session-only and omission notices retained without acknowledgement")
    print "ALL TESTS PASSED"
end sub

sub resetAutoAdd()
    m.completed = false
    m.notices = []
    m.notice = ""
    m.phoneDialog = invalid
    m.phoneMatchedId = ""
    m.phoneVerifyTask = invalid
    m.phoneClock = {control: "stop"}
    m.phoneSetup = {active: true, visible: true, setFocus: function(value as boolean) as boolean
        return true
    end function}
    m.phonePending = {entry: normalizeConnectionEntry({id: "new", name: "New", provider: "dispatcharr", url: "https://provider.test", accountId: "7", remember: true}), credential: {username: "", password: ""}, notes: []}
    m.phoneResult = {ok: true, apiKey: "fixture-key", warning: ""}
    m.connectionStore = defaultConnectionStore()
    m.phoneStoreSnapshot = formatJson(m.connectionStore)
    m.registry = {values: {}, flushes: 0, failWrite: false
        read: function(key as string) as string
            if not m.values.doesExist(key) then return ""
            return m.values[key]
        end function
        write: function(key as string, value as string) as boolean
            if m.failWrite
                m.failWrite = false
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
            return true
        end function}
    m.registry.write("connectionsV1", m.phoneStoreSnapshot)
end sub

sub resetConnectionRuntime()
end sub

sub applySelectedConnection()
end sub

sub completeConnection(result as object)
    m.completed = true
end sub

sub recordDiagnostic(stage as string, code as integer, message as string)
    m.notices.push(message)
end sub

sub showNotice(message as string)
    m.notice = message
end sub

sub check(ok as boolean, message as string)
    if not ok
        print "FAIL: "; message
        stop
    end if
end sub
