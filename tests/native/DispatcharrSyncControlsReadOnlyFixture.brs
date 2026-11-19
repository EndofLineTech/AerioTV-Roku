' Private live read qualification, with a disposable roster/settings section.
' The host builder forbids mutating HTTP before any broker/transport is called.
sub seedSyncControlsReadOnly()
    cfg = ParseJson(ReadAsciiFile("pkg:/sync-controls-private.json"), "d")
    entry = normalizeConnectionEntry({id: "sync-test", name: "Sync qualification", url: cfg.baseUrl, provider: "dispatcharr", accountId: cfg.primary.id.toStr(), accountUsername: cfg.primary.username, remember: true, authMode: "api-key"})
    primary = userProfileFromVerified(entry.id, "00000000-0000-4000-8000-000000000701", cfg.primary, 0)
    held = userProfileFromVerified(entry.id, "00000000-0000-4000-8000-000000000702", cfg.sibling, 0)
    held = setCanonicalPreference(held, "isDefault", false)
    held = setCanonicalPreference(held, "addressHeld", true)
    store = defaultUserProfileStore(entry.id)
    store = setCanonicalPreference(store, "active", primary.id)
    store = setCanonicalPreference(store, "profiles", [primary, held])
    store = setCanonicalPreference(store, "askAtLaunch", false)
    store = setCanonicalPreference(store, "pendingRoster", true)
    m.registry.write("connectionsV1", FormatJson({schema: 1, selected: entry.id, entries: [entry]}))
    m.registry.write(connectionRegistryKey(entry.id), cfg.key)
    m.registry.write(userProfileStoreKey(entry.id), FormatJson(store))
    m.registry.flush()
    cfg.key = ""
    m.syncControlsProbeStage = 0
    m.syncControlsProbeClock = m.top.createChild("Timer")
    m.syncControlsProbeClock.duration = 0.5
    m.syncControlsProbeClock.repeat = true
    m.syncControlsProbeClock.observeField("fire", "tickSyncControlsReadOnly")
    m.syncControlsProbeClock.control = "start"
end sub

sub syncControlsProbeSignal(phase as string, valid as boolean)
    print "[sync-controls-readonly] "; FormatJson({phase: phase, valid: valid})
end sub

sub tickSyncControlsReadOnly()
    if m.syncControlsProbeLastPage <> m.page or m.syncControlsProbeLastBusy <> m.busy
        m.syncControlsProbeLastPage = m.page
        m.syncControlsProbeLastBusy = m.busy
        print "[sync-controls-readonly] "; FormatJson({phase: "diagnostic", page: m.page, busy: m.busy, own: m.activeUserScope <> invalid})
    end if
    if m.page <> "guide" and m.page <> "setup" then return
    if m.activeUserScope = invalid or m.busy then return
    stage = m.syncControlsProbeStage
    settings = loadDispatcharrSyncSettings(m.registry)
    if stage = 0
        if m.syncControlsProbeManagerOpened <> true
            showConnection()
            openConnectionManager()
            m.syncControlsProbeManagerOpened = true
            return
        end if
        if m.connectionDialog = invalid then syncControlsProbeSignal("result", false) : return
        found = false
        for i = 0 to m.connectionChoices.count() - 1
            if m.connectionChoices[i].action = "syncControls"
                m.syncControlsProbeStage = 1
                onConnectionChoice({node: m.connectionDialog, index: i, getRoSGNode: function() as object
                    return m.node
                end function, getData: function() as integer
                    return m.index
                end function})
                syncControlsProbeSignal("manager", m.profileSyncSettingsContext <> invalid)
                found = true
                exit for
            end if
        end for
        if not found then syncControlsProbeSignal("result", false)
    else if stage = 1
        if m.profileSyncSettingsContext = invalid then return
        m.syncControlsProbeStage = 2
        syncControlsProbeSignal("off", not settings.enabled and m.connectionDialog.buttonFocused = 0 and m.connectionDialog.isInFocusChain() and left(m.connectionDialog.message, 3) = "Off")
    else if stage = 2
        if not settings.enabled or m.profileSyncSettingsContext = invalid then return
        m.syncControlsProbeStage = 3
        syncControlsProbeSignal("held", m.connectionDialog.buttonFocused = 0 and m.connectionDialog.isInFocusChain() and instr(1, m.connectionDialog.message, "saved addresses are held") > 0)
    else if stage = 3
        if settings.profiles or m.profileSyncSettingsContext = invalid then return
        m.syncControlsProbeStage = 4
        syncControlsProbeSignal("profiles-off", m.connectionDialog.buttonFocused = 0 and m.connectionDialog.isInFocusChain() and instr(1, m.connectionDialog.message, "Profiles Off") > 0)
    else if stage = 4
        if not settings.profiles or m.profileSyncSettingsContext = invalid then return
        m.syncControlsProbeStage = 5
        syncControlsProbeSignal("back", m.connectionDialog.buttonFocused = 0 and m.connectionDialog.isInFocusChain())
    else if stage = 5
        if m.connectionDialog <> invalid or m.profileSyncAddressPauseScope = invalid then return
        store = loadUserProfileStore(m.registry, "sync-test")
        if not store.pendingRoster or m.profileScheduledSyncTask <> invalid then syncControlsProbeSignal("result", false) : return
        nextStore = copyPreferenceValue(store)
        nextStore.profiles[1] = setCanonicalPreference(nextStore.profiles[1], "addressHeld", false)
        saved = commitUserProfileStore(m.registry, store, nextStore, {}, true)
        if not saved.ok then syncControlsProbeSignal("result", false) : return
        m.syncControlsProbeStage = 6
        syncControlsProbeSignal("release", true)
    else if stage = 6
        if m.syncControlsProbeRead <> true then return
        m.profileSyncClock.control = "stop"
        openDispatcharrSyncControls()
        if m.profileSyncSettingsContext = invalid then syncControlsProbeSignal("result", false) : return
        m.syncControlsProbeStage = 7
        syncControlsProbeSignal("pending", m.connectionDialog.buttonFocused = 0 and m.connectionDialog.isInFocusChain() and instr(1, m.connectionDialog.message, "Changes pending") > 0)
    else if stage = 7
        if settings.enabled then return
        store = loadUserProfileStore(m.registry, "sync-test")
        m.syncControlsProbeClock.control = "stop"
        syncControlsProbeSignal("result", store.pendingRoster and not m.registry.exists(userProfileSyncAckKey("sync-test")) and m.profileSyncClock.control = "stop")
    end if
end sub

sub recordSyncControlsReadOnly(result as object, saved as object, context as object)
    if m.syncControlsProbeStage <> 6 or context.ticket.push <> false then syncControlsProbeSignal("result", false) : return
    if result.state <> "local-commit" or not saved.ok then syncControlsProbeSignal("result", false) : return
    m.profileSyncClock.control = "stop"
    m.syncControlsProbeRead = true
end sub
