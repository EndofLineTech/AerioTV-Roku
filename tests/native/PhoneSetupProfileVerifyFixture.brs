sub onPhoneProfileVerifyProbeTick()
    if m.pickerProbePhoneVerifyStarted = true or m.busy or m.page <> "guide" then return
    m.pickerProbePhoneVerifyStarted = true
    cancelCapabilityRefresh()
    m.guide.active = false
    m.guide.findNode("saveDelay").control = "stop"
    m.phoneVerifyProbePrivate = ParseJson(ReadAsciiFile("pkg:/fixtures/phone-profile-verify.json"))
    m.phoneVerifyProbeScope = m.activeUserScope
    m.phoneVerifyProbeKey = m.apiKey
    m.phoneVerifyProbeConnectionRoot = m.registry.read("connectionsV1")
    m.phoneVerifyProbeStoreRoot = m.registry.read(userProfileStoreKey(m.selectedConnectionId))
    m.phoneVerifyProbeSettingsRoot = m.registry.read("settingsV1")
    task = CreateObject("roSGNode", "PhoneSetupProfileVerifyTask")
    tagTaskForCurrentUser(task)
    task.baseUrl = m.baseUrl
    task.authMode = m.global.authHeaderMode
    task.captureNonce = CreateObject("roDeviceInfo").getRandomUUID()
    task.defaultCredential = {apiKey: m.apiKey}
    task.profiles = [
        {username: m.userProfileStore.profiles[0].username, displayName: "Home", isDefault: true},
        {username: m.phoneVerifyProbePrivate.username, displayName: "Phone Profile", credential: {apiKey: "invalid-phone-fixture-key", password: m.phoneVerifyProbePrivate.password}}
    ]
    task.observeField("result", "onPhoneProfileVerifyProbeResult")
    m.phoneVerifyProbeTask = task
    m.phoneVerifyProbePrivate["password"] = ""
    task.control = "RUN"
end sub

sub onPhoneProfileVerifyProbeResult(event as object)
    if not isCurrentTaskEvent(event, m.phoneVerifyProbeTask) then return
    m.pickerProbeClock.control = "stop"
    task = m.phoneVerifyProbeTask
    result = event.getData()
    own = false
    if result.ok = true
        first = lcase(m.userProfileStore.profiles[0].username)
        second = lcase(m.phoneVerifyProbePrivate.username)
        own = result.proofs.count() = 2 and result.proofs[first].apiKey = m.phoneVerifyProbeKey and result.proofs[second].apiKey = m.phoneVerifyProbePrivate["apiKey"]
        own = own and lcase(result.proofs[second].verifiedUser.username) = second and result.proofs[second].verifiedUser.api_key = invalid
        for each row in result.rows
            if row.credential <> invalid then own = false
        end for
        for each name in result.proofs
            for each key in result.proofs[name]
                if lcase(key) = "apikey" then result.proofs[name][key] = ""
            end for
        end for
    end if
    cleared = task.defaultCredential = invalid and task.profiles.count() = 0
    task.unobserveField("result")
    task.result = invalid
    cancelNetworkTask(task)
    m.phoneVerifyProbeTask = invalid
    for each key in m.phoneVerifyProbePrivate
        if lcase(key) = "password" or lcase(key) = "apikey" then m.phoneVerifyProbePrivate[key] = ""
    end for
    unchanged = m.registry.read("connectionsV1") = m.phoneVerifyProbeConnectionRoot and m.registry.read(userProfileStoreKey(m.selectedConnectionId)) = m.phoneVerifyProbeStoreRoot and m.registry.read("settingsV1") = m.phoneVerifyProbeSettingsRoot
    unchanged = unchanged and m.apiKey = m.phoneVerifyProbeKey and userProfileSameSession(m.activeUserScope, m.phoneVerifyProbeScope)
    print "[picker-launch] "; FormatJson({kind: "result", baseline: true, phoneVerify: true, passed: own and cleared and unchanged, ownProofs: own, inputsCleared: cleared, unchanged: unchanged})
end sub
