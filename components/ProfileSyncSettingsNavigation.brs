' Private selected-connection controls. Choices are DEVICE-wide, but every UI
' operation requires the actual currently adopted full-access holder and roots.
function captureDispatcharrSyncSettings() as dynamic
    if m.profileSyncControlsReady <> true or m.userProfileRecoveryRequired = true or m.busy = true then return invalid
    if userProfileGateClosed() or m.activeUserScope = invalid or textValue(m.apiKey) = "" then return invalid
    if textValue(m.global.activeusersession) <> textValue(m.activeUserScope.sessionId) then return invalid
    if m.profileSwitchContext <> invalid or m.profileOwnSignInContext <> invalid then return invalid
    if m.profileScheduledSyncTask <> invalid or m.profileSyncWriteTask <> invalid then return invalid
    if m.profilePinDialog <> invalid or m.adultPinDialog <> invalid then return invalid
    connections = loadConnectionStore(m.registry)
    if connections.readOnly = true or connections.selected <> m.selectedConnectionId then return invalid
    entry = connectionStoreEntry(connections, m.selectedConnectionId)
    if entry = invalid then return invalid
    context = {connection: entry, scope: m.activeUserScope, connectionRoot: m.registry.read("connectionsV1"), storeRoot: m.registry.read(userProfileStoreKey(entry.id)), settingsRoot: m.registry.read("settingsV1"), settingsPresent: m.registry.exists("settingsV1"), credentialHash: requestGateCredentialHash(m.apiKey)}
    access = dispatcharrSyncSettingsAccess(m.registry, context, m.activeUserScope, m.apiKey, dispatcharrSyncSettingsMemory(context))
    if not access.ok then return invalid
    return context
end function

function dispatcharrSyncControlsAllowed() as boolean
    return captureDispatcharrSyncSettings() <> invalid
end function

function dispatcharrSyncSettingsMemory(context as object) as object
    memory = {}
    if context.connection.remember then return memory
    store = loadUserProfileStore(m.registry, context.connection.id)
    if store.readOnly = true then return memory
    for each profile in store.profiles
        if profile.id = store.active
            name = userProfileKeyName(context.connection.id, profile.id)
            if profile.isDefault then name = connectionRegistryKey(context.connection.id)
            memory[name] = m.apiKey
        end if
    end for
    return memory
end function

sub openDispatcharrSyncControls()
    if m.profileSyncControlsReady <> true then return
    context = captureDispatcharrSyncSettings()
    if context = invalid then return
    settings = loadDispatcharrSyncSettings(m.registry)
    if not settings.ok
        showNotice("Sync choices need recovery. Existing data was retained.")
        return
    end if
    enabledTitle = "Turn On Dispatcharr Sync"
    if settings.enabled then enabledTitle = "Turn Off Dispatcharr Sync"
    profilesTitle = "Turn Off Profiles"
    if not settings.profiles then profilesTitle = "Turn On Profiles"
    choices = [{title: enabledTitle, action: "syncEnabled", value: not settings.enabled}, {title: profilesTitle, action: "syncProfiles", value: not settings.profiles}, {title: "Back", action: "cancel"}]
    message = dispatcharrSyncStatusText(settings) + chr(10) + "These choices apply to this Roku, across all playlists and profiles. Sync starts after closing this menu; Off retains pending edits. Only Profiles is supported here. Other categories are preserved unchanged."
    openConnectionDialog("Dispatcharr Sync", message, choices)
    if m.connectionDialog <> invalid then m.profileSyncSettingsContext = context
end sub

function dispatcharrSyncStatusText(settings as object) as string
    if not settings.enabled then return "Off"
    if not settings.profiles then return "On — Profiles Off"
    if m.profileSyncLinkKnown = true and m.profileSyncLinkUp <> true then return "Waiting for network"
    if type(m.profileSyncSchedule) = "roAssociativeArray"
        if userProfileSameSession(m.profileSyncSchedule.scope, m.activeUserScope)
            if m.profileSyncSchedule.pause = "signin-required" then return "Sign in again to sync"
            if m.profileSyncSchedule.pause = "storage-full" then return "Sync storage on the server is full"
            if m.profileSyncSchedule.pause = "too-large" then return "Sync data too large"
        end if
    end if
    store = loadUserProfileStore(m.registry, m.selectedConnectionId)
    if store.readOnly <> true
        for each profile in store.profiles
            if profile.addressHeld then return "Profiles paused while saved addresses are held"
        end for
        if store.pendingRoster then return "Changes pending"
    end if
    return "On — Profiles"
end function

function toggleDispatcharrSyncControls(context as dynamic, field as string, value as dynamic) as boolean
    if m.profileSyncControlsReady <> true or context = invalid then return false
    if m.userProfileRecoveryRequired = true or m.busy = true then return false
    if m.profileScheduledSyncTask <> invalid or m.profileSyncWriteTask <> invalid then return false
    if m.profilePinDialog <> invalid or m.adultPinDialog <> invalid then return false
    if type(context) <> "roAssociativeArray" then return false
    if type(context.connection) <> "roAssociativeArray" then return false
    if context.connection.id <> m.selectedConnectionId then return false
    if userProfileGateClosed() or m.activeUserScope = invalid then return false
    if textValue(m.global.activeusersession) <> textValue(m.activeUserScope.sessionId) then return false
    if m.profileSwitchContext <> invalid or m.profileOwnSignInContext <> invalid then return false
    if field <> "enabled" and field <> "profiles" then return false
    if not userProfileBoolean(value) then return false
    settings = loadDispatcharrSyncSettings(m.registry)
    if not settings.ok then return false
    enabled = settings.enabled
    profiles = settings.profiles
    if field = "enabled" then enabled = value
    if field = "profiles" then profiles = value
    saved = commitDispatcharrSyncSettings(m.registry, context, m.activeUserScope, textValue(m.apiKey), dispatcharrSyncSettingsMemory(context), enabled, profiles)
    if not saved.ok
        if saved.recoveryRequired = true then coverScheduledProfileSync()
        showNotice("Could not safely save sync choices. Existing data was retained.")
        return false
    end if
    m.preferenceStore = saved.preferenceStore
    ' Profile changes flush this runtime cache too. Keep explicit device-wide
    ' consent/category choices current so an outgoing save cannot revert them.
    m.devicePreferences = setCanonicalPreference(m.devicePreferences, "dispatcharrSyncEnabled", enabled)
    m.devicePreferences = setCanonicalPreference(m.devicePreferences, "dispatcharrSyncProfiles", profiles)
    applyDispatcharrSyncChoices()
    ' A new opt-in/category lifecycle starts with fresh own me/list/key discovery.
    m.profileSyncSchedule = invalid
    openDispatcharrSyncControls()
    activateProfileSyncScheduling()
    return true
end function

sub applyDispatcharrSyncChoices()
    settings = loadDispatcharrSyncSettings(m.registry)
    m.profileSyncEnabled = settings.enabled = true
    m.profileRosterEnabled = settings.profiles = true
    m.profileSyncSettingsValid = settings.ok = true
    if not m.profileRosterEnabled
        m.profileRosterSuggestions = []
        m.profileRosterSuggestionScope = invalid
    end if
    if not m.profileSyncEnabled or not m.profileRosterEnabled
        closeScheduledProfileSync()
        if m.profileSyncClock <> invalid then m.profileSyncClock.control = "stop"
        m.profileSyncSchedule = invalid
    end if
end sub
