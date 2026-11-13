' Injected only into a private normal-app fixture, never the shipping package.
sub onManagementProbeTick()
    if m.activeUserScope = invalid or m.page <> "guide" then return
    m.managementProbeClock.control = "stop"
    store = loadUserProfileStore(m.registry, "slot-a")
    target = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "Synthetic8", user_level: 1}, 1)
    target.isDefault = false
    target.order = 1
    store.profiles.push(target)
    m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
    entry = connectionStoreEntry(m.connectionStore, "slot-a")
    preferences = m.preferenceStore
    preferences.accounts[preferenceScope(connectionPreferenceIdentity(entry, "8"))] = {favoriteIds: ["own-only"], futureField: {value: 9}}
    m.registry.write("settingsV1", FormatJson(preferences))
    m.registry.flush()
    m.ownProbeStore = loadUserProfileStore(m.registry, "slot-a")
    m.ownProbeTarget = target.id
    m.ownProbeSession = currentUserSessionId()
    m.ownProbeNonce = CreateObject("roDeviceInfo").getRandomUUID()
    m.ownProbeCases = ["rejected", "name", "no-api", "correct"]
    m.ownProbeCase = -1
    m.ownProbePassed = true
    beginNextOwnProbeCase()
end sub

sub beginNextOwnProbeCase()
    m.ownProbeCase++
    scenario = m.ownProbeCases[m.ownProbeCase]
    task = CreateObject("roSGNode", "DispatcharrTask")
    tagTaskForCurrentUser(task)
    task.baseUrl = m.baseUrl
    task.authMode = "x-api-key"
    task.ownProfileSignIn = true
    task.verifyOnly = true
    task.expectedUsername = "Synthetic8"
    task.username = "Synthetic8"
    task.password = "synthetic-" + scenario
    task.observeField("result", "onOwnProfileProbeResult")
    m.ownProbeTask = task
    task.control = "RUN"
end sub

sub onOwnProfileProbeResult(event as object)
    if not isCurrentTaskEvent(event, m.ownProbeTask) then return
    task = m.ownProbeTask
    task.unobserveField("result")
    result = event.getData()
    scenario = m.ownProbeCases[m.ownProbeCase]
    passed = task.password = "" and task.apiKey = ""
    entry = connectionStoreEntry(m.connectionStore, "slot-a")
    if scenario = "correct"
        passed = passed and result.ok = true and result.verifiedUser.id = 88
        saved = commitUserProfileOwnSignIn(m.registry, entry, m.ownProbeStore, m.ownProbeTarget, result, CreateObject("roDateTime").asSeconds(), m.ownProbeNonce, m.ownProbeNonce)
        preferences = ParseJson(m.registry.read("settingsV1"), "d")
        oldKey = preferenceScope(connectionPreferenceIdentity(entry, "8"))
        newKey = preferenceScope(connectionPreferenceIdentity(entry, "88"))
        passed = passed and saved.ok and saved.preferencesMoved and not preferences.accounts.doesExist(oldKey) and preferences.accounts[newKey].favoriteIds[0] = "own-only"
    else
        passed = passed and result.ok = false and FormatJson(loadUserProfileStore(m.registry, "slot-a")) = FormatJson(m.ownProbeStore)
        if scenario = "no-api"
            passed = passed and result.apiAccessRequired = true and result.message = "This account has no API key yet. Ask your Dispatcharr administrator to turn on API access for it."
        else
            passed = passed and result.message = "Dispatcharr did not accept that username or password."
        end if
    end if
    task.result = invalid
    m.ownProbeTask = invalid
    m.ownProbePassed = m.ownProbePassed and passed
    print "[own-signin] "; FormatJson({kind: "case", scenario: scenario, passed: passed})
    if m.ownProbeCase < m.ownProbeCases.count() - 1
        beginNextOwnProbeCase()
        return
    end if
    actual = loadUserProfileStore(m.registry, "slot-a")
    print "[own-signin] "; FormatJson({kind: "result", passed: m.ownProbePassed, default_preserved: m.registry.read("connKey_slot-a") = "synthetic-a", own_saved: m.registry.read(userProfileKeyName("slot-a", m.ownProbeTarget)) = "synthetic-new-own-key", active_preserved: actual.active = m.ownProbeStore.active and currentUserSessionId() = m.ownProbeSession and m.apiKey = "synthetic-a", no_autoplay: m.playingChannel = invalid})
end sub
