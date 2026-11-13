' Activation is staged behind own verified identity and a successful atomic
' settings write. Public switching/callback retirement is separate controller
' work; this boundary also preserves the existing single-default upgrade.
function prepareUserProfileConnectionSettings(connection as object, result as object, sessionId = "" as string) as boolean
    m.activeUserScope = invalid
    m.scopedPreferencesRequired = true
    if m.global <> invalid then m.global.activeusersession = ""
    profile = invalid
    if type(m.userProfileStore) <> "roAssociativeArray" then return false
    for each candidate in m.userProfileStore.profiles
        if candidate.id = m.userProfileStore.active then profile = candidate
    end for
    if profile = invalid then return false
    account = userProfileUserId(result.accountId)
    if account = invalid then return false
    if profile.userId <> account then return false
    if sessionId = "" then sessionId = CreateObject("roDeviceInfo").getRandomUUID()
    scope = userProfileSessionScope(connection, profile.id, result.accountId, textValue(result.generation), sessionId)
    if scope = invalid then return false
    if scope.preferenceIdentity <> m.accountIdentity then return false
    prepared = userProfilePrepareSettings(m.accountPreferences, m.preferenceStore.device)
    if not prepared.ok then return false
    saved = commitUserProfilePreferences(m.registry, m.preferenceStore, prepared.preferences, prepared.device, scope, scope)
    if not saved.ok
        m.userProfileRecoveryRequired = saved.recoveryRequired
        return false
    end if
    m.preferenceStore = saved.store
    m.accountPreferences = saved.preferences
    m.devicePreferences = prepared.device
    m.activeUserScope = scope
    if m.global <> invalid then m.global.activeusersession = scope.sessionId
    applyDevicePreferences()
    return true
end function

function persistCurrentUserProfilePreferences(captured = invalid as dynamic) as boolean
    if m.activeUserScope = invalid or m.userProfileRecoveryRequired = true then return false
    if captured = invalid then captured = m.activeUserScope
    if m.activeUserScope.preferenceIdentity <> m.accountIdentity then return false
    saved = commitUserProfilePreferences(m.registry, m.preferenceStore, m.accountPreferences, m.devicePreferences, captured, m.activeUserScope)
    if not saved.ok
        m.userProfileRecoveryRequired = saved.recoveryRequired
        return false
    end if
    m.preferenceStore = saved.store
    m.accountPreferences = saved.preferences
    prepared = userProfilePrepareSettings(saved.preferences, saved.store.device)
    m.devicePreferences = prepared.device
    return true
end function
