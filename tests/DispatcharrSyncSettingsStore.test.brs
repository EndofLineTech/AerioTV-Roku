sub main()
    m.nativeSyncSettings = false
    syncControlsFixture()
    openDispatcharrSyncControls()
    context = m.profileSyncSettingsContext
    check(context <> invalid and m.connectionChoices.count() = 3 and m.connectionChoices[0].value = true and m.connectionChoices[1].value = false, "private selected-connection controls offer explicit opt-in and Profiles choices without enabling them")
    check(toggleDispatcharrSyncControls(context, "enabled", true), "actual current full-access holder may explicitly enable device-wide sync")
    check(loadDispatcharrSyncSettings(m.registry).enabled and m.profileSyncEnabled and loadUserProfileStore(m.registry, "slot-a").pendingRoster, "explicit opt-in updates runtime choice but leaves durable dirty intent")
    check(m.devicePreferences.dispatcharrSyncEnabled and m.devicePreferences.dispatcharrSyncProfiles and m.devicePreferences.futureDevice = "keep", "controls update the cached device choices used by outgoing profile preference saves")
    before = FormatJson(m.registry.values)
    check(not toggleDispatcharrSyncControls(context, "profiles", false) and FormatJson(m.registry.values) = before, "old controls snapshot cannot toggle a newer settings root")
    syncControlsFixture()
    m.profileSyncControlsReady = false
    openDispatcharrSyncControls()
    check(m.profileSyncSettingsContext = invalid and not toggleDispatcharrSyncControls(m.context, "enabled", true) and not loadDispatcharrSyncSettings(m.registry).enabled, "shipping-off controls cannot be opened or forged into enabling sync")
    syncControlsFixture()
    store = loadUserProfileStore(m.registry, "slot-a")
    store.profiles[0] = setCanonicalPreference(store.profiles[0], "role", "child")
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(store)
    openDispatcharrSyncControls()
    check(m.profileSyncSettingsContext = invalid and not loadDispatcharrSyncSettings(m.registry).enabled, "Child cannot open device-wide sync controls through a forged direct action")
    for each fault in ["", "write", "flush", "rollback"]
        syncSettingsFixture()
        before = FormatJson(m.registry.values)
        m.registry.fault = fault
        saved = commitDispatcharrSyncSettings(m.registry, m.context, m.scope, m.key, {}, true, false)
        if fault = ""
            settings = loadDispatcharrSyncSettings(m.registry)
            check(saved.ok and settings.ok and settings.enabled and not settings.profiles and m.registry.flushes = 1, "explicit device-wide opt-in and Profiles choice commit in one transaction")
            check(FormatJson(settings.store.accounts) = m.accountRoot, "sync controls preserve all profile data")
            check(settings.store["FutureRoot"] = "retain", "sync controls preserve exact-case unknown root values")
            check(settings.store.device["FutureDevice"] = m.futureDevice, "sync controls preserve the precise parsed unknown device value")
            check(m.registry.read(userProfileStoreKey("slot-a")) = m.context.storeRoot and loadUserProfileStore(m.registry, "slot-a").pendingRoster and m.registry.read("connKey_slot-a") = m.key, "toggling sync never acknowledges dirty roster intent or changes credentials")
            if m.nativeSyncSettings then check(not m.registry.exists("settingsv1"), "native transaction writes exact settingsV1, never a separate lowercase registry key")
        else
            check(not saved.ok and saved.recoveryRequired = (fault = "rollback") and FormatJson(m.registry.values) = before, "sync setting write/flush faults restore exact original roots")
        end if
    end for
    syncSettingsFixture()
    settings = loadDispatcharrSyncSettings(m.registry)
    check(settings.ok and not settings.enabled and settings.profiles and m.registry.flushes = 0, "missing sync choices default to opt-out without a normalization write")
    for each change in ["scope", "generation", "settings-root", "roster-root", "connection-root", "key", "child", "held", "invalid-enable", "invalid-profiles", "empty-settings", "malformed-settings"]
        syncSettingsFixture()
        scope = m.scope
        enabled = true
        profiles = true
        if change = "scope" then scope = setCanonicalPreference(scope, "sessionId", "00000000-0000-4000-8000-000000000091")
        if change = "generation" then scope = setCanonicalPreference(scope, "authorizationGeneration", "successor")
        if change = "settings-root" then m.registry.values["settingsV1"] += " "
        if change = "roster-root" then m.registry.values[userProfileStoreKey("slot-a")] += " "
        if change = "connection-root" then m.registry.values["connectionsV1"] += " "
        if change = "key" then m.key = "successor-key"
        if change = "child" or change = "held"
            store = loadUserProfileStore(m.registry, "slot-a")
            if change = "child" then store.profiles[0] = setCanonicalPreference(store.profiles[0], "role", "child")
            if change = "held" then store.profiles[0] = setCanonicalPreference(store.profiles[0], "addressHeld", true)
            m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(store)
            m.context.storeRoot = m.registry.values[userProfileStoreKey("slot-a")]
        end if
        if change = "invalid-enable" then enabled = "true"
        if change = "invalid-profiles" then profiles = 1
        if change = "empty-settings" then m.registry.values["settingsV1"] = "" : m.context.settingsRoot = ""
        if change = "malformed-settings" then m.registry.values["settingsV1"] = "{bad" : m.context.settingsRoot = "{bad"
        before = FormatJson(m.registry.values)
        saved = commitDispatcharrSyncSettings(m.registry, m.context, scope, m.key, {}, enabled, profiles)
        check(not saved.ok and FormatJson(m.registry.values) = before and m.registry.flushes = 0, "sync controls refuse stale or unsafe " + change)
    end for
    syncSettingsFixture()
    m.registry.values["settingsV1"] = "{""schema"":1,""device"":{""dispatcharrSyncEnabled"":""true""},""accounts"":{}}"
    check(not loadDispatcharrSyncSettings(m.registry).ok, "malformed present opt-in never silently enables sync")
    if m.nativeSyncSettings
        syncSettingsFixture()
        settings = loadDispatcharrSyncSettings(m.registry)
        precision = ParseJson("{""Case"":1,""case"":2,""values"":[1.3,1.0,1794675600000,null,""😀""]}", "d")
        settings.store.device["FuturePrecision"] = precision
        m.registry.values["settingsV1"] = strictJsonEncode(settings.store).text
        m.context.settingsRoot = m.registry.values["settingsV1"]
        saved = commitDispatcharrSyncSettings(m.registry, m.context, m.scope, m.key, {}, true, true)
        settings = loadDispatcharrSyncSettings(m.registry)
        check(saved.ok and dispatcharrSyncWireEqual(settings.store.device["FuturePrecision"], precision), "native sync choice transaction preserves exact future case/number kinds/milliseconds/null/emoji")
        m.registry.values["settingsV1"] = "{""schema"":1,""device"":{""dispatcharrSyncEnabled"":true,""DispatcharrSyncEnabled"":false},""accounts"":{}}"
        check(not loadDispatcharrSyncSettings(m.registry).ok, "native ambiguous opt-in aliases fail closed rather than choosing a value")
    end if
    print "ALL TESTS PASSED"
end sub

sub syncControlsFixture()
    syncSettingsFixture()
    m.profileSyncControlsReady = true
    m.profileSyncSettingsContext = invalid
    m.activeUserScope = m.scope
    m.apiKey = m.key
    m.selectedConnectionId = "slot-a"
    m.connectionStore = loadConnectionStore(m.registry)
    m.profileScheduledSyncTask = invalid
    m.profileSyncWriteTask = invalid
    m.profileSwitchContext = invalid
    m.profileOwnSignInContext = invalid
    m.profilePinDialog = invalid
    m.adultPinDialog = invalid
    m.userProfileRecoveryRequired = false
    m.global = {activeusersession: m.scope.sessionId, profilegateclosed: false}
    m.page = "setup"
    m.busy = false
    m.profileSyncEnabled = false
    m.profileRosterEnabled = true
    m.profileSyncClock = invalid
    m.devicePreferences = {dispatcharrSyncEnabled: false, dispatcharrSyncProfiles: true, futureDevice: "keep"}
end sub

sub openConnectionDialog(title as string, message as string, choices as object)
    m.connectionChoices = choices
    m.connectionDialog = {title: title, message: message}
end sub

sub showNotice(message as string)
end sub

sub closeScheduledProfileSync()
end sub

sub activateProfileSyncScheduling()
end sub

sub coverScheduledProfileSync()
    m.userProfileRecoveryRequired = true
end sub

sub syncSettingsFixture()
    m.strictJsonFloatingText = function(value as dynamic) as string
        return FormatJson(value)
    end function
    m.profilePreferenceDecoder = function(raw as string) as dynamic
        return ParseJson(raw)
    end function
    connections = connectionStoreAdd(defaultConnectionStore(), "slot-a", "Synthetic")
    connections = connectionStoreUpdate(connections, "slot-a", {url: "https://example.test", accountId: "7", remember: true})
    connection = connectionStoreEntry(connections, "slot-a")
    store = defaultUserProfileStore("slot-a")
    store.profiles = [userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "Alice", user_level: 1}, 1)]
    store.active = store.profiles[0].id
    store.pendingRoster = true
    m.scope = userProfileSessionScope(connection, store.active, 7, "own-generation", "00000000-0000-4000-8000-000000000090")
    m.key = "synthetic-own"
    preferences = ParseJson("{""schema"":1,""device"":{""FutureDevice"":1.3},""accounts"":{""foreign"":{""FutureAccount"":true}},""FutureRoot"":""retain""}")
    values = ParseJson("{}")
    values["connectionsV1"] = FormatJson(connections)
    values["settingsV1"] = FormatJson(preferences)
    values[userProfileStoreKey("slot-a")] = FormatJson(store)
    values["connKey_slot-a"] = m.key
    m.context = {connection: connection, scope: m.scope, connectionRoot: values["connectionsV1"], storeRoot: values[userProfileStoreKey("slot-a")], settingsRoot: values["settingsV1"], settingsPresent: true, credentialHash: string(64, "a")}
    m.accountRoot = FormatJson(preferences.accounts)
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
    m.futureDevice = loadDispatcharrSyncSettings(m.registry).store.device["FutureDevice"]
end sub

function requestGateCredentialHash(key as string) as string
    if key = "synthetic-own" then return string(64, "a")
    return string(64, "b")
end function

function requestGateAccessAllowed(url as string, key as string) as boolean
    return true
end function

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
