sub main()
    for each scenario in ["write", "creation-blocked-existing", "unchanged", "pull-clean", "pull-dirty", "disabled", "stale", "child", "profiles-off", "held", "key-changed", "identity", "authority", "legacy", "missing", "missing404", "missing-blocked", "listed404", "proxy404", "legacy-listed404", "me-denied", "list-denied", "key-denied", "put-denied", "too-large", "max-apps", "get-failed", "local-commit", "root-race", "cancel", "put-failed", "late-success"]
        syncWriterFixture(scenario)
        writeDispatcharrSync()
        check(m.key = "" and m.top.apiKey = "", "writer clears Task credentials on every terminal path: " + scenario)
        puts = 0
        for each call in m.calls
            if call.method = "PUT" then puts++
            check(instr(1, call.url, "app.molinete") = 0 and instr(1, call.url, "/users/7/") = 0, "writer never targets legacy or another account path")
        end for
        if scenario = "write" or scenario = "creation-blocked-existing" or scenario = "missing" or scenario = "missing404" or scenario = "listed404"
            check(m.top.result.ok and m.top.result.submitted and puts = 1 and m.calls.count() = 4, "own fresh me/list/key precede one exact checked-string PUT")
        else if scenario = "late-success"
            check(not m.top.result.ok and m.top.result.submitted and puts = 1, "late successful PUT cannot acknowledge a successor session")
        else if scenario = "put-failed" or scenario = "put-denied" or scenario = "too-large" or scenario = "max-apps"
            check(not m.top.result.ok and m.top.result.submitted and puts = 1, "failed PUT stays pending without an immediate retry")
        else if scenario = "unchanged"
            check(m.top.result.ok and m.top.result.state = "unchanged" and not m.top.result.submitted and m.top.result.readStatus = 200 and puts = 0 and m.calls.count() = 3, "unchanged fresh own data acknowledges without a redundant PUT")
        else
            check(not m.top.result.ok and puts = 0, "unsafe writer scenario sends no PUT: " + scenario)
        end if
        if scenario = "disabled" or scenario = "stale" or scenario = "child" or scenario = "profiles-off" or scenario = "held" or scenario = "key-changed" then check(m.calls.count() = 0, "failed admission sends no request: " + scenario)
        if scenario = "identity" or scenario = "authority" then check(m.calls.count() = 1, "wrong identity/authority cannot reach App Data discovery")
        if scenario = "local-commit" then check(m.top.result.state = "local-commit" and m.top.result.readStatus = 200 and m.top.result.submitted = false and userProfileSameSession(m.top.result.scope, m.top.userScope), "read receipt stays bound to its actual own source and is not a write acknowledgement")
        if scenario = "pull-clean" or scenario = "pull-dirty" then check(m.top.result.state = "local-commit" and m.calls.count() = 3 and not m.top.result.submitted, "read-only schedule uses fresh own me/list/key and cannot PUT even when dirty")
        if scenario = "list-denied" or scenario = "put-denied" then check(m.top.result.state = "signin-required", "only list/PUT authorization refusal pauses sync for sign-in")
        if scenario = "me-denied" then check(m.top.result.state = "authorization-unavailable", "me authorization refusal ends quietly before App Data")
        if scenario = "key-denied" then check(m.top.result.state = "retry", "key authorization refusal is a failed read, not a sign-in pause")
        if scenario = "too-large" then check(m.top.result.state = "too-large", "typed413 stops repeated identical writes")
        if scenario = "max-apps" or scenario = "missing-blocked" then check(m.top.result.state = "storage-full", "capacity refusal never deletes legacy keys or creates another canonical")
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
    if scenario = "pull-clean" then store.pendingRoster = false
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
    m.top.pullOnly = scenario = "pull-clean" or scenario = "pull-dirty"
    m.top.creationBlocked = scenario = "missing-blocked" or scenario = "creation-blocked-existing"
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
        if m.scenario = "put-denied" then response.status = 403
        if m.scenario = "too-large" then response.status = 413 : response.body = "{""code"":""value_too_large""}"
        if m.scenario = "max-apps" then response.status = 409 : response.body = "{""code"":""max_apps""}"
        if m.scenario = "late-success" then m.global.activeusersession = "00000000-0000-4000-8000-000000000091"
    else if right(url, 10) = "/users/me/"
        user = {id: 7, username: "Alice", user_level: 1}
        if m.scenario = "identity" then user.username = "Other"
        if m.scenario = "authority" then user.user_level = 10
        response.body = FormatJson(user)
        if m.scenario = "me-denied" then response.status = 401
    else if right(url, 9) = "app-data/"
        apps = [{key: "alice.aeriotv", bytes: 100}]
        if m.scenario = "legacy" then apps = [{key: "app.molinete.aerio", bytes: 100}]
        if m.scenario = "missing" or m.scenario = "missing404" or m.scenario = "missing-blocked" or m.scenario = "proxy404" then apps = []
        if m.scenario = "legacy-listed404" then apps.push({key: "app.molinete.aerio", bytes: 100})
        response.body = FormatJson({apps: apps})
        if m.scenario = "list-denied" then response.status = 403
    else
        response.body = "{""schemaVersion"":3,""deviceId"":""fixture"",""platform"":""android"",""appVersion"":""1"",""updatedAt"":""2026-11-14T17:00:00Z"",""categories"":{""profiles"":{""updatedAt"":""2026-11-14T17:00:00Z"",""data"":{""rows"":[]}}}}"
        if m.scenario = "missing404" or m.scenario = "missing-blocked" or m.scenario = "listed404" or m.scenario = "legacy-listed404" then response.status = 404 : response.body = "{""code"":""key_not_found""}"
        if m.scenario = "key-denied" then response.status = 403
        if m.scenario = "proxy404" then response.status = 404 : response.body = "<html>Not found</html>"
        if m.scenario = "get-failed" then response.status = 500
        if m.scenario = "root-race" then m.syncWriterRegistry.values[userProfileStoreKey("slot-a")] = "changed-after-read"
        if m.scenario = "cancel" then m.top.cancelRequested = true
    end if
    return response
end function

function dispatcharrSyncPrepareProfilesWrite(original as dynamic, store as object, enabled as boolean, now as integer, acknowledgedStamp as dynamic, deviceId as string, appVersion as string) as object
    return {ok: true, allowWrite: false, body: "{""schemaVersion"":3,""synthetic"":true}", localPlan: {store: store}, needsLocalCommit: m.scenario = "local-commit", unchanged: m.scenario = "unchanged", maximumSentStamp: 100}
end function

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
