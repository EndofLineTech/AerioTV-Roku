sub main()
    for each scenario in ["write", "disabled", "stale", "child", "profiles-off", "held", "key-changed", "identity", "authority", "legacy", "missing", "get-failed", "local-commit", "root-race", "cancel", "put-failed", "late-success"]
        syncWriterFixture(scenario)
        writeDispatcharrSync()
        check(m.key = "" and m.top.apiKey = "", "writer clears Task credentials on every terminal path: " + scenario)
        puts = 0
        for each call in m.calls
            if call.method = "PUT" then puts++
            check(instr(1, call.url, "app.molinete") = 0 and instr(1, call.url, "/users/7/") = 0, "writer never targets legacy or another account path")
        end for
        if scenario = "write"
            check(m.top.result.ok and m.top.result.submitted and puts = 1 and m.calls.count() = 4, "own fresh me/list/key precede one exact checked-string PUT")
        else if scenario = "late-success"
            check(not m.top.result.ok and m.top.result.submitted and puts = 1, "late successful PUT cannot acknowledge a successor session")
        else if scenario = "put-failed"
            check(not m.top.result.ok and m.top.result.submitted and puts = 1, "failed PUT stays pending without an immediate retry")
        else
            check(not m.top.result.ok and puts = 0, "unsafe writer scenario sends no PUT: " + scenario)
        end if
        if scenario = "disabled" or scenario = "stale" or scenario = "child" or scenario = "profiles-off" or scenario = "held" or scenario = "key-changed" then check(m.calls.count() = 0, "failed admission sends no request: " + scenario)
        if scenario = "identity" or scenario = "authority" then check(m.calls.count() = 1, "wrong identity/authority cannot reach App Data discovery")
    end for
    print "ALL TESTS PASSED"
end sub

sub syncWriterFixture(scenario as string)
    m.scenario = scenario
    m.calls = []
    m.syncWriterReady = scenario <> "disabled"
    m.syncJsonParser = function(raw as string) as dynamic
        return ParseJson(raw)
    end function
    connections = connectionStoreAdd(defaultConnectionStore(), "slot-a", "Synthetic")
    connections = connectionStoreUpdate(connections, "slot-a", {url: "https://example.test", accountId: "7", remember: true})
    entry = connectionStoreEntry(connections, "slot-a")
    profile = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "Alice", user_level: 1}, 1)
    if scenario = "child" then profile = setCanonicalPreference(profile, "role", "child")
    store = defaultUserProfileStore("slot-a")
    store.profiles = [profile]
    store.active = profile.id
    store.pendingRoster = true
    values = {connectionsV1: FormatJson(connections)}
    values[userProfileStoreKey("slot-a")] = FormatJson(store)
    values["connKey_slot-a"] = "synthetic-own"
    if scenario = "key-changed" then values["connKey_slot-a"] = "replacement-own"
    m.syncWriterRegistry = {values: values
        exists: function(key as string) as boolean
            return m.values.doesExist(key)
        end function
        read: function(key as string) as string
            if not m.values.doesExist(key) then return ""
            return m.values[key]
        end function
    }
    scope = userProfileSessionScope(entry, profile.id, 7, "own-generation", "00000000-0000-4000-8000-000000000090")
    m.global = {activeusersession: scope.sessionId, profilegateclosed: false}
    m.top = {baseUrl: entry.url, apiKey: "synthetic-own", authMode: "x-api-key", userScope: scope, aeriosession: scope.sessionId, storeRoot: values[userProfileStoreKey("slot-a")], connectionRoot: values.connectionsV1, profilesEnabled: scenario <> "profiles-off", expectedAuthorizationSignature: dispatcharrAuthorizationSignature({id: 7, username: "Alice", user_level: 1}), deviceId: "synthetic-device", appVersion: "1", acknowledgedStamp: 0, cancelRequested: false}
    if scenario = "stale" then m.global.activeusersession = "00000000-0000-4000-8000-000000000091"
end sub

function requestGateAccessAllowed(url as string, key as string) as boolean
    return m.scenario <> "held"
end function

function requestGateTaskSessionCurrent() as boolean
    return taskUserSessionCurrent(m.top)
end function

function requestGateCredentialHash(key as string) as string
    return string(64, "a")
end function

function httpTransferOnce(url as string, body as dynamic, bearer as string, timeoutMs as integer, maxBytes as integer, method = "GET" as string, checked = invalid as dynamic) as object
    m.calls.push({url: url, method: method})
    check(body = invalid and bearer = "" and m.key = "synthetic-own", "writer uses only its own key and never object-reserializes PUT data")
    response = {status: 200, error: "", body: "{}", headers: {}}
    if method = "PUT"
        check(checked = "{""schemaVersion"":3,""synthetic"":true}", "transport receives the exact independently checked string")
        if m.scenario = "put-failed" then response.status = 429
        if m.scenario = "late-success" then m.global.activeusersession = "00000000-0000-4000-8000-000000000091"
    else if right(url, 10) = "/users/me/"
        user = {id: 7, username: "Alice", user_level: 1}
        if m.scenario = "identity" then user.username = "Other"
        if m.scenario = "authority" then user.user_level = 10
        response.body = FormatJson(user)
    else if right(url, 9) = "app-data/"
        apps = [{key: "alice.aeriotv", bytes: 100}]
        if m.scenario = "legacy" then apps = [{key: "app.molinete.aerio", bytes: 100}]
        if m.scenario = "missing" then apps = []
        response.body = FormatJson({apps: apps})
    else
        if m.scenario = "get-failed" then response.status = 500
        if m.scenario = "root-race" then m.syncWriterRegistry.values[userProfileStoreKey("slot-a")] = "changed-after-read"
        if m.scenario = "cancel" then m.top.cancelRequested = true
    end if
    return response
end function

function dispatcharrSyncPrepareProfilesWrite(original as dynamic, store as object, enabled as boolean, now as integer, acknowledgedStamp as dynamic, deviceId as string, appVersion as string) as object
    return {ok: true, allowWrite: false, body: "{""schemaVersion"":3,""synthetic"":true}", localPlan: {store: store}, needsLocalCommit: m.scenario = "local-commit", maximumSentStamp: 100}
end function

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
