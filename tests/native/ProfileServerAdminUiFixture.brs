sub onProfileServerAdminUiProbeTick()
    if m.busy or m.page = "setup" then return
    stage = m.pickerProbeBaselineStage
    if stage = invalid then stage = 0
    if m.pickerProbeAdminLoggedStage <> stage
        m.pickerProbeAdminLoggedStage = stage
        print "[picker-launch] "; FormatJson({kind: "admin-ui-state", stage: stage, page: m.page})
    end if
    if stage = 0
        m.pickerProbeAdminOriginalScope = m.activeUserScope
        m.pickerProbeAdminOriginalKey = m.apiKey
        store = loadUserProfileStore(m.registry, "slot-a")
        candidate = copyJson(store)
        candidate.profiles[0] = setCanonicalPreference(candidate.profiles[0], "userLevel", 10)
        candidate.profiles[0] = setCanonicalPreference(candidate.profiles[0], "role", "admin")
        if not commitUserProfileStore(m.registry, store, candidate, {}, true).ok then return
        m.userProfileStore = candidate
        openSettingsHub()
        beginProfileBaselineAdd()
        m.pickerProbeBaselineStage = 1
    else if stage = 1
        if m.profileOwnSignInDialog = invalid then return
        if m.profileOwnSignInDialog.buttons.count() <> 5 then return
        onProfileOwnSignInChoice(baselineProbeEvent(m.profileOwnSignInDialog, 4))
        m.pickerProbeBaselineStage = 2
    else if stage = 2
        if m.profileServerAdminTask <> invalid or m.profileServerAdminDialog = invalid then return
        if m.profileServerAdminChoices[0].action <> "user" then return
        onProfileServerAdminChoice(baselineProbeEvent(m.profileServerAdminDialog, 0))
        m.pickerProbeBaselineStage = 3
    else if stage = 3
        if m.profileServerAdminChoices[0].action <> "generate" then return
        onProfileServerAdminChoice(baselineProbeEvent(m.profileServerAdminDialog, 0))
        m.pickerProbeBaselineStage = 4
    else if stage = 4
        if m.profileServerAdminTask <> invalid or m.profileServerAdminDialog = invalid then return
        if m.profileServerAdminContext.target.api_key <> "synthetic-minted-key" then return
        if m.profileServerAdminChoices[1].action <> "revoke-confirm" then return
        onProfileServerAdminChoice(baselineProbeEvent(m.profileServerAdminDialog, 1))
        m.pickerProbeBaselineStage = 5
    else if stage = 5
        if m.profileServerAdminChoices[0].action <> "revoke" then return
        onProfileServerAdminChoice(baselineProbeEvent(m.profileServerAdminDialog, 0))
        m.pickerProbeBaselineStage = 6
    else if stage = 6
        if m.profileServerAdminTask <> invalid or m.profileServerAdminDialog = invalid then return
        if m.profileServerAdminContext.target.api_key <> "" then return
        m.pickerProbeAdminApiValid = not m.profileServerAdminContext.minted.doesExist("9001") and m.profileServerAdminChoices[0].action = "generate"
        finishProfileServerAdminUi("")
        cancelUserProfileOwnSignIn()
        openUserProfileManagement()
        onProfileManagementChoice(baselineProbeEvent(m.profileManagementDialog, 0))
        channelIndex = -1
        for i = 0 to m.profileManagementChoices.count() - 1
            if m.profileManagementChoices[i].action = "server-channels" then channelIndex = i
        end for
        if channelIndex < 0 then return
        onProfileManagementChoice(baselineProbeEvent(m.profileManagementDialog, channelIndex))
        m.pickerProbeBaselineStage = 7
    else if stage = 7
        if m.pickerProbeAdminChoiceLogged <> true and m.profileServerAdminTask = invalid
            m.pickerProbeAdminChoiceLogged = true
            actions = []
            for each choice in m.profileServerAdminChoices
                actions.push(choice.action)
            end for
            print "[picker-launch] "; FormatJson({kind: "admin-ui-choices", actions: actions, dialog: m.profileServerAdminDialog <> invalid})
        end if
        if m.profileServerAdminTask <> invalid or m.profileServerAdminDialog = invalid then return
        if m.profileServerAdminChoices[1].action <> "channel" then return
        onProfileServerAdminChoice(baselineProbeEvent(m.profileServerAdminDialog, 1))
        onProfileServerAdminChoice(baselineProbeEvent(m.profileServerAdminDialog, 3))
        m.pickerProbeBaselineStage = 8
    else if stage = 8
        if m.profileServerAdminContext <> invalid or m.profileServerAdminTask <> invalid then return
        if m.activeUserScope = invalid or m.page <> "guide" then return
        if userProfileSameSession(m.activeUserScope, m.pickerProbeAdminOriginalScope) then return
        m.pickerProbeClock.control = "stop"
        valid = m.pickerProbeAdminApiValid and m.apiKey = m.pickerProbeAdminOriginalKey and currentUserSettingsRole() = "user"
        valid = valid and m.activeUserScope.profileId = m.pickerProbeAdminOriginalScope.profileId and m.profileOwnSignInContext = invalid
        print "[picker-launch] "; FormatJson({kind: "result", baseline: true, adminUi: true, syntheticAdminOnly: true, passed: valid, apiAccess: m.pickerProbeAdminApiValid, ownReload: m.activeUserScope.profileId = m.pickerProbeAdminOriginalScope.profileId})
    end if
end sub
