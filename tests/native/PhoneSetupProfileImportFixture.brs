' Exercises the receiver controller in an isolated registry. Listener security
' and real sender interoperability are intentionally not bypassed or claimed.
sub onPhoneProfileImportProbeTick()
    stage = m.pickerProbeBaselineStage
    if stage = invalid then stage = 0
    if m.phoneImportLoggedStage <> stage
        m.phoneImportLoggedStage = stage
        print "[picker-launch] "; FormatJson({kind: "phone-import-state", stage: stage, page: m.page})
    end if
    if stage = 0
        taskState = ""
        if m.task <> invalid then taskState = m.task.state
        startupState = ""
        if m.profileStartupTask <> invalid then startupState = m.profileStartupTask.state
        state = FormatJson({kind: "phone-import-source-state", busy: m.busy, page: m.page, task: taskState, startupTask: startupState, gate: m.global.profilegateclosed, recovery: m.userProfileRecoveryRequired, hasKey: m.apiKey <> "", deferred: m.profileStartupDeferred, routing: m.profileStartupRoutingStarted})
        if m.phoneImportSourceState <> state
            m.phoneImportSourceState = state
            print "[picker-launch] "; state
        end if
        if m.busy or m.page <> "guide" then return
        private = ParseJson(ReadAsciiFile("pkg:/fixtures/phone-profile-verify.json"))
        pin = {pinType: "numbers", pinSalt: "00112233445566778899aabbccddeeff", pinHash: userProfilePinHash("00112233445566778899aabbccddeeff", "1234")}
        baseName = m.userProfileStore.profiles[0].username
        first = {username: baseName, displayName: "Phone Home", isDefault: true, role: "user"}
        first.append(pin)
        second = {username: private.username, displayName: "Phone Other", isDefault: false, role: "user", credential: {apiKey: private["apiKey"]}}
        payload = {playlist: {id: "PHONE-IMPORT", type: "dispatcharr", name: "Phone Import", url: m.baseUrl, credential: {apiKey: m.apiKey}, vodEnabled: false, guideDays: 3}, profiles: [second, first], sync: {provider: "dispatcharr", enabled: true}}
        m.phoneImportAddMode = private.addOnboarding = true
        if m.phoneImportAddMode then payload.profiles = [first]
        checked = validatePhoneSetupPayload(payload)
        if m.phoneImportValidationLogged <> true
            m.phoneImportValidationLogged = true
            print "[picker-launch] "; FormatJson({kind: "phone-import-payload-shape", accepted: checked.ok, guideType: type(payload.playlist.guideDays), guideAccepted: phoneSetupTypeMatches(payload.playlist.guideDays, "int"), defaultProfile: phoneSetupProfile(first) <> invalid, otherProfile: phoneSetupProfile(second) <> invalid, syncType: type(payload.sync)})
        end if
        if not checked.ok then return
        payload = checked.payload
        m.phoneImportSourceConnections = m.registry.read("connectionsV1")
        m.phoneImportSourceProfiles = m.registry.read(userProfileStoreKey(m.selectedConnectionId))
        m.phoneImportSourceKey = m.registry.read(connectionRegistryKey(m.selectedConnectionId))
        m.phoneImportBaseKey = m.apiKey
        m.phoneImportSecondKey = private["apiKey"]
        m.phoneImportSecondUsername = private.username
        m.phoneOriginPage = "setup"
        m.page = "phoneSetup"
        m.phoneSetup.active = true
        m.phoneSetup.visible = true
        acceptPhoneSetupPayload(payload)
        m.pickerProbeBaselineStage = 1
    else if stage = 1
        if m.phoneDialog = invalid or m.phoneResult = invalid then return
        ' Same server/base user is an existing duplicate; explicitly choose a
        ' separate playlist rather than changing the outgoing slot.
        onPhoneSetupChoice(baselineProbeEvent(m.phoneDialog, 1))
        m.pickerProbeBaselineStage = 2
    else if stage = 2
        if m.phoneImportAddMode and m.profilePinDialog <> invalid
            m.pickerProbeBaselineStage = 3
            return
        end if
        if m.profilePicker = invalid then return
        m.profilePicker.intent = {action: userProfilePickerChoice(m.profilePicker.model, 0), index: 0}
        m.pickerProbeBaselineStage = 3
    else if stage = 3
        if m.profilePinDialog = invalid then return
        m.phoneImportCovered = m.global.profilegateclosed and m.activeUserScope = invalid
        m.profilePinDialog.textEditBox.text = "1234"
        onProfilePinSubmit(baselineProbeEvent(m.profilePinDialog, 0))
        m.pickerProbeBaselineStage = 4
    else if stage = 4
        if m.busy or m.page <> "guide" or m.activeUserScope = invalid then return
        if m.phoneImportOnboardingLogged <> true
            m.phoneImportOnboardingLogged = true
            phase = ""
            if m.phoneProfileOnboarding <> invalid then phase = textValue(m.phoneProfileOnboarding.phase)
            choice = phoneSetupSyncOfferChoice(m.registry)
            print "[picker-launch] "; FormatJson({kind: "phone-onboarding-state", context: m.phoneProfileOnboarding <> invalid, dialog: m.phoneProfileOnboardingDialog <> invalid, phase: phase, role: currentUserSettingsRole(), enabled: choice.enabled, declined: choice.declined})
        end if
        if m.phoneImportOnboardingStarted <> true
            if m.phoneProfileOnboardingDialog = invalid or m.phoneProfileOnboarding = invalid then return
            if m.phoneProfileOnboarding.phase <> "offer" then return
            onPhoneProfileOnboardingChoice(baselineProbeEvent(m.phoneProfileOnboardingDialog, 1))
            if m.phoneProfileOnboardingDialog = invalid then return
            choices = m.phoneProfileOnboardingChoices
            if choices[choices.count() - 1].action <> "continue" then return
            if choices[choices.count() - 2].action <> "add" then return
            onPhoneProfileOnboardingChoice(baselineProbeEvent(m.phoneProfileOnboardingDialog, choices.count() - 2))
            if m.adultPinDialog = invalid or m.phoneProfileOnboardingDialog <> invalid then return
            m.adultPinDialog.textEditBox.text = "1234"
            onAdultProfilePinSubmit(baselineProbeEvent(m.adultPinDialog, 0))
            if m.profileOwnSignInContext = invalid then return
            if m.profileOwnSignInContext.returnToPhoneOnboarding <> true then return
            m.phoneImportOnboardingStarted = true
            if m.phoneImportAddMode
                private = ParseJson(ReadAsciiFile("pkg:/fixtures/phone-profile-verify.json"))
                m.profileOwnSignInContext.username = private.username
                m.profileOwnSignInContext.password = private.password
                submitUserProfileOwnSignIn()
                m.pickerProbeBaselineStage = 6
                return
            end if
            cancelUserProfileOwnSignIn()
            if m.phoneProfileOnboardingDialog = invalid or m.phoneProfileOnboarding.phase <> "who" then return
            m.phoneImportAddReturn = true
        end if
        if m.phoneImportOnboardingValid <> true
            choices = m.phoneProfileOnboardingChoices
            onPhoneProfileOnboardingChoice(baselineProbeEvent(m.phoneProfileOnboardingDialog, choices.count() - 1))
            choice = phoneSetupSyncOfferChoice(m.registry)
            m.phoneImportOnboardingValid = choice.ok and choice.declined and not choice.enabled and m.phoneProfileOnboarding = invalid
            if not m.phoneImportOnboardingValid then return
        end if
        store = loadUserProfileStore(m.registry, "phone-import")
        valid = not store.readOnly = true and store.profiles.count() = 2 and m.selectedConnectionId = "phone-import"
        if m.phoneImportAddMode then valid = not store.readOnly = true and store.profiles.count() = 1 and m.selectedConnectionId = "phone-import"
        own = false
        for each profile in store.profiles
            if lcase(profile.username) = lcase(m.phoneImportSecondUsername) then own = m.registry.read(userProfileKeyName("phone-import", profile.id)) = m.phoneImportSecondKey
        end for
        if m.phoneImportAddMode then own = m.phoneImportAddUndo = true
        unchanged = m.registry.read(userProfileStoreKey("slot-a")) = m.phoneImportSourceProfiles and m.registry.read(connectionRegistryKey("slot-a")) = m.phoneImportSourceKey
        valid = valid and own and unchanged and m.phoneImportCovered and m.apiKey = m.phoneImportBaseKey and not m.registry.exists(userProfileImportKey("phone-import"))
        options = m.accountPreferences.vodEnabled = false and m.accountPreferences.guide.futureDays = 3 and m.phoneOptions = invalid and m.phoneCommittedId = ""
        m.phoneImportCorePassed = valid and m.phoneImportOnboardingValid and options
        m.phoneImportCoreOwn = own
        m.phoneImportCoreUnchanged = unchanged
        if not persistCurrentUserProfilePreferences() then return
        m.phoneImportRecoveredRoot = m.registry.read(userProfileStoreKey("phone-import"))
        interrupted = copyJson(connectionStoreEntry(m.connectionStore, "phone-import"))
        interrupted.id = "phone-interrupted"
        interrupted.name = "Incomplete Import"
        staged = copyJson(m.connectionStore)
        staged.entries.push(interrupted)
        staged.selected = interrupted.id
        fenced = phoneSetupCommitFencedConnection(m.registry, m.connectionStore, staged, m.apiKey, CreateObject("roDeviceInfo").getRandomUUID())
        if not fenced.ok then return
        resetConnectionRuntime()
        m.connectionStore = fenced.store
        m.selectedConnectionId = interrupted.id
        applySelectedConnection()
        if not showIncompletePhoneImportRecovery() then return
        m.pickerProbeBaselineStage = 5
    else if stage = 6
        if m.profileOwnSignInContext <> invalid or m.phoneProfileOnboardingDialog = invalid then return
        if m.phoneProfileOnboarding.phase <> "who" or m.phoneProfileOnboarding.addedIds.count() <> 1 then return
        addedId = m.phoneProfileOnboarding.addedIds[0]
        store = loadUserProfileStore(m.registry, "phone-import")
        if store.profiles.count() <> 2 or m.registry.read(userProfileKeyName("phone-import", addedId)) <> m.phoneImportSecondKey then return
        undoIndex = -1
        for i = 0 to m.phoneProfileOnboardingChoices.count() - 1
            if m.phoneProfileOnboardingChoices[i].action = "undo" then undoIndex = i
        end for
        if undoIndex < 0 then return
        onPhoneProfileOnboardingChoice(baselineProbeEvent(m.phoneProfileOnboardingDialog, undoIndex))
        store = loadUserProfileStore(m.registry, "phone-import")
        if store.profiles.count() <> 1 or m.registry.read(userProfileKeyName("phone-import", addedId)) <> "" then return
        if store.removed.count() <> 1 or not store.pendingRoster then return
        m.phoneImportAddUndo = true
        m.phoneImportAddReturn = true
        m.pickerProbeBaselineStage = 4
    else if stage = 5
        if m.phoneImportRecoveryDialog = invalid then return
        onIncompletePhoneImportRecovery(baselineProbeEvent(m.phoneImportRecoveryDialog, 0))
        removed = connectionStoreEntry(loadConnectionStore(m.registry), "phone-interrupted") = invalid and m.registry.read(connectionRegistryKey("phone-interrupted")) = ""
        rootKept = m.registry.read(userProfileStoreKey("phone-import")) = m.phoneImportRecoveredRoot and not m.registry.exists(userProfileImportKey("phone-interrupted"))
        noActor = m.activeUserScope = invalid and m.profileUnlockGrant = invalid and m.guide.active <> true
        selected = m.selectedConnectionId = "phone-import"
        choice = phoneSetupSyncOfferChoice(m.registry)
        declineKept = choice.ok and choice.declined and not choice.enabled
        recovered = removed and rootKept and noActor and selected and declineKept
        m.pickerProbeClock.control = "stop"
        print "[picker-launch] "; FormatJson({kind: "result", baseline: true, phoneImport: true, passed: m.phoneImportCorePassed and recovered and m.phoneImportAddReturn = true, addReturn: m.phoneImportAddReturn, ownKeys: m.phoneImportCoreOwn, protectedAdmission: m.phoneImportCovered, sourceUnchanged: m.phoneImportCoreUnchanged, recoveryUi: recovered, onboarding: m.phoneImportOnboardingValid, removed: removed, rootKept: rootKept, noActor: noActor, selectedRestored: selected, recoveryFailure: m.phoneImportRecoveryFailure})
    end if
end sub
