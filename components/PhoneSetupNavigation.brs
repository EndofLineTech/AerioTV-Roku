' The receiver has already written 200. Verification and user confirmation occur
' here without touching the selected connection or its stored credential.
sub openPhoneSetup()
    if not userProfileConnectionSetupAllowed() then return
    if userProfileGateClosed() then return
    if m.busy or (m.page <> "setup" and m.page <> "welcome") then return
    if m.phoneRecoveryRequired = true
        showNotice("Restart AerioTV to reload saved connections before trying setup again.")
        return
    end if
    if m.connectionStore.readOnly = true
        showNotice("Saved connections need recovery; setup will not overwrite them.")
        return
    end if
    profileGate = phoneSetupSelectedProfileGate()
    if not profileGate.allowed
        showNotice(userProfileGateMessage(profileGate))
        return
    end if
    m.phoneOriginPage = m.page
    cancelProfileTask()
    cancelCapabilityRefresh()
    m.phonePending = invalid
    m.phoneResult = invalid
    m.phoneMatchedId = ""
    m.page = "phoneSetup"
    m.phoneSetup.visible = true
    m.phoneSetup.active = true
    m.phoneSetup.setFocus(true)
end sub

' Startup/picker admission consumes its one-shot PIN grant. Only reuse the
' resulting admission for the same live adult session and unchanged saved PIN.
function phoneSetupSelectedProfileGate() as object
    gate = selectedUserProfileGate()
    if gate.reason <> "pin" then return gate
    admission = m.phoneSetupPinAdmission
    scope = m.activeUserScope
    if type(admission) <> "roAssociativeArray" or type(scope) <> "roAssociativeArray" then return gate
    if not userProfileSameSession(admission.scope, scope) then return gate
    if currentUserSessionId() <> scope.sessionId or userProfileGateClosed() then return gate
    entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    if entry = invalid then return gate
    if entry.id <> scope.playlistId or entry.url <> m.baseUrl or textValue(m.apiKey) = "" then return gate
    if connectionPreferenceIdentity(entry, scope.accountId) <> scope.preferenceIdentity then return gate
    for each profile in m.userProfileStore.profiles
        if profile.id = m.userProfileStore.active and profile.id = scope.profileId
            if not userProfileFullAccess(profile.role) or profile.addressHeld = true or profile.userId.toStr() <> scope.accountId then return gate
            if not userProfilePinGrantMatches(admission.pin, entry.id, profile) then return gate
            credential = phoneSetupOwnCredential(entry, m.userProfileStore, profile)
            if credential.ok and credential.profileId = scope.profileId and credential.key = m.apiKey and requestGateAccessAllowed(entry.url, credential.key)
                return {allowed: true, reason: ""}
            end if
        end if
    end for
    return gate
end function

function phoneSetupOwnCredential(entry as object, store as object, profile as object) as object
    memory = {}
    if entry.remember <> true and type(m.profileSessionKeys) = "roAssociativeArray"
        bucket = preferenceScope(entry.url + "|" + entry.id + "|" + profile.id)
        keyName = userProfileKeyName(entry.id, profile.id)
        if profile.isDefault then keyName = connectionRegistryKey(entry.id)
        if m.profileSessionKeys.doesExist(bucket) then memory[keyName] = m.profileSessionKeys[bucket]
    end if
    return userProfileCredential(m.registry, entry, store, memory)
end function

' The fenced slot cannot use the ordinary loader until phase two. Its caller
' separately verifies the original roster digest and exact import journal.
function phoneSetupFencedActorCredentialCurrent(context as object, originalStore as object) as boolean
    scope = context.commitActor
    entry = context.commitActorConnection
    if type(scope) <> "roAssociativeArray" or type(entry) <> "roAssociativeArray" then return false
    if originalStore.active <> scope.profileId or entry.id <> scope.playlistId then return false
    if textValue(m.apiKey) = "" or m.apiKey <> context.commitActorKey then return false
    for each profile in originalStore.profiles
        if profile.id = scope.profileId
            if not userProfileFullAccess(profile.role) or profile.addressHeld = true or profile.userId.toStr() <> scope.accountId then return false
            ' Only the persistent default slot key can be overwritten by flush one.
            if context.replacedActorDefaultKey = true and profile.isDefault and entry.remember = true
                writtenKey = textValue(m.phoneResult.apiKey)
                return writtenKey <> "" and writtenKey <> context.commitActorKey and m.registry.read(connectionRegistryKey(entry.id)) = writtenKey
            end if
            own = phoneSetupOwnCredential(entry, originalStore, profile)
            return own.ok and own.profileId = scope.profileId and own.key = m.apiKey
        end if
    end for
    return false
end function

sub onPhoneSetupPayload(event as object)
    if not m.phoneSetup.isSameNode(event.getRoSGNode()) then return
    payload = event.getData()
    m.phoneSetup.payload = invalid
    if type(payload) = "roAssociativeArray" then acceptPhoneSetupPayload(payload)
end sub

sub acceptPhoneSetupPayload(payload as object)
    if m.page <> "phoneSetup" or not m.phoneSetup.active then return
    if not userProfileConnectionSetupAllowed() or not phoneSetupSelectedProfileGate().allowed
        m.phonePending = invalid
        failPhoneSetup("Profile access changed. Reopen phone setup to try again.")
        m.phoneSetup.retryAvailable = false
        return
    end if
    digest = ""
    if payload.playlist.type = "m3u" then digest = metadataCacheDigest("m3u|" + phoneSetupFeedIdentity(payload.playlist.url))
    profilesReady = m.profilePhoneImportReady = true and payload.playlist.type = "dispatcharr"
    prepared = phoneSetupPrepareImport(payload, CreateObject("roDeviceInfo").getRandomUUID(), digest, profilesReady)
    if not prepared.ok
        m.phonePending = invalid
        failPhoneSetup(prepared.message)
        return
    end if
    m.phonePending = prepared
    m.phoneStoreSnapshot = formatJson(m.connectionStore)
    if profilesReady
        prepared.phoneProfilesRequired = true
        beginPhoneProfileVerification(payload, prepared)
        return
    end if
    startPhoneVerification()
end sub

sub stopPhoneVerification()
    m.phoneClock.control = "stop"
    if m.phoneVerifyTask = invalid then return
    task = m.phoneVerifyTask
    m.phoneVerifyTask = invalid
    task.unobserveField("result")
    task.unobserveField("progress")
    cancelNetworkTask(task)
    for each field in ["apiKey", "username", "password", "url"]
        if task.hasField(field) then task[field] = ""
    end for
    task.result = invalid
end sub

sub startPhoneVerification()
    if not userProfileConnectionSetupAllowed() then return
    stopPhoneVerification()
    if m.phonePending = invalid or m.page <> "phoneSetup" then return
    if m.phonePending.phoneProfilesRequired = true and m.phoneProfileImport = invalid
        m.phonePending = invalid
        failPhoneSetup("Send profile setup again to verify all required protection.")
        return
    end if
    profileGate = phoneSetupSelectedProfileGate()
    if m.phoneProfileImport <> invalid
        if phoneSetupHeldAddressCurrent(m.phoneProfileImport) and phoneProfileDefaultVerificationCurrent() then profileGate = {allowed: true}
    end if
    if not profileGate.allowed
        m.phonePending = invalid
        failPhoneSetup(userProfileGateMessage(profileGate))
        return
    end if
    entry = m.phonePending.entry
    credential = m.phonePending.credential
    if entry.provider = "m3u"
        task = CreateObject("roSGNode", "M3uTask")
        tagTaskForCurrentUser(task)
        task.url = m.phonePending.url
        task.connectionId = entry.id
    else if entry.provider = "xtream"
        task = CreateObject("roSGNode", "XtreamTask")
        tagTaskForCurrentUser(task)
        task.baseUrl = m.phonePending.url
        task.connectionId = entry.id
        task.username = credential.username
        task.password = credential.password
    else
        task = CreateObject("roSGNode", "DispatcharrTask")
        tagTaskForCurrentUser(task)
        task.baseUrl = m.phonePending.url
        task.cacheEpoch = m.global.cacheEpoch
        task.authMode = entry.authMode
        task.channelProfileIds = entry.channelProfileIds
        task.apiKey = credential.apiKey
        if credential.apiKey = ""
            task.username = credential.username
            task.password = credential.password
        end if
    end if
    ' Explicit blanks mean defaults for THIS candidate, never the old slot's UA
    ' or Referer. Globals are not changed during verification.
    task.requestIdentity = {userAgent: entry.userAgent, referer: ""}
    task.observeField("result", "onPhoneVerified")
    task.observeField("progress", "onPhoneVerificationProgress")
    m.phoneVerifyTask = task
    m.phoneElapsed = CreateObject("roTimespan")
    m.phoneElapsed.mark()
    m.phoneSetup.retryAvailable = false
    m.phoneSetup.phase = "Verifying playlist and live channels"
    m.phoneClock.control = "start"
    task.control = "RUN"
end sub

sub onPhoneVerificationProgress(event as object)
    if not isCurrentTaskEvent(event, m.phoneVerifyTask) then return
    if m.page = "phoneSetup" then m.phoneSetup.phase = event.getData()
end sub

sub onPhoneVerified(event as object)
    if isCurrentTaskEvent(event, m.phoneVerifyTask) then finishPhoneVerification(event.getData())
end sub

sub onPhoneVerificationTick()
    if m.phoneVerifyTask = invalid then return
    if m.phoneVerifyTask.state = "done" or m.phoneVerifyTask.state = "stop"
        finishPhoneVerification(m.phoneVerifyTask.result)
    else if m.phoneElapsed.totalSeconds() >= 120
        failPhoneSetup("Verification timed out. Saved connections were not changed.")
    end if
end sub

sub finishPhoneVerification(result as dynamic)
    if m.phoneVerifyTask = invalid or m.phonePending = invalid or m.page <> "phoneSetup" then return
    verified = phoneSetupVerifiedImport(m.phonePending, result)
    stopPhoneVerification()
    if not verified.ok
        failPhoneSetup(verified.message)
        return
    end if
    m.phonePending = verified
    m.phoneResult = result
    m.phoneMatchedId = ""
    showPhoneSetupConfirmation()
end sub

sub failPhoneSetup(message as string)
    stopPhoneVerification()
    m.phoneResult = invalid
    m.phoneSetup.phase = message
    m.phoneSetup.retryAvailable = true
    m.phoneSetup.setFocus(true)
end sub

sub onPhoneSetupRetry()
    if m.page <> "phoneSetup" then return
    if m.phonePending <> invalid
        startPhoneVerification()
    else
        m.phoneSetup.active = false
        m.phoneSetup.active = true
    end if
end sub

sub closePhoneSetupDialog()
    if m.phoneDialog = invalid then return
    m.phoneDialog.unobserveField("buttonSelected")
    m.phoneDialog.unobserveField("wasClosed")
    m.phoneDialog.close = true
    m.phoneDialog = invalid
end sub

sub onPhoneSetupClosed()
    incomplete = m.phoneFailedImport
    if type(m.phoneProfileImport) = "roAssociativeArray"
        if m.phoneProfileImport.saved <> invalid then incomplete = {slot: m.phoneProfileImport.connection.id, root: m.phoneProfileImport.saved.importRoot, restartRequired: false}
    end if
    if m.phoneProfileImport <> invalid or m.phoneProfileVerifyTask <> invalid then retirePhoneProfileImport()
    closePhoneSetupDialog()
    stopPhoneVerification()
    m.phoneSetup.active = false
    m.phoneSetup.visible = false
    m.phonePending = invalid
    m.phoneResult = invalid
    if type(incomplete) = "roAssociativeArray" and m.page = "phoneSetup"
        resetConnectionRuntime()
        ' Only offer discard for the same readable journal on the same slot.
        ' An unsuccessful rollback leaves registry state uncertain in this run.
        if not incomplete.restartRequired
            connections = loadConnectionStore(m.registry)
            key = userProfileImportKey(incomplete.slot)
            if connections.readOnly <> true and connections.selected = incomplete.slot and key <> "" and incomplete.root <> ""
                if m.registry.exists(key) and m.registry.read(key) = incomplete.root
                    m.connectionStore = connections
                    m.selectedConnectionId = incomplete.slot
                    applySelectedConnection()
                    if showIncompletePhoneImportRecovery() then return
                end if
            end if
        end if
        coverProfileManagementRecovery("Phone setup storage needs recovery. Restart AerioTV before using saved connections.")
        return
    end if
    if m.page <> "phoneSetup" then return
    m.page = m.phoneOriginPage
    if m.page = "welcome" then drawWelcome() else drawSetup()
    m.top.setFocus(true)
end sub

sub onPhoneSetupDialogClosed(event as object)
    if not isCurrentTaskEvent(event, m.phoneDialog) then return
    onPhoneSetupClosed()
end sub

sub showPhoneSetupConfirmation()
    if not userProfileConnectionSetupAllowed() then return
    closePhoneSetupDialog()
    matches = phoneSetupDuplicateIds(m.connectionStore, m.phonePending.entry)
    if type(m.phoneProfileImport) = "roAssociativeArray"
        if m.phoneProfileImport.matchedId <> ""
            m.phoneMatchedId = m.phoneProfileImport.matchedId
            commitPhoneSetup("replace")
            return
        end if
    end if
    m.phoneMatches = matches
    if matches.count() = 0
        if m.connectionStore.entries.count() >= 4
            failPhoneSetup("All four connection slots are occupied. Cancel and forget a slot before importing another playlist.")
            m.phoneSetup.retryAvailable = false
            return
        end if
        ' Sending from the phone authorizes addition, not replacement. Keep the
        ' verification, stale-store and atomic-commit gates; no second Save step.
        commitPhoneSetup("add")
        return
    end if
    dialog = CreateObject("roSGNode", "AerioDialog")
    m.phoneDialogMode = "confirm"
    if matches.count() > 1 and m.phoneMatchedId = ""
        dialog.title = "Choose the matching connection"
        dialog.message = "More than one saved slot matches this verified account. Choose which slot Replace would retain."
        labels = []
        for each id in matches
            labels.push(connectionStoreEntry(m.connectionStore, id).name)
        end for
        labels.push("Cancel")
        dialog.buttons = labels
        m.phoneDialogMode = "match"
    else
        if matches.count() = 1 then m.phoneMatchedId = matches[0]
        message = "Verified live channels. "
        if m.phonePending.entry.provider = "dispatcharr" then message += "Replace keeps this connection's Remember choice. Add Anyway remembers the key in a new slot. "
        if m.phonePending.entry.provider = "xtream" then message += "Xtream credentials are session-only; enter or send them again after restarting. "
        for each note in m.phonePending.notes
            message += note + " "
        end for
        dialog.message = message
        dialog.title = "This playlist is already saved"
        dialog.buttons = ["Cancel", "Add Anyway", "Replace"]
    end if
    dialog.observeField("buttonSelected", "onPhoneSetupChoice")
    dialog.observeField("wasClosed", "onPhoneSetupDialogClosed")
    m.phoneDialog = dialog
    m.top.dialog = dialog
    if matches.count() > 0 and m.phoneDialogMode = "confirm" then dialog.focusButton = 2
end sub

sub onPhoneSetupChoice(event as object)
    if not userProfileConnectionSetupAllowed() then return
    if not isCurrentTaskEvent(event, m.phoneDialog) or m.phonePending = invalid then return
    index = event.getData()
    mode = m.phoneDialogMode
    closePhoneSetupDialog()
    if mode = "match"
        if index < 0 or index >= m.phoneMatches.count()
            onPhoneSetupClosed()
        else
            m.phoneMatchedId = m.phoneMatches[index]
            showPhoneSetupConfirmation()
        end if
        return
    end if
    choice = "add"
    if m.phoneMatches.count() > 0
        if index = 0 then choice = "cancel"
        if index = 1 then choice = "addAnyway"
        if index = 2 then choice = "replace"
    else if index <> 0
        choice = "cancel"
    end if
    if choice = "cancel"
        onPhoneSetupClosed()
        return
    end if
    if choice = "addAnyway" and m.connectionStore.entries.count() >= 4
        showNotice("All four slots are occupied. Choose Replace or Cancel.")
        showPhoneSetupConfirmation()
        return
    end if
    commitPhoneSetup(choice)
end sub

sub commitPhoneSetup(choice as string)
    if not userProfileConnectionSetupAllowed() then return
    if m.phonePending = invalid or m.phoneResult = invalid then return
    if not phoneSetupCommitAdmissionCurrent()
        if m.phoneProfileImport <> invalid then retirePhoneProfileImport()
        m.phonePending = invalid
        failPhoneSetup("Profile access changed. Reopen phone setup to try again.")
        return
    end if
    if m.phonePending.phoneProfilesRequired = true and m.phoneProfileImport = invalid
        m.phonePending = invalid
        failPhoneSetup("Profile verification expired. Send setup again.")
        return
    end if
    if formatJson(m.connectionStore) <> m.phoneStoreSnapshot
        failPhoneSetup("Saved connections changed during verification. Cancel and send setup again.")
        m.phonePending = invalid
        return
    end if
    matchedById = false
    addressEdited = false
    if type(m.phoneProfileImport) = "roAssociativeArray"
        matchedById = m.phoneProfileImport.matchedId <> "" and m.phoneProfileImport.matchedId = m.phoneMatchedId
        addressEdited = m.phoneProfileImport.addressEdited = true
    end if
    staged = phoneSetupStageVerifiedConnection(m.connectionStore, m.phonePending.entry, choice, m.phoneMatchedId, matchedById, addressEdited)
    if staged = invalid
        failPhoneSetup("Could not stage this connection. Saved connections were not changed.")
        return
    end if
    m.phoneSetup.phase = "Saving verified connection"
    if m.phoneProfileImport <> invalid
        startPhoneProfileCommit(staged)
        return
    else
        saved = phoneSetupCommitConnection(m.registry, m.connectionStore, staged, textValue(m.phoneResult.apiKey))
    end if
    if not saved.ok
        failPhoneSetup(saved.message)
        if saved.recoveryRequired
            m.phonePending = invalid
            m.phoneRecoveryRequired = true
            m.phoneSetup.retryAvailable = false
            m.status = saved.message
        end if
        return
    end if
    pending = m.phonePending
    result = m.phoneResult
    if m.phoneProfileImport <> invalid
        continuePhoneProfileImport(saved, pending, result)
        return
    end if
    m.phonePending = invalid
    m.phoneResult = invalid
    m.phoneSetup.active = false
    m.phoneSetup.visible = false
    resetConnectionRuntime()
    m.connectionStore = saved.store
    m.selectedConnectionId = saved.store.selected
    applySelectedConnection()
    entry = connectionStoreEntry(saved.store, saved.store.selected)
    if entry.provider = "m3u" then m.baseUrl = pending.url
    m.username = pending.credential.username
    m.password = pending.credential.password
    m.phoneOptions = entry
    m.phoneCommittedId = entry.id
    m.connectionElapsed = m.phoneElapsed
    if entry.provider = "m3u" then result.scope = metadataCacheDigest("m3u|" + pending.url + "|" + entry.id)
    if entry.provider = "xtream" then result.scope = metadataCacheDigest("xc|" + pending.url + "|" + m.username + "|" + entry.id)
    notices = phoneSetupImportNotices({entry: entry, notes: pending.notes})
    summary = "Playlist added."
    if notices.count() > 0
        summary = "Playlist added. Setup notes: Settings > Diagnostics."
        if entry.provider = "xtream" or entry.sessionUrl = true then summary = "Playlist added (session-only). Setup notes: Settings > Diagnostics."
        warning = textValue(result.warning)
        if warning <> "" then warning += " "
        result.warning = warning + summary
    end if
    completeConnection(result)
    for each note in notices
        recordDiagnostic("connect", 0, note)
    end for
    if pending.multipleProfiles = true then summary = "Multiple profiles aren't currently supported on Roku. Stay tuned."
    showNotice(summary) ' Nonblocking; the guide is already active.
end sub

function phoneSetupCommitAdmissionCurrent() as boolean
    if phoneSetupHeldAddressCurrent(m.phoneProfileImport) then return phoneProfileDefaultVerificationCurrent()
    return userProfileConnectionSetupAllowed() and phoneSetupSelectedProfileGate().allowed
end function

' Only the original, already-authorized matched address edit may continue
' after intentionally retiring the selected actor and its old credential.
function phoneSetupHeldAddressCurrent(context as dynamic) as boolean
    if type(context) <> "roAssociativeArray" then return false
    if context.heldSelectedAddress <> true or context.matchedId <> m.selectedConnectionId then return false
    if m.activeUserScope <> invalid or textValue(m.apiKey) <> "" or userProfileGateClosed() then return false
    return context.connectionRoot = m.registry.read("connectionsV1")
end function

function takePhoneSetupPreferences(preferences as object, entry as object) as object
    if m.phoneOptions = invalid then return preferences
    if m.phoneOptions.id <> entry.id then return preferences
    result = phoneSetupImportedPreferences(preferences, m.phoneOptions)
    m.phoneOptions = invalid
    return result
end function
