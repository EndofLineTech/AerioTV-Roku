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
    previousDefault = invalid
    replacing = false
    for each profile in m.userProfileStore.profiles
        if profile.isDefault
            previousDefault = profile
            replacing = profile.userId <> verified.userId or lcase(profile.username) <> lcase(verified.username)
        end if
    end for
    ' Replacement belongs to authentication BEFORE the new holder's early
    ' App Data/protection read. A later full-lineup identity change must restart
    ' that sequence, never activate an account whose protection was not read.
    if replacing and result.phase <> "verified"
        m.status = "The account changed during sign-in. Reconnect to load this user's profile protection."
        return false
    end if
    if replacing and m.registry.exists("preferences")
        m.status = "Reconnect the previous account to migrate its legacy settings before replacing this default. Existing data was retained."
        return false
    end if
    candidate = userProfileEnsureDefault(m.userProfileStore, verified, result.phase = "verified")
    if candidate = invalid
        m.status = "Could not safely replace this default identity. Existing profiles and data were retained."
        return false
    end if
    oldIdentity = connectionPreferenceIdentity(entry, verified.userId.toStr())
    newIdentity = oldIdentity
    if previousDefault <> invalid then oldIdentity = userProfilePreferenceIdentity(entry, previousDefault)
    for i = 0 to candidate.profiles.count() - 1
        if candidate.profiles[i].isDefault
            candidate.profiles[i] = setCanonicalPreference(candidate.profiles[i], "preferenceAnchor", newIdentity)
        end if
    end for
    moved = {ok: true, moved: false}
    if m.registry.exists("settingsV1") and (oldIdentity <> newIdentity or replacing)
        settings = loadStrictPreferenceStore(m.registry)
        if settings.readOnly = true then return false
        if replacing
            oldKey = preferenceScope(oldIdentity)
            newKey = preferenceScope(newIdentity)
            ' A different existing destination has no proven lineage to this
            ' rebuilt local holder. Never overwrite or adopt its personal data.
            if oldKey <> newKey and settings.accounts.doesExist(newKey) then return false
            seed = invalid
            if settings.accounts.doesExist(oldKey) then seed = settings.accounts[oldKey]
            nextSettings = copyPreferenceValue(settings)
            nextSettings.accounts[newKey] = userProfileSeedAccountPreferences(seed)
            moved = {ok: true, moved: true, store: nextSettings}
        else
            moved = userProfilePreferenceMovePlan(settings, oldIdentity, newIdentity)
            if not moved.ok then return false
        end if
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
    if replacing
        ' Full activation may persist the newly verified key later. Until then,
        ' a rebuilt default must not fall back to its previous holder's key.
        prepared.changes[connectionRegistryKey(entry.id)] = ""
        if entry.id = "legacy" then prepared.changes["apiKey"] = ""
    end if
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
    if replacing and type(m.profileSessionKeys) = "roAssociativeArray"
        m.profileSessionKeys.delete(preferenceScope(entry.url + "|" + entry.id + "|" + previousDefault.id))
    end if
    if moved.moved then m.preferenceStore = moved.store
    return true
end function
