' Actual approved-account Sync. No scope, credential, receipt or PUT is faked.
sub startRealProfileSyncProof()
    m.realSyncBaselineWriterReady = m.profileSyncWriterReady
    m.realSyncBaselineSchedulingReady = m.profileSyncSchedulingReady
    m.realSyncBaselineControlsReady = m.profileSyncControlsReady
    m.profileSyncWriterReady = false
    m.profileSyncSchedulingReady = false
    m.realSyncStage = 0
    m.realSyncWrites = {}
    m.realSyncConfig = ParseJson(ReadAsciiFile("pkg:/real-sync-config.json"))
    m.realSyncClock = m.top.createChild("Timer")
    m.realSyncClock.duration = 0.5
    m.realSyncClock.repeat = true
    m.realSyncClock.observeField("fire", "onRealProfileSyncTick")
    m.realSyncClock.control = "start"
end sub

function realSyncEvent(node as object, value as dynamic) as object
    return {node: node, value: value, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as dynamic
        return m.value
    end function}
end function

sub finishRealProfileSync(passed as boolean, reason as string)
    m.realSyncClock.control = "stop"
    print "[real-sync] "; FormatJson({kind: "result", passed: passed, reason: reason, ownWrites: m.realSyncWrites.count()})
end sub

sub recordRealProfileSyncReceipt(result as object, saved as object)
    print "[real-sync] "; FormatJson({kind: "receipt", state: textValue(result.state), ok: result.ok = true, committed: saved.ok = true, submitted: result.submitted = true})
    if saved.ok = true then m.realSyncSettled = true
    if result.state = "written" and result.ok = true and saved.ok = true
        m.realSyncWrites[m.activeUserScope.profileId] = true
    end if
end sub

function renameRealSyncHolder(id as string, name as string) as boolean
    openUserProfileManagement()
    if m.profileManagementDialog = invalid then return false
    found = false
    for i = 0 to m.profileManagementChoices.count() - 1
        if m.profileManagementChoices[i].id = id
            onProfileManagementChoice(realSyncEvent(m.profileManagementDialog, i))
            found = true
            exit for
        end if
    end for
    if not found then return false
    onProfileManagementChoice(realSyncEvent(m.profileManagementDialog, 0))
    m.profileManagementDialog.text = name
    onProfileManagementName(realSyncEvent(m.profileManagementDialog, 0))
    retireProfileManagement()
    store = loadUserProfileStore(m.registry, m.selectedConnectionId)
    for each profile in store.profiles
        if profile.id = id then return profile.displayName = name
    end for
    return false
end function

sub onRealProfileSyncTick()
    if m.top.startupReady <> true or m.busy then return
    stage = m.realSyncStage
    if m.realSyncLoggedStage <> stage
        m.realSyncLoggedStage = stage
        print "[real-sync] "; FormatJson({kind: "stage", stage: stage, page: m.page})
    end if
    if stage = 0
        entries = loadConnectionStore(m.registry)
        entry = connectionStoreEntry(entries, m.selectedConnectionId)
        if entry = invalid then finishRealProfileSync(false, "test-connection-required") : return
        if entries.entries.count() <> 1 or entry.url <> m.realSyncConfig.baseUrl
            print "[real-sync] "; FormatJson({kind: "scope-check", entryCount: entries.entries.count(), expectedName: entry.name = "Profiles Test", expectedOrigin: entry.url = m.realSyncConfig.baseUrl, configuredOriginType: type(m.realSyncConfig.baseUrl)})
            finishRealProfileSync(false, "test-scope-refused")
            return
        end if
        store = loadUserProfileStore(m.registry, entry.id)
        if store.readOnly = true or store.profiles.count() <> 2 then finishRealProfileSync(false, "test-roster-refused") : return
        for each profile in store.profiles
            if lcase(profile.username) = lcase(m.realSyncConfig.first) then m.realSyncFirst = profile.id
            if lcase(profile.username) = lcase(m.realSyncConfig.second) then m.realSyncSecond = profile.id
        end for
        if textValue(m.realSyncFirst) = "" or textValue(m.realSyncSecond) = "" then finishRealProfileSync(false, "test-identities-refused") : return
        if m.profilePicker <> invalid
            if m.requestGate = invalid then return
            if m.requestGate.ready <> true then return
            if m.realSyncPickerChosen <> true
                m.realSyncPickerChosen = true
                model = m.profilePicker.model
                for i = 0 to model.tiles.count() - 1
                    if model.tiles[i].id = m.realSyncFirst
                        print "[real-sync] "; FormatJson({kind: "choose-first", action: userProfilePickerChoice(model, i), ready: m.requestGate.ready})
                        m.profilePicker.intent = {action: userProfilePickerChoice(model, i), index: i, uiNonce: model.uiNonce}
                        exit for
                    end if
                end for
            end if
            return
        end if
        if m.page <> "guide" or m.activeUserScope = invalid then return
        if m.activeUserScope.profileId <> m.realSyncFirst then finishRealProfileSync(false, "first-own-scope-required") : return
        if entry.name <> "Profiles Test"
            ' Earlier one-shot provisioning used Update for a name, but that
            ' API intentionally ignores names. Repair only this already-bound
            ' two-test-account connection through the normal rename model.
            renamed = connectionStoreRename(entries, entry.id, "Profiles Test")
            if renamed = invalid then finishRealProfileSync(false, "test-name-refused") : return
            if not saveConnectionStore(m.registry, renamed) then finishRealProfileSync(false, "test-name-not-saved") : return
            m.connectionStore = renamed
            print "[real-sync] "; FormatJson({kind: "test-name-restored", preserved: true})
            return
        end if
        if m.realSyncConfig.mode = "off"
            m.profileSyncControlsReady = true
            if loadDispatcharrSyncSettings(m.registry).enabled
                openDispatcharrSyncControls()
                if m.connectionDialog = invalid then finishRealProfileSync(false, "cleanup-menu-unavailable") : return
                onConnectionChoice(realSyncEvent(m.connectionDialog, 0))
                onConnectionChoice(realSyncEvent(m.connectionDialog, 2))
            end if
            finishRealProfileSync(not loadDispatcharrSyncSettings(m.registry).enabled, "test-sync-off")
            return
        end if
        if m.realSyncBaselineWriterReady <> true or m.realSyncBaselineSchedulingReady <> true or m.realSyncBaselineControlsReady <> true then finishRealProfileSync(false, "qualified-baseline-required") : return
        m.profileSyncWriterReady = m.realSyncBaselineWriterReady
        m.profileSyncSchedulingReady = m.realSyncBaselineSchedulingReady
        m.profileSyncControlsReady = m.realSyncBaselineControlsReady
        openDispatcharrSyncControls()
        if m.connectionDialog = invalid then finishRealProfileSync(false, "consent-menu-unavailable") : return
        if loadDispatcharrSyncSettings(m.registry).enabled then finishRealProfileSync(false, "explicit-off-start-required") : return
        onConnectionChoice(realSyncEvent(m.connectionDialog, 0))
        if not loadDispatcharrSyncSettings(m.registry).enabled then finishRealProfileSync(false, "consent-not-saved") : return
        onConnectionChoice(realSyncEvent(m.connectionDialog, 2))
        m.realSyncStage = 1
        return
    end if
    if stage = 1
        if not m.realSyncWrites.doesExist(m.realSyncFirst)
            if m.realSyncSettled <> true or m.realSyncFirstEdited = true then return
            if m.profileScheduledSyncTask <> invalid or m.profileSyncWriteTask <> invalid then return
            store = loadUserProfileStore(m.registry, m.selectedConnectionId)
            name = "Test 1"
            for each profile in store.profiles
                if profile.id = m.realSyncFirst and profile.displayName = name then name = m.realSyncConfig.first
            end for
            if not renameRealSyncHolder(m.realSyncFirst, name) then finishRealProfileSync(false, "first-edit-refused") : return
            m.realSyncFirstEdited = true
            return
        end if
        if m.profileScheduledSyncTask <> invalid or m.profileSyncWriteTask <> invalid then return
        if not beginUserProfileSwitch(m.realSyncSecond) then finishRealProfileSync(false, "second-switch-refused") : return
        m.realSyncStage = 2
        return
    end if
    if stage = 2
        if m.profileSwitchContext <> invalid or m.profileScheduledSyncTask <> invalid then return
        if m.page <> "guide" or m.activeUserScope = invalid then return
        if m.activeUserScope.profileId <> m.realSyncSecond then finishRealProfileSync(false, "second-own-scope-required") : return
        store = loadUserProfileStore(m.registry, m.selectedConnectionId)
        name = "Test 2"
        for each profile in store.profiles
            if profile.id = m.realSyncSecond and profile.displayName = name then name = m.realSyncConfig.second
        end for
        if not renameRealSyncHolder(m.realSyncSecond, name) then finishRealProfileSync(false, "second-edit-refused") : return
        m.realSyncStage = 3
        return
    end if
    if stage = 3
        if not m.realSyncWrites.doesExist(m.realSyncSecond) then return
        if m.profileScheduledSyncTask <> invalid or m.profileSyncWriteTask <> invalid then return
        if not beginUserProfileSwitch(m.realSyncFirst) then finishRealProfileSync(false, "first-return-refused") : return
        m.realSyncStage = 4
        return
    end if
    if m.profileSwitchContext <> invalid or m.profileScheduledSyncTask <> invalid then return
    if m.page <> "guide" or m.activeUserScope = invalid then return
    if m.activeUserScope.profileId <> m.realSyncFirst then finishRealProfileSync(false, "first-return-scope-refused") : return
    openDispatcharrSyncControls()
    if m.connectionDialog = invalid then return
    print "[real-sync] "; FormatJson({kind: "off-choice", enabledBefore: loadDispatcharrSyncSettings(m.registry).enabled, setupAllowed: userProfileConnectionSetupAllowed(), action: m.connectionChoices[0].action, intendedValue: m.connectionChoices[0].value})
    onConnectionChoice(realSyncEvent(m.connectionDialog, 0))
    if loadDispatcharrSyncSettings(m.registry).enabled then finishRealProfileSync(false, "off-not-saved") : return
    onConnectionChoice(realSyncEvent(m.connectionDialog, 2))
    finishRealProfileSync(m.realSyncWrites.count() = 2, "two-own-writes-acknowledged-sync-off")
end sub

sub traceRealSyncStartup(context as object)
    storage = userProfileStartupSelectionStorageCurrent(m.registry, context, context.nonce, m.activeUserScope, textValue(m.apiKey), context.memoryKeys, false)
    admitted = userProfileStartupSelectionCurrent(m.registry, context, context.nonce, m.activeUserScope, textValue(m.apiKey), context.memoryKeys, false)
    print "[real-sync] "; FormatJson({kind: "startup-preflight", storage: storage, admitted: admitted, noActor: m.activeUserScope = invalid, emptyKey: textValue(m.apiKey) = ""})
end sub
