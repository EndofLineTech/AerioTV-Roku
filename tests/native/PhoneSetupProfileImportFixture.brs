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
        if m.busy or m.page <> "guide" then return
        private = ParseJson(ReadAsciiFile("pkg:/fixtures/phone-profile-verify.json"))
        pin = {pinType: "numbers", pinSalt: "00112233445566778899aabbccddeeff", pinHash: userProfilePinHash("00112233445566778899aabbccddeeff", "1234")}
        baseName = m.userProfileStore.profiles[0].username
        first = {username: baseName, displayName: "Phone Home", isDefault: true, role: "user"}
        first.append(pin)
        second = {username: private.username, displayName: "Phone Other", isDefault: false, role: "user", credential: {apiKey: private["apiKey"]}}
        payload = {playlist: {id: "PHONE-IMPORT", type: "dispatcharr", name: "Phone Import", url: m.baseUrl, credential: {apiKey: m.apiKey}}, profiles: [second, first]}
        checked = validatePhoneSetupPayload(payload)
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
        m.profilePhoneImportReady = true
        acceptPhoneSetupPayload(payload)
        m.pickerProbeBaselineStage = 1
    else if stage = 1
        if m.phoneDialog = invalid or m.phoneResult = invalid then return
        ' Same server/base user is an existing duplicate; explicitly choose a
        ' separate playlist rather than changing the outgoing slot.
        onPhoneSetupChoice(baselineProbeEvent(m.phoneDialog, 1))
        m.pickerProbeBaselineStage = 2
    else if stage = 2
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
        store = loadUserProfileStore(m.registry, "phone-import")
        valid = not store.readOnly = true and store.profiles.count() = 2 and m.selectedConnectionId = "phone-import"
        own = false
        for each profile in store.profiles
            if lcase(profile.username) = lcase(m.phoneImportSecondUsername) then own = m.registry.read(userProfileKeyName("phone-import", profile.id)) = m.phoneImportSecondKey
        end for
        unchanged = m.registry.read(userProfileStoreKey("slot-a")) = m.phoneImportSourceProfiles and m.registry.read(connectionRegistryKey("slot-a")) = m.phoneImportSourceKey
        valid = valid and own and unchanged and m.phoneImportCovered and m.apiKey = m.phoneImportBaseKey and not m.registry.exists(userProfileImportKey("phone-import"))
        m.phoneImportCorePassed = valid
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
    else if stage = 5
        if m.phoneImportRecoveryDialog = invalid then return
        onIncompletePhoneImportRecovery(baselineProbeEvent(m.phoneImportRecoveryDialog, 0))
        removed = connectionStoreEntry(loadConnectionStore(m.registry), "phone-interrupted") = invalid and m.registry.read(connectionRegistryKey("phone-interrupted")) = ""
        rootKept = m.registry.read(userProfileStoreKey("phone-import")) = m.phoneImportRecoveredRoot and not m.registry.exists(userProfileImportKey("phone-interrupted"))
        noActor = m.activeUserScope = invalid and m.profileUnlockGrant = invalid and m.guide.active <> true
        selected = m.selectedConnectionId = "phone-import"
        recovered = removed and rootKept and noActor and selected
        m.pickerProbeClock.control = "stop"
        print "[picker-launch] "; FormatJson({kind: "result", baseline: true, phoneImport: true, passed: m.phoneImportCorePassed and recovered, ownKeys: m.phoneImportCoreOwn, protectedAdmission: m.phoneImportCovered, sourceUnchanged: m.phoneImportCoreUnchanged, recoveryUi: recovered, removed: removed, rootKept: rootKept, noActor: noActor, selectedRestored: selected, recoveryFailure: m.phoneImportRecoveryFailure})
    end if
end sub
