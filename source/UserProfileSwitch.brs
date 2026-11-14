' Incoming identity/lineup staging is separate from runtime adoption. The
' controller must still flush outgoing work, retire callbacks and atomically
' persist this plan with target settings before changing the active runtime.
function userProfileSwitchAcceptPinStore(previous as object, current as object, targetId as string, grant as dynamic) as boolean
    before = normalizeUserProfileStore(previous, previous.playlistId)
    live = normalizeUserProfileStore(current, previous.playlistId)
    if before.readOnly = true or live.readOnly = true then return false
    target = invalid
    for each profile in live.profiles
        if profile.id = targetId then target = profile
    end for
    if target = invalid then return false
    if not userProfilePinGrantMatches(grant, previous.playlistId, target) then return false
    expected = copyJson(before)
    for i = 0 to expected.profiles.count() - 1
        if expected.profiles[i].id = targetId then expected.profiles[i] = setCanonicalPreference(expected.profiles[i], "pinLength", target.pinLength)
    end for
    return FormatJson(expected) = FormatJson(live)
end function

function userProfileSwitchPlan(connection as object, previous as object, targetId as string, verified as dynamic, targetPinGrant as dynamic, deviceAdmin as dynamic, managementGrant as dynamic, capturedNonce as string, activeNonce as string, managementNonce = "" as string) as object
    denied = {ok: false, reason: "stale-context"}
    if userProfileLocalId(capturedNonce) = "" or capturedNonce <> activeNonce then return denied
    if connection.provider <> "dispatcharr" or connection.id <> previous.playlistId or previous.readOnly = true then return denied
    cleaned = normalizeUserProfileStore(previous, connection.id)
    if cleaned.readOnly = true then return denied
    incoming = invalid
    outgoing = invalid
    index = -1
    for i = 0 to cleaned.profiles.count() - 1
        profile = cleaned.profiles[i]
        if profile.id = cleaned.active then outgoing = profile
        if profile.id = targetId
            incoming = profile
            index = i
        end if
    end for
    if incoming = invalid or outgoing = invalid or incoming.id = outgoing.id then return denied
    if incoming.addressHeld then return {ok: false, reason: "address-held"}
    if outgoing.role = "child"
        if not userProfileManagementGrantMatches(cleaned, deviceAdmin, managementGrant, managementNonce) then return {ok: false, reason: "adult-pin-required"}
    end if
    if incoming.pinType <> "none"
        if not userProfilePinGrantMatches(targetPinGrant, connection.id, incoming) then return {ok: false, reason: "target-pin-required"}
    end if
    if type(verified) <> "roAssociativeArray" then return denied
    if verified.ok <> true then return {ok: false, reason: "authentication-failed"}
    if type(verified.apiKey) <> "String" and type(verified.apiKey) <> "roString" then return denied
    if verified.apiKey = "" or len(verified.apiKey) > 512 then return denied
    if type(verified.verifiedUser) <> "roAssociativeArray" then return denied
    identity = userProfileFromVerified(connection.id, incoming.id, verified.verifiedUser, 0)
    if identity = invalid then return {ok: false, reason: "identity-mismatch"}
    if identity.userId <> incoming.userId or lcase(identity.username) <> lcase(incoming.username) then return {ok: false, reason: "identity-mismatch"}
    if textValue(verified.accountId) <> incoming.userId.toStr() or lcase(textValue(verified.accountUsername)) <> lcase(incoming.username) then return {ok: false, reason: "identity-mismatch"}
    if type(verified.channels) <> "roArray" or type(verified.groups) <> "roArray" then return {ok: false, reason: "lineup-not-ready"}
    if not incoming.isDefault
        if textValue(verified.profileId) <> "" then return {ok: false, reason: "default-filter-borrowed"}
        if type(verified.channelProfileIds) = "roArray"
            if verified.channelProfileIds.count() > 0 then return {ok: false, reason: "default-filter-borrowed"}
        end if
    end if
    if type(verified.generation) <> "String" and type(verified.generation) <> "roString" then return denied
    scope = userProfileSessionScope(connection, incoming.id, incoming.userId, verified.generation, capturedNonce)
    if scope = invalid then return denied
    for each field in ["userLevel", "isStaff", "isSuperuser"]
        incoming = setCanonicalPreference(incoming, field, identity[field])
    end for
    incoming = setCanonicalPreference(incoming, "role", userProfileResolveRole(identity.userLevel, incoming.role))
    cleaned.profiles[index] = incoming
    cleaned.active = incoming.id
    return {ok: true, reason: "", store: cleaned, scope: scope, target: incoming}
end function

' Storage adoption only. Runtime/Guide configuration is returned for the Scene
' to adopt after this one transaction succeeds; failure cannot auto-play.
function commitUserProfileSwitch(registry as object, connection as object, previous as object, targetId as string, verified as object, targetPinGrant as dynamic, managementGrant as dynamic, managementNonce as string, capturedNonce as string, activeNonce as string, capturedScope as dynamic, activeScope as dynamic) as object
    denied = {ok: false, recoveryRequired: false, reason: "stale-context"}
    if not userProfileSameSession(capturedScope, activeScope) then return denied
    if capturedScope.playlistId <> connection.id or capturedScope.profileId <> previous.active then return denied
    for each profile in previous.profiles
        if profile.id = previous.active
            if capturedScope.accountId <> profile.userId.toStr() then return denied
            if capturedScope.preferenceIdentity <> connectionPreferenceIdentity(connection, profile.userId.toStr()) then return denied
        end if
    end for
    return commitVerifiedUserProfileSwitchState(registry, connection, previous, targetId, verified, targetPinGrant, managementGrant, managementNonce, capturedNonce, activeNonce)
end function

' An unavailable Child has no authenticated outgoing session to fabricate or
' flush. Adult-purpose proof and the freshly authenticated target still apply;
' outgoing dirty marks/data remain for that holder's next real session.
function commitUnavailableChildProfileSwitch(registry as object, connection as object, previous as object, targetId as string, verified as object, targetPinGrant as dynamic, managementGrant as dynamic, managementNonce as string, capturedNonce as string, activeNonce as string) as object
    denied = {ok: false, recoveryRequired: false, reason: "unavailable-child-context"}
    before = normalizeUserProfileStore(previous, connection.id)
    if before.readOnly = true then return denied
    child = false
    for each profile in before.profiles
        if profile.id = before.active then child = profile.role = "child"
    end for
    if not child then return denied
    if verified.verifiedBaseUrl <> connection.url then return denied
    return commitVerifiedUserProfileSwitchState(registry, connection, previous, targetId, verified, targetPinGrant, managementGrant, managementNonce, capturedNonce, activeNonce)
end function

' Shared storage adoption after the authenticated-session OR unavailable-Child
' caller boundary. The same target, PIN, adult grant, nonce and registry checks
' govern both; this helper never clears an outgoing pending roster mark.
function commitVerifiedUserProfileSwitchState(registry as object, connection as object, previous as object, targetId as string, verified as object, targetPinGrant as dynamic, managementGrant as dynamic, managementNonce as string, capturedNonce as string, activeNonce as string) as object
    denied = {ok: false, recoveryRequired: false, reason: "stale-context"}
    connections = loadConnectionStore(registry)
    if connections.readOnly = true or connections.selected <> connection.id then return denied
    currentConnection = connectionStoreEntry(connections, connection.id)
    if currentConnection = invalid then return denied
    if FormatJson(currentConnection) <> FormatJson(normalizeConnectionEntry(connection)) then return denied
    admin = userProfileLoadDeviceAdminPin(registry, connection.id)
    if not admin.ok then return {ok: false, recoveryRequired: true, reason: "pin-recovery"}
    planned = userProfileSwitchPlan(connection, previous, targetId, verified, targetPinGrant, admin.record, managementGrant, capturedNonce, activeNonce, managementNonce)
    if not planned.ok then return {ok: false, recoveryRequired: false, reason: planned.reason}
    oldPreferenceIdentity = userProfilePreferenceIdentity(connection, planned.target)
    planned.target = setCanonicalPreference(planned.target, "preferenceAnchor", planned.scope.preferenceIdentity)
    for i = 0 to planned.store.profiles.count() - 1
        if planned.store.profiles[i].id = planned.target.id then planned.store.profiles[i] = planned.target
    end for
    if planned.target.isDefault
        changingAddress = planned.store.doesExist("addressChangeSnapshot")
        checked = userProfileDefaultAddressCheck(connection, planned.store, verified)
        if not checked.ok then return denied
        recorded = userProfileRecordDefaultIdentity(checked.store, changingAddress)
        if not recorded.ok then return denied
        planned.store = recorded.store
    end if
    keys = {}
    if not planned.target.isDefault then keys[targetId] = verified.apiKey
    prepared = userProfileStoreChanges(registry, previous, planned.store, keys, connection.remember)
    if not prepared.ok then return denied
    preferences = defaultPreferenceStore()
    if registry.exists("settingsV1")
        preferences = loadStrictPreferenceStore(registry)
        if preferences.readOnly = true then return denied
        if type(preferences) <> "roAssociativeArray" then return denied
        if not userProfileInteger(preferences.schema) then return denied
        if preferences.schema <> 1 or type(preferences.device) <> "roAssociativeArray" or type(preferences.accounts) <> "roAssociativeArray" then return denied
    end if
    moved = userProfilePreferenceMovePlan(preferences, oldPreferenceIdentity, planned.scope.preferenceIdentity)
    if not moved.ok then return denied
    preferences = moved.store
    accountKey = preferenceScope(planned.scope.preferenceIdentity)
    incoming = invalid
    if preferences.accounts.doesExist(accountKey)
        incoming = preferences.accounts[accountKey]
        if type(incoming) <> "roAssociativeArray" then return denied
    end if
    incoming = normalizeAccountPreferences(incoming)
    baseline = normalizeDevicePreferences(preferences.device)
    settings = userProfilePrepareSettings(incoming, baseline)
    if not settings.ok then return denied
    nextSettings = userProfileSettingsCommitPlan(preferences, planned.scope.preferenceIdentity, settings.preferences, settings.device)
    if not nextSettings.ok then return denied
    encoded = strictJsonEncode(nextSettings.store)
    if not encoded.ok then return denied
    settingsText = encoded.text
    if preferenceByteBudget(settingsText) > 24000 then return denied
    prepared.changes["settingsV1"] = settingsText
    if planned.target.isDefault and connection.remember = true then prepared.changes[connectionRegistryKey(connection.id)] = verified.apiKey
    saved = userProfileRegistryTransaction(registry, prepared.changes)
    if saved.ok
        saved.store = planned.store
        saved.scope = planned.scope
        saved.preferenceStore = nextSettings.store
        saved.preferences = nextSettings.preferences
        saved.device = settings.device
    end if
    return saved
end function
