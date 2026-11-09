sub init()
    m.global.addFields({cacheEpoch: "fixture", httpUserAgent: "Old-Connection", httpReferer: "https://old.example.test"})
    m.phoneSetup = m.top.findNode("phoneSetup")
    m.phoneClock = m.top.findNode("phoneSetupClock")
    m.phoneClock.observeField("fire", "onPhoneVerificationTick")
    m.phoneSetup.observeField("closed", "onPhoneSetupClosed")
    m.phoneSetup.observeField("retryRequested", "onPhoneSetupRetry")
    m.phoneSetup.observeField("retryAvailable", "fixtureFailed")
    m.top.findNode("fixtureWatch").observeField("fire", "fixtureWatch")
    print "[setup-apply] "; formatJson({kind: "ready"})
end sub

sub startFixtureCase()
    closePhoneSetupDialog()
    stopPhoneVerification()
    m.phoneSetup.active = false
    m.phoneSetup.visible = false
    m.reportedDialog = invalid
    m.phoneVerifyTask = invalid
    m.phonePending = invalid
    m.phoneResult = invalid
    m.phoneOptions = invalid
    m.phoneCommittedId = ""
    m.page = "setup"
    m.busy = false
    m.runtimeResets = 0
    m.apiKey = "old-runtime-key"
    m.baseUrl = "https://old.example.test"
    m.case = m.top.fixtureCase
    store = defaultConnectionStore()
    if instr(1, m.case, "duplicate") > 0 or instr(1, m.case, "full") > 0
        store.entries.push(normalizeConnectionEntry({id: "saved", name: "Original", provider: "dispatcharr", url: "https://example.test", accountId: "7", remember: true}))
        store.selected = "saved"
    end if
    if instr(1, m.case, "full") > 0
        for i = 1 to 3
            store.entries.push(normalizeConnectionEntry({id: "other" + i.toStr(), name: "Other", provider: "dispatcharr", url: "https://other.example.test", accountId: i.toStr()}))
        end for
    end if
    m.connectionStore = store
    m.selectedConnectionId = store.selected
    m.before = formatJson(store)
    m.registry = fixtureRegistry()
    m.registry.write("connectionsV1", m.before)
    if store.entries.count() > 0 then m.registry.write("connKey_saved", "old-stored-key")
    m.registry.writes = 0
    cases = parseJson(ReadAsciiFile("pkg:/apply-cases.json"))
    valid = validatePhoneSetupPayload(cases[m.case])
    if not valid.ok then stop
    openPhoneSetup()
    acceptPhoneSetupPayload(valid.payload)
    print "[setup-apply] "; formatJson({kind: "verifying", case: m.case})
end sub

sub fixtureWatch()
    if m.phoneDialog = invalid then return
    if m.reportedDialog <> invalid
        if m.reportedDialog.isSameNode(m.phoneDialog) then return
    end if
    m.reportedDialog = m.phoneDialog
    if m.registry.writes <> 0 or m.runtimeResets <> 0 then stop
    print "[setup-apply] "; formatJson({kind: "confirmation", case: m.case, focus: m.phoneDialog.buttonFocused, unchanged: formatJson(m.connectionStore) = m.before, omissions: m.phonePending.notes.count() > 0})
end sub

sub fixtureFailed()
    if m.phoneSetup.retryAvailable <> true then return
    if m.registry.writes <> 0 or m.runtimeResets <> 0 or m.apiKey <> "old-runtime-key" then stop
    print "[setup-apply] "; formatJson({kind: "rejected", unchanged: formatJson(m.connectionStore) = m.before})
end sub

function fixtureRegistry() as object
    return {values: {}, writes: 0
        read: function(key as string) as string
            if not m.values.doesExist(key) then return ""
            return m.values[key]
        end function
        write: function(key as string, value as string) as boolean
            m.writes++
            m.values[key] = value
            return true
        end function
        delete: function(key as string) as boolean
            m.writes++
            m.values.delete(key)
            return true
        end function
        flush: function() as boolean
            return true
        end function
        getKeyList: function() as object
            return m.values.keys()
        end function
    }
end function

' Navigation handoff stubs. The real controller runs, but neither the normal
' Scene/Guide nor any real account, registry section or provider is instantiated.
sub cancelProfileTask()
end sub

sub cancelCapabilityRefresh()
end sub

sub resetConnectionRuntime()
    m.runtimeResets++
    m.page = "setup"
end sub

sub applySelectedConnection()
    entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    m.baseUrl = entry.url
    m.apiKey = m.registry.read(connectionRegistryKey(entry.id))
end sub

sub completeConnection(result as object)
    entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    serialized = m.registry.read("connectionsV1")
    if instr(1, serialized, "verified-fixture-key") > 0 or instr(1, serialized, "fixture-password") > 0 or instr(1, serialized, "session-token") > 0 then stop
    if instr(1, lcase(serialized), "pinhash") > 0 or instr(1, lcase(serialized), "pinsalt") > 0 then stop
    if entry.provider = "dispatcharr" and m.apiKey <> "verified-fixture-key" then stop
    if m.case = "duplicate-replace-full" and (entry.id <> "saved" or m.connectionStore.entries.count() <> 4) then stop
    if m.case = "duplicate-add" and (entry.id = "saved" or m.connectionStore.entries.count() <> 2) then stop
    if m.case = "m3u-query"
        if entry.url <> "" or m.baseUrl <> "https://example.test/?token=session-token" then stop
        prefs = takePhoneSetupPreferences({guide: {futureDays: 7}, vodEnabled: true}, entry)
        if prefs.vodEnabled <> false or prefs.guide.futureDays <> 3 then stop
    end if
    if m.runtimeResets <> 1 then stop
    print "[setup-apply] "; formatJson({kind: "committed", case: m.case, count: m.connectionStore.entries.count(), replacement: entry.id = "saved"})
end sub

sub showNotice(message as string)
    if m.registry.writes <> 0 or m.runtimeResets <> 0 then stop
    print "[setup-apply] "; formatJson({kind: "capacity_refused", unchanged: formatJson(m.connectionStore) = m.before})
end sub

sub drawSetup()
    if m.phonePending <> invalid or m.phoneResult <> invalid or m.phoneVerifyTask <> invalid then stop
    if m.registry.writes <> 0 or m.runtimeResets <> 0 or m.apiKey <> "old-runtime-key" then stop
    print "[setup-apply] "; formatJson({kind: "cancelled", unchanged: formatJson(m.connectionStore) = m.before})
end sub

sub drawWelcome()
    drawSetup()
end sub
