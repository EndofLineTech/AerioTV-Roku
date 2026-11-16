' Owner-authorized one-shot setup only. Uses normal connection/sign-in paths;
' never constructs an authenticated scope or edits an existing connection.
sub startBaselineProvision()
    m.baselineProvisionStage = 0
    m.baselineProvisionTimer = m.top.createChild("Timer")
    m.baselineProvisionTimer.duration = 1
    m.baselineProvisionTimer.repeat = true
    m.baselineProvisionTimer.observeField("fire", "onBaselineProvisionTick")
    m.baselineProvisionTimer.control = "start"
end sub

sub finishBaselineProvision(passed as boolean, reason as string)
    m.baselineProvisionTimer.control = "stop"
    if m.baselineProvisionConfig <> invalid then m.baselineProvisionConfig.password = ""
    print "[baseline-setup] "; FormatJson({kind: "result", passed: passed, reason: reason})
end sub

sub onBaselineProvisionTick()
    if m.top.startupReady <> true or m.busy = true then return
    if m.baselineProvisionStage = 0
        m.baselineProvisionStage = 1
        if m.page <> "setup" or m.activeUserScope <> invalid or userProfileGateClosed() then finishBaselineProvision(false, "setup-not-available") : return
        config = ParseJson(ReadAsciiFile("pkg:/baseline-provision-private.json"))
        m.baselineProvisionConfig = config
        before = loadConnectionStore(m.registry)
        if before.readOnly = true or before.entries.count() >= 4 then finishBaselineProvision(false, "connection-store-unavailable") : return
        for each entry in before.entries
            if entry.name = "Profiles Test" then finishBaselineProvision(false, "test-connection-already-exists") : return
        end for
        m.baselineProvisionBefore = before
        m.baselineProvisionPreserved = {}
        for each entry in before.entries
            for each key in [connectionRegistryKey(entry.id), userProfileStoreKey(entry.id)]
                m.baselineProvisionPreserved[key] = {present: m.registry.exists(key), value: m.registry.read(key)}
            end for
        end for
        addSavedConnection()
        if m.connectionStore.entries.count() <> before.entries.count() + 1 or m.selectedConnectionId = before.selected then finishBaselineProvision(false, "new-connection-not-created") : return
        m.baselineProvisionSlot = m.selectedConnectionId
        updateConnectionUrl(config.baseUrl)
        current = connectionStoreEntry(m.connectionStore, m.baselineProvisionSlot)
        if current = invalid then finishBaselineProvision(false, "new-connection-not-current") : return
        if current.url <> config.baseUrl or current.provider <> "dispatcharr" then finishBaselineProvision(false, "new-connection-address-not-saved") : return
        updated = connectionStoreUpdate(m.connectionStore, current.id, {name: "Profiles Test", remember: true})
        if updated = invalid then finishBaselineProvision(false, "test-name-not-planned") : return
        if not saveConnectionStore(m.registry, updated) then finishBaselineProvision(false, "test-name-not-saved") : return
        m.connectionStore = updated
        applySelectedConnection()
        m.username = config.username
        m.password = config.password
        config.password = ""
        m.authMode = "password"
        connectServer(true)
        return
    end if
    if m.page <> "guide" or m.activeUserScope = invalid or textValue(m.apiKey) = "" then finishBaselineProvision(false, "own-sign-in-not-complete") : return
    if m.activeUserScope.playlistId <> m.baselineProvisionSlot then finishBaselineProvision(false, "wrong-active-slot") : return
    matched = false
    for each profile in m.userProfileStore.profiles
        if profile.id = m.activeUserScope.profileId and lcase(profile.username) = lcase(m.baselineProvisionConfig.username) then matched = true
    end for
    if not matched then finishBaselineProvision(false, "wrong-own-identity") : return
    currentStore = loadConnectionStore(m.registry)
    for each previous in m.baselineProvisionBefore.entries
        retained = connectionStoreEntry(currentStore, previous.id)
        if FormatJson(retained) <> FormatJson(previous) then finishBaselineProvision(false, "existing-connection-changed") : return
    end for
    for each key in m.baselineProvisionPreserved
        previous = m.baselineProvisionPreserved[key]
        if m.registry.exists(key) <> previous.present or m.registry.read(key) <> previous.value then finishBaselineProvision(false, "existing-owned-storage-changed") : return
    end for
    finishBaselineProvision(true, "own-guide-ready-existing-connections-preserved")
end sub
