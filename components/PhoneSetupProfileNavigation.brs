' Developer-only receiver integration. Public receiver/security gates are not
' changed here. A phone payload never supplies a PIN grant or Sync consent.
sub beginPhoneProfileVerification(payload as object, prepared as object)
    retirePhoneProfileImport()
    identity = phoneSetupPlaylistIdentityPlan(m.connectionStore, payload.playlist.id, prepared.entry.id)
    if not identity.ok then failPhoneSetup("Could not match the playlist ID. Saved connections were not changed.") : return
    prepared.entry.id = identity.id
    heldSelectedAddress = false
    previous = connectionStoreEntry(m.connectionStore, identity.matchedId)
    if previous <> invalid
        if previous.provider <> "dispatcharr"
            failPhoneSetup("This playlist ID belongs to another provider.")
            return
        end if
        if previous.url <> prepared.url
            if m.activeUserScope <> invalid
                if not persistCurrentUserProfilePreferences() then failPhoneSetup("Could not preserve the current profile.") : return
            end if
            held = phoneSetupHoldMatchedAddress(m.registry, m.connectionStore, previous.id, prepared.url)
            if not held.ok
                if held.recoveryRequired = true then m.phoneRecoveryRequired = true
                failPhoneSetup("Could not safely hold profiles before changing the saved address.")
                return
            end if
            if type(m.profileSessionKeys) = "roAssociativeArray"
                for each profile in held.previous.profiles
                    m.profileSessionKeys.delete(preferenceScope(previous.url + "|" + previous.id + "|" + profile.id))
                    m.profileSessionKeys.delete(preferenceScope(prepared.url + "|" + previous.id + "|" + profile.id))
                end for
            end if
            selectedChanged = previous.id = m.selectedConnectionId
            heldSelectedAddress = selectedChanged
            if selectedChanged then resetConnectionRuntime()
            m.connectionStore = held.connections
            if selectedChanged then applySelectedConnection()
            m.page = "phoneSetup"
            m.phoneStoreSnapshot = FormatJson(m.connectionStore)
        end if
    end if
    nonce = CreateObject("roDeviceInfo").getRandomUUID()
    m.phoneProfileImport = {nonce: nonce, phase: "default", matchedId: identity.matchedId, connectionRoot: m.registry.read("connectionsV1"), rows: [], proofs: {}, privateProfiles: copyJson(payload.profiles), incomingSync: payload.sync}
    m.phoneProfileImport.heldSelectedAddress = heldSelectedAddress
    task = CreateObject("roSGNode", "PhoneSetupProfileVerifyTask")
    tagTaskForCurrentUser(task)
    task.baseUrl = prepared.url
    task.authMode = prepared.entry.authMode
    task.userAgent = prepared.entry.userAgent
    task.captureNonce = nonce
    task.defaultOnly = true
    task.defaultCredential = copyJson(prepared.credential)
    task.profiles = copyJson(payload.profiles)
    task.observeField("result", "onPhoneProfileVerification")
    m.phoneProfileVerifyTask = task
    m.phonePending = prepared
    m.phoneSetup.phase = "Verifying supplied profiles"
    m.phoneSetup.retryAvailable = false
    task.control = "RUN"
end sub

function phoneProfileDefaultVerificationCurrent() as boolean
    if m.profilePhoneImportReady <> true or type(m.phoneProfileImport) <> "roAssociativeArray" then return false
    context = m.phoneProfileImport
    if context.phase <> "default" or context.connectionRoot <> m.registry.read("connectionsV1") then return false
    if type(m.phonePending) <> "roAssociativeArray" or type(context.proofs) <> "roAssociativeArray" then return false
    for each name in context.proofs
        proof = context.proofs[name]
        if proof.ok = true and proof.verifiedBaseUrl = m.phonePending.url and proof.apiKey = m.phonePending.credential.apiKey then return true
    end for
    return false
end function

sub onPhoneProfileVerification(event as object)
    if not isCurrentTaskEvent(event, m.phoneProfileVerifyTask) then return
    context = m.phoneProfileImport
    result = event.getData()
    closePhoneProfileVerificationTask()
    if context = invalid or m.page <> "phoneSetup" or m.phoneSetup.active <> true then retirePhoneProfileImport() : return
    if context.connectionRoot <> m.registry.read("connectionsV1") then failPhoneProfileImport("Saved connections changed. Send setup again.") : return
    if type(result) <> "roAssociativeArray" then failPhoneProfileImport("Could not verify profiles. Send setup again.") : return
    if result.ok <> true or result.nonce <> context.nonce then failPhoneProfileImport("Could not verify profiles. Send setup again.") : return
    context.rows = result.rows
    context.proofs = result.proofs
    context.rateLimited = result.rateLimited
    if context.phase = "remaining"
        finishPhoneProfileCommit()
        return
    end if
    proof = context.proofs[lcase(result.baseUsername)]
    m.phonePending.credential = {apiKey: proof.apiKey, username: "", password: ""}
    ' Existing live-lineup verification and duplicate confirmation remain the
    ' common provider path; no profile is exposed by the credential service.
    startPhoneVerification()
end sub

sub failPhoneProfileImport(message as string)
    committed = false
    if type(m.phoneProfileImport) = "roAssociativeArray" then committed = m.phoneProfileImport.saved <> invalid
    retirePhoneProfileImport()
    m.phonePending = invalid
    failPhoneSetup(message)
    if committed or m.phoneRecoveryRequired = true
        m.phoneRecoveryRequired = true
        m.phoneSetup.retryAvailable = false
        m.phoneSetup.phase = "Profile import is incomplete. The saved playlist remains locked pending recovery."
    end if
end sub

' Commit the verified playlist BEFORE any nondefault password/key attempts.
' The fence is deliberately retained while the remaining bounded Task runs.
sub startPhoneProfileCommit(staged as object)
    context = m.phoneProfileImport
    if context = invalid or context.connectionRoot <> m.registry.read("connectionsV1") then failPhoneProfileImport("Saved connections changed. Send setup again.") : return
    entry = connectionStoreEntry(staged, staged.selected)
    if entry = invalid then failPhoneProfileImport("Could not stage the playlist.") : return
    previous = loadUserProfileStore(m.registry, entry.id)
    admin = userProfileLoadDeviceAdminPin(m.registry, entry.id)
    if previous.readOnly = true or not admin.ok then failPhoneProfileImport("Saved profiles need recovery.") : return
    if m.activeUserScope <> invalid
        if not persistCurrentUserProfilePreferences() then failPhoneProfileImport("Could not preserve the current profile.") : return
    end if
    if not phoneSetupCommitAdmissionCurrent() then failPhoneProfileImport("Profile access changed. Reopen phone setup to try again.") : return
    context.commitActor = m.activeUserScope
    context.commitActorUrl = m.baseUrl
    context.commitActorKey = textValue(m.apiKey)
    if context.commitActor <> invalid and context.commitActor.playlistId = entry.id
        originalEntry = connectionStoreEntry(m.connectionStore, entry.id)
        if originalEntry = invalid then failPhoneProfileImport("Saved profile access changed.") : return
        context.commitActorConnection = originalEntry
        for each holder in previous.profiles
            if holder.id = previous.active and holder.id = context.commitActor.profileId and holder.isDefault and originalEntry.remember = true and entry.remember = true
                originalKey = phoneSetupOwnCredential(originalEntry, previous, holder)
                context.replacedActorDefaultKey = originalKey.ok and originalKey.profileId = holder.id and originalKey.key = context.commitActorKey and originalKey.key <> textValue(m.phoneResult.apiKey)
            end if
        end for
        if context.replacedActorDefaultKey <> true and not phoneSetupFencedActorCredentialCurrent(context, previous)
            failPhoneProfileImport("Saved profile access changed.")
            return
        end if
    end if
    saved = phoneSetupCommitFencedConnection(m.registry, m.connectionStore, staged, textValue(m.phoneResult.apiKey), context.nonce)
    if not saved.ok
        if saved.recoveryRequired = true then m.phoneRecoveryRequired = true
        failPhoneProfileImport("Could not save the verified playlist.")
        return
    end if
    context.saved = saved
    context.connection = entry
    context.previous = previous
    context.deviceAdmin = admin.record
    context.connectionRoot = m.registry.read("connectionsV1")
    context.phase = "remaining"
    task = CreateObject("roSGNode", "PhoneSetupProfileVerifyTask")
    tagTaskForCurrentUser(task)
    task.baseUrl = entry.url
    task.authMode = entry.authMode
    task.userAgent = entry.userAgent
    task.captureNonce = context.nonce
    task.defaultCredential = {apiKey: m.phoneResult.apiKey}
    task.verifiedDefault = context.proofs[lcase(entry.accountUsername)]
    task.profiles = context.privateProfiles
    context.privateProfiles = []
    task.observeField("result", "onPhoneProfileVerification")
    m.phoneProfileVerifyTask = task
    m.phoneSetup.phase = "Playlist saved. Verifying the other supplied profiles"
    m.phoneSetup.retryAvailable = false
    task.control = "RUN"
end sub

sub finishPhoneProfileCommit()
    context = m.phoneProfileImport
    entry = context.connection
    ' The first flush deliberately fences the target; its exact journal/root,
    ' prior roster (including PIN), and verified key must still own phase two.
    if context.commitActor <> invalid
        if not userProfileSameSession(context.commitActor, m.activeUserScope) or currentUserSessionId() <> context.commitActor.sessionId or userProfileGateClosed()
            failPhoneProfileImport("Profile access changed. Reopen phone setup to try again.")
            return
        end if
        if textValue(m.apiKey) = "" or not requestGateAccessAllowed(context.commitActorUrl, textValue(m.apiKey))
            failPhoneProfileImport("Profile access changed. Reopen phone setup to try again.")
            return
        end if
        if context.commitActor.playlistId = entry.id
            if not phoneSetupFencedActorCredentialCurrent(context, context.previous) then failPhoneProfileImport("Saved profile access changed.") : return
        else
            if not phoneSetupCommitAdmissionCurrent() then failPhoneProfileImport("Profile access changed. Reopen phone setup to try again.") : return
        end if
    else if m.activeUserScope <> invalid
        failPhoneProfileImport("Profile access changed. Reopen phone setup to try again.")
        return
    end if
    if entry.remember and m.registry.read(connectionRegistryKey(entry.id)) <> textValue(m.phoneResult.apiKey)
        failPhoneProfileImport("Saved connection credentials changed.")
        return
    end if
    ids = {defaultId: CreateObject("roDeviceInfo").getRandomUUID(), byUsername: {}}
    for each profile in context.previous.profiles
        if profile.isDefault then ids.defaultId = profile.id
    end for
    for each row in context.rows
        ids.byUsername[lcase(row.username)] = CreateObject("roDeviceInfo").getRandomUUID()
    end for
    batch = {nonce: context.nonce, connection: entry, connectionRoot: context.connectionRoot, store: context.previous, rows: context.rows, proofs: context.proofs, ids: ids, deviceAdmin: context.deviceAdmin, importRoot: context.saved.importRoot}
    applied = commitPhoneSetupProfileBatch(m.registry, batch, CreateObject("roDateTime").asSeconds(), context.nonce)
    if not applied.ok then failPhoneProfileImport("Profile import did not finish.") : return
    context.skipped = applied.skipped
    context.saved.profiles = applied.store
    continuePhoneProfileImport(context.saved, m.phonePending, m.phoneResult)
end sub

sub continuePhoneProfileImport(saved as object, pending as object, result as object)
    context = m.phoneProfileImport
    entry = connectionStoreEntry(saved.store, saved.store.selected)
    ' Retain only verified nondefault session keys when Remember is off.
    if not entry.remember
        if type(m.profileSessionKeys) <> "roAssociativeArray" then m.profileSessionKeys = {}
        for each profile in saved.profiles.profiles
            proof = context.proofs[lcase(profile.username)]
            if type(proof) = "roAssociativeArray"
                bucket = preferenceScope(entry.url + "|" + entry.id + "|" + profile.id)
                m.profileSessionKeys[bucket] = proof.apiKey
            end if
        end for
    end if
    summary = "Profiles imported."
    if context.skipped.count() > 0 then summary = "Profiles imported. Some supplied profiles could not be added."
    if context.rateLimited = true then summary = "Profiles imported partially. The server asked us to wait."
    m.phoneSetup.active = false
    m.phoneSetup.visible = false
    m.phonePending = invalid
    m.phoneResult = invalid
    resetConnectionRuntime()
    m.connectionStore = saved.store
    m.selectedConnectionId = entry.id
    applySelectedConnection()
    m.apiKey = result.apiKey
    m.userProfileStore = saved.profiles
    m.phoneOptions = entry
    m.phoneCommittedId = entry.id
    m.phoneProfileOnboarding = {slot: entry.id, phase: "offer", incomingSync: context.incomingSync, addedIds: [], connectionRoot: m.registry.read("connectionsV1")}
    retirePhoneProfileImport()
    m.page = "setup"
    m.profileRefreshReload = true
    drawSetup()
    ' Existing startup selection/admission enforces imported default PIN/Child;
    ' the phone's verified credential is never treated as a PIN grant.
    if not beginUserProfileLaunchPicker(false) then connectServer(true)
    showNotice(summary)
end sub

sub closePhoneProfileVerificationTask()
    task = m.phoneProfileVerifyTask
    m.phoneProfileVerifyTask = invalid
    if task = invalid then return
    task.unobserveField("result")
    cancelNetworkTask(task)
    task.defaultCredential = invalid
    task.verifiedDefault = invalid
    task.profiles = []
    task.result = invalid
end sub

sub retirePhoneProfileImport()
    closePhoneProfileVerificationTask()
    context = m.phoneProfileImport
    if type(context) = "roAssociativeArray"
        if type(context.privateProfiles) = "roArray"
            for each row in context.privateProfiles
                if type(row.credential) = "roAssociativeArray"
                    for each key in row.credential
                        if lcase(key) = "password" or lcase(key) = "apikey" then row.credential[key] = ""
                    end for
                end if
            end for
        end if
        if type(context.proofs) = "roAssociativeArray"
            for each name in context.proofs
                context.proofs[name].apiKey = ""
            end for
        end if
    end if
    m.phoneProfileImport = invalid
end sub

function showIncompletePhoneImportRecovery() as boolean
    key = userProfileImportKey(textValue(m.selectedConnectionId))
    if key = "" then return false
    if not m.registry.exists(key) then return false
    if m.phoneImportRecoveryDialog <> invalid then return true
    if m.activeUserScope <> invalid or m.profilePinDialog <> invalid or m.adultPinDialog <> invalid then return false
    m.apiKey = ""
    m.global.profilegateclosed = true
    m.profileGateCover.visible = true
    m.phoneImportRecoveryContext = {slot: m.selectedConnectionId, root: m.registry.read(key), connections: loadConnectionStore(m.registry)}
    dialog = CreateObject("roSGNode", "AerioDialog")
    dialog.title = "Phone setup did not finish"
    dialog.message = "This playlist is locked because its profiles were not fully saved. Discard the incomplete setup? Existing profile protection and personal data are kept. Sign in again before using the restored playlist."
    dialog.buttons = ["Discard incomplete setup", "Cancel"]
    dialog.observeField("buttonSelected", "onIncompletePhoneImportRecovery")
    dialog.observeField("wasClosed", "onIncompletePhoneImportRecoveryClosed")
    m.phoneImportRecoveryDialog = dialog
    m.top.dialog = dialog
    dialog.setFocus(true)
    return true
end function

sub onIncompletePhoneImportRecovery(event as object)
    dialog = m.phoneImportRecoveryDialog
    if dialog = invalid then return
    if not dialog.isSameNode(event.getRoSGNode()) then return
    context = m.phoneImportRecoveryContext
    choice = event.getData()
    m.phoneImportRecoveryFailure = "choice"
    closeIncompletePhoneImportRecovery()
    if choice <> 0 or type(context) <> "roAssociativeArray" then return
    m.phoneImportRecoveryFailure = "stale-ui"
    if context.slot <> m.selectedConnectionId or m.activeUserScope <> invalid then return
    saved = phoneSetupDiscardIncompleteImport(m.registry, context.connections, context.slot, context.root)
    if not saved.ok
        m.phoneImportRecoveryFailure = saved.reason
        m.top.findNode("profileGateMessage").text = "Could not recover incomplete setup. The playlist remains locked. Back exits AerioTV."
        return
    end if
    m.phoneImportRecoveryFailure = ""
    resetConnectionRuntime()
    m.connectionStore = saved.connections
    m.selectedConnectionId = saved.connections.selected
    applySelectedConnection()
    m.phoneRecoveryRequired = false
    m.profileUnlockGrant = invalid
    m.pendingLaunch = invalid
    m.global.profilegateclosed = false
    m.profileGateCover.visible = false
    if connectionWelcomeNeeded(saved.connections) then drawWelcome() else drawSetup()
end sub

sub onIncompletePhoneImportRecoveryClosed(event as object)
    if m.phoneImportRecoveryDialog = invalid then return
    if not m.phoneImportRecoveryDialog.isSameNode(event.getRoSGNode()) then return
    closeIncompletePhoneImportRecovery()
end sub

sub closeIncompletePhoneImportRecovery()
    dialog = m.phoneImportRecoveryDialog
    m.phoneImportRecoveryDialog = invalid
    m.phoneImportRecoveryContext = invalid
    if dialog = invalid then return
    dialog.unobserveField("buttonSelected")
    dialog.unobserveField("wasClosed")
    dialog.close = true
    if m.top.dialog <> invalid
        if m.top.dialog.isSameNode(dialog) then m.top.dialog = invalid
    end if
end sub
