sub init()
    m.global.addFields({cacheEpoch: "fixture", metadataSession: "fixture", httpUserAgent: "Old-Connection", httpReferer: "https://old.example.test"})
    m.phoneSetup = m.top.findNode("phoneSetup")
    m.phoneClock = m.top.findNode("phoneSetupClock")
    m.phoneClock.observeField("fire", "onPhoneVerificationTick")
    m.phoneSetup.observeField("closed", "onPhoneSetupClosed")
    m.phoneSetup.observeField("retryRequested", "onPhoneSetupRetry")
    m.phoneSetup.observeField("retryAvailable", "fixtureFailed")
    m.top.findNode("fixtureWatch").observeField("fire", "fixtureWatch")
    m.httpMode = m.top.httpFixture
    if m.httpMode
        m.fixtureServer = CreateObject("roSGNode", "SetupApplyFixtureHttpTask")
        m.fixtureServer.observeField("baseUrl", "onFixtureHttpReady")
        m.fixtureServer.control = "RUN"
    else
        print "[setup-apply] "; formatJson({kind: "ready", transport: "fake-providers"})
    end if
end sub

sub onFixtureHttpReady(event as object)
    m.fixtureBase = event.getData()
    if left(m.fixtureBase, 17) <> "http://127.0.0.1:" then stop
    for each stamp in ["20231114221500 +0000", "20231115004500 +0230", "20231114164500 -0530"]
        epoch = xmltvEpoch(stamp)
        if epoch <> 1700000100 or GetInterface(epoch, "ifInt") = invalid then stop
    end for
    print "[setup-apply] "; formatJson({kind: "xmltv_epochs_verified"})
    print "[setup-apply] "; formatJson({kind: "ready", transport: "loopback-http"})
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
    m.confirmations = 0
    m.apiKey = "old-runtime-key"
    m.baseUrl = "https://old.example.test"
    m.global.httpUserAgent = "Old-Connection"
    m.global.httpReferer = "https://old.example.test"
    m.case = m.top.fixtureCase
    store = defaultConnectionStore()
    if instr(1, m.case, "duplicate") > 0 or instr(1, m.case, "full") > 0
        store.entries.push(normalizeConnectionEntry({id: "saved", name: "Original", provider: "dispatcharr", url: "https://example.test", accountId: "7", remember: true}))
        store.selected = "saved"
    end if
    if m.httpMode and store.entries.count() > 0 then store.entries[0].url = m.fixtureBase
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
    if m.httpMode
        playlist = cases[m.case].playlist
        playlist.url = m.fixtureBase
        if m.case = "reject" then playlist.url += "/reject"
        if m.case = "cancel" then playlist.url += "/slow"
        if m.case = "m3u-query"
            playlist.url += "/feed?token=session-token"
            playlist["xmltvUrl"] = m.fixtureBase + "/guide.xml"
        end if
    end if
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
    m.confirmations++
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
    m.global.httpUserAgent = dispatcharrUserAgent(entry.userAgent)
    m.global.httpReferer = entry.referer
end sub

sub completeConnection(result as object)
    entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    serialized = m.registry.read("connectionsV1")
    if instr(1, serialized, "verified-fixture-key") > 0 or instr(1, serialized, "fixture-password") > 0 or instr(1, serialized, "session-token") > 0 then stop
    if instr(1, lcase(serialized), "pinhash") > 0 or instr(1, lcase(serialized), "pinsalt") > 0 then stop
    if entry.provider = "dispatcharr"
        expectedKey = "verified-fixture-key"
        if m.httpMode then expectedKey = "fixture-api-key"
        if m.apiKey <> expectedKey then stop
    end if
    if m.case = "duplicate-replace-full" and (entry.id <> "saved" or m.connectionStore.entries.count() <> 4) then stop
    if m.case = "duplicate-add" and (entry.id = "saved" or m.connectionStore.entries.count() <> 2) then stop
    if m.case = "m3u-query"
        expectedUrl = "https://example.test/?token=session-token"
        if m.httpMode then expectedUrl = m.fixtureBase + "/feed?token=session-token"
        if entry.url <> "" or m.baseUrl <> expectedUrl then stop
        prefs = takePhoneSetupPreferences({guide: {futureDays: 7}, vodEnabled: true}, entry)
        if prefs.vodEnabled <> false or prefs.guide.futureDays <> 3 then stop
    end if
    if m.runtimeResets <> 1 then stop
    if instr(1, m.case, "duplicate") = 0 and m.confirmations <> 0 then stop
    if m.case = "xtream" or m.case = "m3u-query" or m.case = "default-profile"
        if instr(1, textValue(result.warning), "Diagnostics") = 0 then stop
    end if
    if m.httpMode and m.case = "default-profile"
        if result.channels.count() <> 2 then stop
        for each channel in result.channels
            if channel.id = "3" then stop
        end for
        print "[setup-apply] "; formatJson({kind: "profile_union_verified"})
    end if
    print "[setup-apply] "; formatJson({kind: "committed", case: m.case, count: m.connectionStore.entries.count(), replacement: entry.id = "saved", confirmations: m.confirmations})
    if m.httpMode then loadFixtureHttpGuide(result, entry)
end sub

sub loadFixtureHttpGuide(result as object, entry as object)
    channels = result.channels
    if entry.provider = "dispatcharr" then bindChannelGuide(channels, [])
    allowed = {}
    for each channel in channels
        if channel.epgKey <> "" then allowed[channel.epgKey] = true
    end for
    if not allowed.doesExist("fixture.station") then stop
    m.fixtureGuide = CreateObject("roSGNode", "GuideTask")
    m.fixtureGuide.baseUrl = m.fixtureBase
    m.fixtureGuide.apiKey = ""
    if entry.provider = "dispatcharr" then m.fixtureGuide.apiKey = m.apiKey
    m.fixtureGuide.providerType = entry.provider
    if entry.provider = "m3u" then m.fixtureGuide.guideUrl = entry.epgUrl
    if entry.provider = "xtream" then m.fixtureGuide.guideUrl = result.guideUrl
    m.fixtureGuide.windowStart = 1700000000
    m.fixtureGuide.allowedKeys = allowed
    m.fixtureGuide.scope = result.scope
    m.fixtureGuide.generation = result.generation
    m.fixtureGuide.cacheEpoch = m.global.cacheEpoch
    m.fixtureGuide.bypassCache = true
    m.fixtureGuide.observeField("result", "onFixtureHttpGuide")
    m.fixtureGuide.control = "RUN"
end sub

sub onFixtureHttpGuide(event as object)
    if not isCurrentTaskEvent(event, m.fixtureGuide) then return
    result = event.getData()
    if result.ok <> true then stop
    if result.index.doesExist("outside.station") then stop
    programs = result.index["fixture.station"]
    if type(programs) <> "roArray" or programs.count() <> 1 then stop
    if programs[0].title <> "HTTP Fixture" or programs[0].startsAt <> 1700000100 or programs[0].endsAt <> 1700003700
        print "[setup-apply] "; formatJson({kind: "guide_epoch_mismatch", titlematches: programs[0].title = "HTTP Fixture", actual: programs[0].startsAt, expected: 1700000100, actualend: programs[0].endsAt})
        stop
    end if
    m.fixtureGuide.unobserveField("result")
    m.fixtureGuide = invalid
    print "[setup-apply] "; formatJson({kind: "guide_loaded", case: m.case, source: result.source})
end sub

sub showNotice(message as string)
    if m.registry.writes > 0
        print "[setup-apply] "; formatJson({kind: "handoff_notice", case: m.case, nonblocking: true})
        return
    end if
    if m.registry.writes <> 0 or m.runtimeResets <> 0 then stop
    print "[setup-apply] "; formatJson({kind: "capacity_refused", unchanged: formatJson(m.connectionStore) = m.before})
end sub

sub recordDiagnostic(stage as string, code as integer, message as string)
    if stage <> "connect" then stop
    omission = instr(1, message, "not be imported") > 0 or instr(1, message, "not be enabled") > 0 or instr(1, message, "session-only") > 0
    print "[setup-apply] "; formatJson({kind: "import_notice", case: m.case, omissions: omission})
end sub

sub drawSetup()
    if m.phonePending <> invalid or m.phoneResult <> invalid or m.phoneVerifyTask <> invalid then stop
    if m.registry.writes <> 0 or m.runtimeResets <> 0 or m.apiKey <> "old-runtime-key" then stop
    print "[setup-apply] "; formatJson({kind: "cancelled", unchanged: formatJson(m.connectionStore) = m.before})
end sub

sub drawWelcome()
    drawSetup()
end sub
