' Startup/default migration only. Authenticated switching remains gated until
' scoped state, early roster import, PIN/Child rules and request safety land.
function userProfileConnectionSetupAllowed() as boolean
    if m.profileOwnSignInContext <> invalid then return false
    if m.userProfileRecoveryRequired = true then return false
    if m.global <> invalid
        if m.global.profilegateclosed = true or m.global.profileswitchpending = true then return false
    end if
    if type(m.connectionStore) <> "roAssociativeArray" then return false
    if m.connectionStore.readOnly = true then return false
    if type(m.connectionStore.entries) <> "roArray" then return false
    selected = textValue(m.selectedConnectionId)
    if selected = "" then selected = textValue(m.connectionStore.selected)
    entry = connectionStoreEntry(m.connectionStore, selected)
    if entry = invalid then return m.connectionStore.entries.count() = 0
    if entry.provider <> "dispatcharr" then return true
    store = loadUserProfileStore(m.registry, entry.id)
    if store.readOnly = true then return false
    if store.profiles.count() = 0 then return true
    for each profile in store.profiles
        if profile.id = store.active then return userProfileFullAccess(profile.role)
    end for
    return false
end function

function selectedUserProfileGate() as object
    if m.userProfileRecoveryRequired = true then return {allowed: false, reason: "recovery"}
    entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    m.userProfileStore = invalid
    if entry = invalid then return {allowed: m.connectionStore.readOnly <> true, reason: ""}
    if entry.provider <> "dispatcharr" then return {allowed: true, reason: ""}
    m.userProfileStore = loadUserProfileStore(m.registry, entry.id)
    gate = userProfileStartupGate(m.userProfileStore)
    if gate.reason = "pin"
        for each profile in m.userProfileStore.profiles
            if profile.id = m.userProfileStore.active
                if userProfilePinGrantMatches(m.profileUnlockGrant, entry.id, profile) then return {allowed: true, reason: ""}
            end if
        end for
    end if
    return gate
end function

function userProfileGateMessage(gate as object) as string
    if gate.reason = "child" then return "Could not reach your Dispatcharr server. Protected profiles cannot connect until profile access is available on this build."
    if gate.reason = "recovery" then return "Saved profiles need recovery. This connection will not send requests or overwrite them; use Forget to remove this Roku's copy."
    return "This saved profile requires a protected profile sign-in flow. This build will not connect it using the default account's key."
end function

function ensureConnectedUserProfile(result as object, id = "" as string, now = 0 as integer) as boolean
    entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    if entry = invalid then return false
    if entry.provider <> "dispatcharr" then return true
    gate = selectedUserProfileGate()
    if not gate.allowed
        m.status = userProfileGateMessage(gate)
        return false
    end if
    if type(result.verifiedUser) <> "roAssociativeArray"
        m.status = "The server did not return verified profile authority. Saved profiles were not changed."
        return false
    end if
    actualId = userProfileUserId(result.verifiedUser.id)
    expectedId = userProfileUserId(result.accountId)
    if actualId = invalid or expectedId = invalid then return false
    if actualId <> expectedId then return false
    if id = ""
        for each profile in m.userProfileStore.profiles
            if profile.isDefault then id = profile.id
        end for
        ' UUID names a local record only; never used as salt or credential.
        if id = "" then id = CreateObject("roDeviceInfo").getRandomUUID()
    end if
    if now = 0 then now = CreateObject("roDateTime").asSeconds()
    verified = userProfileFromVerified(entry.id, id, result.verifiedUser, now)
    if verified = invalid
        m.status = "The server returned an incomplete profile identity. Saved profiles were not changed."
        return false
    end if
    candidate = userProfileEnsureDefault(m.userProfileStore, verified)
    if candidate = invalid
        m.status = "This sign-in belongs to a different saved default profile. Existing profile protection was retained; use a separate connection or Forget this Roku's copy."
        return false
    end if
    oldIdentity = connectionPreferenceIdentity(entry, verified.userId.toStr())
    newIdentity = oldIdentity
    for i = 0 to candidate.profiles.count() - 1
        if candidate.profiles[i].isDefault
            oldIdentity = userProfilePreferenceIdentity(entry, candidate.profiles[i])
            candidate.profiles[i] = setCanonicalPreference(candidate.profiles[i], "preferenceAnchor", newIdentity)
        end if
    end for
    moved = {ok: true, moved: false}
    if oldIdentity <> newIdentity and m.registry.exists("settingsV1")
        moved = userProfilePreferenceMovePlan(loadStrictPreferenceStore(m.registry), oldIdentity, newIdentity)
        if not moved.ok then return false
    end if
    ' Record only from this default-owned /me/, never cleared slot metadata.
    ' A persisted change snapshot also freezes recording until its URL-bound
    ' verification/settlement lifecycle can explicitly complete the change.
    changingAddress = candidate.doesExist("addressChangeSnapshot")
    checked = userProfileDefaultAddressCheck(entry, candidate, result)
    if not checked.ok then return false
    recorded = userProfileRecordDefaultIdentity(checked.store, changingAddress)
    if not recorded.ok then return false
    candidate = recorded.store
    if FormatJson(candidate) = FormatJson(m.userProfileStore) and not moved.moved then return true
    prepared = userProfileStoreChanges(m.registry, m.userProfileStore, candidate, {}, entry.remember)
    if not prepared.ok then return false
    if moved.moved
        encoded = strictJsonEncode(moved.store)
        if not encoded.ok then return false
        if preferenceByteBudget(encoded.text) > 24000 then return false
        prepared.changes["settingsV1"] = encoded.text
    end if
    saved = userProfileRegistryTransaction(m.registry, prepared.changes)
    if not saved.ok
        m.userProfileRecoveryRequired = saved.recoveryRequired
        m.status = "Could not save profiles. Existing profile protection was retained; restart before retrying if storage needs recovery."
        return false
    end if
    m.userProfileStore = candidate
    if moved.moved then m.preferenceStore = moved.store
    return true
end function
