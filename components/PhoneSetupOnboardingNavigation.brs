' Post-admission continuation. No payload may consent to Sync, and a Child
' session never sees other profiles or Add/management controls here.
sub continuePhoneProfileOnboarding()
    context = m.phoneProfileOnboarding
    if type(context) <> "roAssociativeArray" then return
    if m.busy or m.activeUserScope = invalid or userProfileGateClosed() then return
    if m.selectedConnectionId <> context.slot or not userProfileFullAccess(currentUserSettingsRole())
        m.phoneProfileOnboarding = invalid
        return
    end if
    if context.scope <> invalid
        if not userProfileSameSession(context.scope, m.activeUserScope) then m.phoneProfileOnboarding = invalid : return
    end if
    context.scope = m.activeUserScope
    context.connectionRoot = m.registry.read("connectionsV1")
    context.storeRoot = m.registry.read(userProfileStoreKey(context.slot))
    context.settingsRoot = m.registry.read("settingsV1")
    if context.phase = "offer"
        choice = phoneSetupSyncOfferChoice(m.registry)
        if choice.ok
            if phoneSetupProfileSyncOffer(context.incomingSync, choice)
                showPhoneProfileOnboardingDialog("Dispatcharr Sync is on for this account", "Another device already syncs this account through Dispatcharr. Turn it on here too?", [{title: "Turn On", action: "enable"}, {title: "Not Now", action: "decline"}])
                return
            end if
        end if
        context.phase = "who"
    end if
    store = loadUserProfileStore(m.registry, context.slot)
    if store.readOnly = true then m.phoneProfileOnboarding = invalid : return
    choices = []
    for each profile in userProfileSorted(store.profiles)
        addedHere = false
        for each id in context.addedIds
            if id = profile.id then addedHere = true
        end for
        if addedHere and not profile.isDefault and profile.id <> store.active
            choices.push({title: profile.displayName + " — Remove", action: "undo", id: profile.id})
        else
            choices.push({title: profile.displayName + " — Added", action: "added"})
        end if
    end for
    if store.profiles.count() < 4 then choices.push({title: "Add Profile", action: "add"})
    choices.push({title: "Continue", action: "continue"})
    showPhoneProfileOnboardingDialog("Who watches on this TV?", "Profiles are chosen per device. Add the ones that belong here.", choices)
end sub

sub showPhoneProfileOnboardingDialog(title as string, message as string, choices as object)
    closePhoneProfileOnboardingDialog()
    dialog = CreateObject("roSGNode", "AerioDialog")
    dialog.title = title
    dialog.message = message
    buttons = []
    for each choice in choices
        buttons.push(choice.title)
    end for
    dialog.buttons = buttons
    dialog.observeField("buttonSelected", "onPhoneProfileOnboardingChoice")
    dialog.observeField("wasClosed", "onPhoneProfileOnboardingClosed")
    m.phoneProfileOnboardingChoices = choices
    m.phoneProfileOnboardingDialog = dialog
    m.top.dialog = dialog
    dialog.setFocus(true)
end sub

function phoneProfileOnboardingCurrent(event as object) as boolean
    dialog = m.phoneProfileOnboardingDialog
    context = m.phoneProfileOnboarding
    if dialog = invalid or type(context) <> "roAssociativeArray" then return false
    if not dialog.isSameNode(event.getRoSGNode()) then return false
    if m.activeUserScope = invalid or userProfileGateClosed() or m.busy then return false
    if not userProfileSameSession(context.scope, m.activeUserScope) then return false
    if m.selectedConnectionId <> context.slot or not userProfileFullAccess(currentUserSettingsRole()) then return false
    return context.connectionRoot = m.registry.read("connectionsV1") and context.storeRoot = m.registry.read(userProfileStoreKey(context.slot))
end function

sub onPhoneProfileOnboardingChoice(event as object)
    if not phoneProfileOnboardingCurrent(event) then return
    index = event.getData()
    if not userProfileInteger(index) then return
    if index < 0 or index >= m.phoneProfileOnboardingChoices.count() then return
    action = m.phoneProfileOnboardingChoices[index].action
    selected = m.phoneProfileOnboardingChoices[index]
    context = m.phoneProfileOnboarding
    closePhoneProfileOnboardingDialog()
    if action = "decline"
        saved = phoneSetupDeclineSyncOffer(m.registry, m.registry.read("settingsV1"))
        if saved.ok
            m.preferenceStore = saved.store
            m.devicePreferences = setCanonicalPreference(m.devicePreferences, "dispatcharrSyncOfferDeclined", true)
        end if
        if not saved.ok then showNotice("Could not save that choice. Sync remains unchanged.")
        context.phase = "who"
    else if action = "enable"
        admission = captureDispatcharrSyncSettings()
        settings = loadDispatcharrSyncSettings(m.registry)
        if admission <> invalid and settings.ok
            saved = commitDispatcharrSyncSettings(m.registry, admission, m.activeUserScope, textValue(m.apiKey), dispatcharrSyncSettingsMemory(admission), true, settings.profiles)
            if saved.ok
                m.preferenceStore = saved.preferenceStore
                m.devicePreferences = setCanonicalPreference(m.devicePreferences, "dispatcharrSyncEnabled", true)
                m.devicePreferences = setCanonicalPreference(m.devicePreferences, "dispatcharrSyncProfiles", settings.profiles)
                applyDispatcharrSyncChoices()
                m.profileSyncSchedule = invalid
                activateProfileSyncScheduling()
            else
                showNotice("Could not safely enable Sync. Existing choices were retained.")
            end if
        else
            showNotice("Sync is not available in this build. It remains unchanged.")
        end if
        context.phase = "who"
    else if action = "add"
        beginProfileBaselineAdd(false, false, true)
        if m.profileOwnSignInContext <> invalid or m.adultPinDialog <> invalid then return
    else if action = "undo"
        tracked = false
        for each id in context.addedIds
            if id = selected.id then tracked = true
        end for
        if tracked
            entry = connectionStoreEntry(loadConnectionStore(m.registry), context.slot)
            store = loadUserProfileStore(m.registry, context.slot)
            saved = removeUserProfile(m.registry, entry, store, selected.id, CreateObject("roDateTime").asSeconds(), "undo")
            if saved.ok
                m.userProfileStore = saved.store
                if type(saved.preferences) = "roAssociativeArray" then m.preferenceStore = saved.preferences
                if type(m.profileSessionKeys) = "roAssociativeArray" then m.profileSessionKeys.delete(preferenceScope(entry.url + "|" + entry.id + "|" + selected.id))
                kept = []
                for each id in context.addedIds
                    if id <> selected.id then kept.push(id)
                end for
                context.addedIds = kept
                refreshUserProfileChrome()
            else if saved.recoveryRequired = true
                coverProfileManagementRecovery("Saved profiles need recovery.")
                m.phoneProfileOnboarding = invalid
                return
            else
                showNotice("Could not remove this added profile. Existing data was retained.")
            end if
        end if
    else if action = "continue"
        m.phoneProfileOnboarding = invalid
        return
    end if
    continuePhoneProfileOnboarding()
end sub

sub retirePhoneProfileOnboarding()
    closePhoneProfileOnboardingDialog()
    m.phoneProfileOnboarding = invalid
end sub

sub onPhoneProfileOnboardingClosed(event as object)
    if not phoneProfileOnboardingCurrent(event) then return
    context = m.phoneProfileOnboarding
    closePhoneProfileOnboardingDialog()
    if context.phase = "offer"
        context.phase = "who"
        continuePhoneProfileOnboarding()
    else
        m.phoneProfileOnboarding = invalid
    end if
end sub

sub closePhoneProfileOnboardingDialog()
    dialog = m.phoneProfileOnboardingDialog
    m.phoneProfileOnboardingDialog = invalid
    if dialog = invalid then return
    dialog.unobserveField("buttonSelected")
    dialog.unobserveField("wasClosed")
    dialog.close = true
    if m.top.dialog <> invalid
        if m.top.dialog.isSameNode(dialog) then m.top.dialog = invalid
    end if
end sub
