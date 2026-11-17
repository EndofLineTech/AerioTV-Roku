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
    m.baselineProvisionFirstKey = ""
    if m.baselineProvisionConfig <> invalid then m.baselineProvisionConfig.password = ""
    if m.baselineProvisionConfig <> invalid
        if type(m.baselineProvisionConfig.otherAccount) = "roAssociativeArray" then m.baselineProvisionConfig.otherAccount.password = ""
    end if
    print "[baseline-setup] "; FormatJson({kind: "result", passed: passed, reason: reason})
end sub

sub onBaselineProvisionTick()
    if m.top.startupReady <> true or m.busy = true then return
    if m.baselineProvisionStage = 0
        if m.page = "welcome" then onKeyEvent("back", true)
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
        updated = connectionStoreRename(m.connectionStore, current.id, "Profiles Test")
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
    if m.baselineProvisionStage > 1
        continueBaselineSecondAccount()
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
    if type(m.baselineProvisionConfig.otherAccount) = "roAssociativeArray"
        m.baselineProvisionFirstId = m.activeUserScope.profileId
        m.baselineProvisionFirstKey = m.apiKey
        m.baselineProvisionFirstAccount = m.activeUserScope.accountId
        beginProfileBaselineAdd()
        if m.profileOwnSignInContext = invalid then finishBaselineProvision(false, "second-add-not-available") : return
        m.baselineProvisionStage = 2
        return
    end if
    finishBaselineProvision(true, "own-guide-ready-existing-connections-preserved")
end sub

function baselineProvisionEvent(node as object, value as dynamic) as object
    return {node: node, value: value, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as dynamic
        return m.value
    end function}
end function

sub continueBaselineSecondAccount()
    stage = m.baselineProvisionStage
    if stage = 2
        if m.profileOwnSignInContext <> invalid
            if m.baselineProvisionSecondSubmitted = true
                if m.profileOwnSignInTask = invalid and m.profileOwnSignInHold = invalid then finishBaselineProvision(false, "second-sign-in-not-complete")
                return
            end if
            if m.profileOwnSignInDialog = invalid then return
            m.profileOwnSignInContext.username = m.baselineProvisionConfig.otherAccount.username
            m.profileOwnSignInContext.password = m.baselineProvisionConfig.otherAccount.password
            m.baselineProvisionConfig.otherAccount.password = ""
            m.baselineProvisionSecondSubmitted = true
            onProfileOwnSignInChoice(baselineProvisionEvent(m.profileOwnSignInDialog, 2))
            return
        end if
        store = loadUserProfileStore(m.registry, m.baselineProvisionSlot)
        for each profile in store.profiles
            if lcase(profile.username) = lcase(m.baselineProvisionConfig.otherAccount.username) then m.baselineProvisionSecondId = profile.id
        end for
        if textValue(m.baselineProvisionSecondId) = "" then finishBaselineProvision(false, "second-profile-not-added") : return
        if m.registry.read(connectionRegistryKey(m.baselineProvisionSlot)) <> m.baselineProvisionFirstKey then finishBaselineProvision(false, "default-key-changed") : return
        closeProfileBaselineMenu()
        if not beginUserProfileSwitch(m.baselineProvisionSecondId) then finishBaselineProvision(false, "second-switch-not-admitted") : return
        m.baselineProvisionStage = 3
        return
    end if
    if m.profileSwitchContext <> invalid or m.profileOwnSignInContext <> invalid then return
    if m.activeUserScope = invalid or m.page <> "guide" then finishBaselineProvision(false, "switched-guide-not-ready") : return
    if stage = 3
        if m.activeUserScope.profileId <> m.baselineProvisionSecondId or m.activeUserScope.accountId = m.baselineProvisionFirstAccount or m.apiKey = m.baselineProvisionFirstKey then finishBaselineProvision(false, "second-own-scope-not-adopted") : return
        if not beginUserProfileSwitch(m.baselineProvisionFirstId) then finishBaselineProvision(false, "default-return-not-admitted") : return
        m.baselineProvisionStage = 4
        return
    end if
    if m.activeUserScope.profileId <> m.baselineProvisionFirstId or m.apiKey <> m.baselineProvisionFirstKey then finishBaselineProvision(false, "default-own-scope-not-restored") : return
    m.baselineProvisionFirstKey = ""
    finishBaselineProvision(true, "two-own-profiles-guide-ready-existing-connections-preserved")
end sub
