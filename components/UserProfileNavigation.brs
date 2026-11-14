' Startup/default migration only. Authenticated switching remains gated until
' scoped state, early roster import, PIN/Child rules and request safety land.
function prepareUserProfileLaunchRestore(entry as dynamic) as boolean
    if entry = invalid then return true
    if entry.provider <> "dispatcharr" then return true
    store = loadUserProfileStore(m.registry, entry.id)
    if store.readOnly = true then return false
    if store.profiles.count() = 0 then return true
    selected = invalid
    defaultId = ""
    for each profile in store.profiles
        if profile.id = store.active then selected = profile
        if profile.isDefault then defaultId = profile.id
    end for
    if selected = invalid or defaultId = "" then return false
    ' Only cold-process restoration uses this automatic fallback. A rejected
    ' active key/reconnect must keep its holder; a Child never leaves here.
    if selected.isDefault or selected.role = "child" then return true
    ownKey = ""
    if entry.remember then ownKey = m.registry.read(userProfileKeyName(entry.id, selected.id))
    if not selected.addressHeld and ownKey <> "" then return true
    candidate = setCanonicalPreference(store, "active", defaultId)
    saved = commitUserProfileStore(m.registry, store, candidate, {}, entry.remember)
    if not saved.ok
        ' Even a successful rollback cannot allow startup with the slot key
        ' while the persisted selection still names another holder.
        m.userProfileRecoveryRequired = true
        return false
    end if
    m.userProfileStore = candidate
    m.profileUnlockGrant = invalid
    return true
end function

' Every connect/lineup refresh must use the selected user's own server lineup.
' A slot's client-side Channel Profile choice belongs only to its default.
function configureUserProfileConnectionTask(task as object, entry as object, bindDefault as boolean) as boolean
    store = loadUserProfileStore(m.registry, entry.id)
    if store.readOnly = true then return false
    task.profileId = entry.profileId
    task.channelProfileIds = entry.channelProfileIds
    if store.profiles.count() = 0 then return not bindDefault
    for each profile in store.profiles
        if profile.id = store.active
            if profile.addressHeld then return false
            if not profile.isDefault
                task.profileId = ""
                task.channelProfileIds = []
            end if
            if bindDefault or not profile.isDefault or profile.role = "child"
                task.expectedUserId = profile.userId.toStr()
                task.expectedUsername = profile.username
            end if
            return true
        end if
    end for
    return false
end function

' A permission refresh updates only the active holder's live server authority.
' It is not account replacement, credential recovery, or a new default proof.
function refreshActiveUserProfileAuthority(result as object, now as integer) as boolean
    if m.userProfileRecoveryRequired = true or now <= 0 then return false
    scope = m.activeUserScope
    if type(scope) <> "roAssociativeArray" then return false
    entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    if entry = invalid then return false
    if entry.provider <> "dispatcharr" or scope.playlistId <> entry.id then return false
    if result.verifiedBaseUrl <> entry.url then return false
    if scope.preferenceIdentity <> connectionPreferenceIdentity(entry, scope.accountId) then return false
    before = loadUserProfileStore(m.registry, entry.id)
    if before.readOnly = true or before.active <> scope.profileId then return false
    candidate = copyPreferenceValue(before)
    found = false
    for i = 0 to candidate.profiles.count() - 1
        profile = candidate.profiles[i]
        if profile.id = scope.profileId
            if profile.addressHeld or profile.userId.toStr() <> scope.accountId then return false
            verified = userProfileFromVerified(entry.id, profile.id, result.verifiedUser, now)
            if verified = invalid then return false
            if verified.userId <> profile.userId or lcase(verified.username) <> lcase(profile.username) then return false
            nextRole = userProfileResolveRole(verified.userLevel, profile.role)
            if nextRole <> profile.role
                if now <= profile.updatedAt then return false
                profile = setCanonicalPreference(profile, "updatedAt", now)
                candidate = setCanonicalPreference(candidate, "pendingRoster", true)
            end if
            for each field in ["userLevel", "isStaff", "isSuperuser"]
                profile = setCanonicalPreference(profile, field, verified[field])
            end for
            profile = setCanonicalPreference(profile, "role", nextRole)
            candidate.profiles[i] = profile
            found = true
        end if
    end for
    if not found then return false
    if FormatJson(candidate) <> FormatJson(before)
        saved = commitUserProfileStore(m.registry, before, candidate, {}, entry.remember)
        if not saved.ok then return false
    end if
    m.userProfileStore = candidate
    return true
end function

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

function selectedUserProfileIsChild() as boolean
    if type(m.connectionStore) <> "roAssociativeArray" then return false
    if type(m.connectionStore.entries) <> "roArray" then return false
    entry = connectionStoreEntry(m.connectionStore, textValue(m.selectedConnectionId))
    if entry = invalid or entry.provider <> "dispatcharr" then return false
    store = loadUserProfileStore(m.registry, entry.id)
    if store.readOnly = true then return false
    for each profile in store.profiles
        if profile.id = store.active then return profile.role = "child"
    end for
    return false
end function

function userProfileSetupFieldAllowed(field as string) as boolean
    if not userProfileConnectionSetupAllowed() then return false
    credentialField = field = "method" or field = "username" or field = "password" or field = "key" or field = "profile"
    if not credentialField then return true
    entry = connectionStoreEntry(m.connectionStore, textValue(m.selectedConnectionId))
    if entry = invalid then return false
    if entry.provider <> "dispatcharr" then return true
    store = loadUserProfileStore(m.registry, entry.id)
    if store.readOnly = true then return false
    if store.profiles.count() = 0 then return true
    for each profile in store.profiles
        if profile.id = store.active then return profile.isDefault
    end for
    return false
end function

function captureUserProfileSetupEdit(field as string, nonce as string) as dynamic
    if userProfileLocalId(nonce) = "" or not userProfileSetupFieldAllowed(field) then return invalid
    slot = textValue(m.selectedConnectionId)
    entry = connectionStoreEntry(m.connectionStore, slot)
    connection = ""
    roster = ""
    if entry <> invalid
        ' Capture the same normalized representation used by the registry
        ' loader; native in-memory patch aliases need not serialize identically.
        connection = FormatJson(normalizeConnectionEntry(entry))
        if entry.provider = "dispatcharr" then roster = m.registry.read(userProfileStoreKey(entry.id))
    end if
    session = ""
    if m.global <> invalid then session = textValue(m.global.activeusersession)
    return {nonce: nonce, field: field, slot: slot, connection: connection, roster: roster, session: session}
end function

function userProfileSetupEditCurrent(context as dynamic) as boolean
    if type(context) <> "roAssociativeArray" then return false
    if context.nonce <> m.setupEditNonce or context.slot <> textValue(m.selectedConnectionId) then return false
    if not userProfileSetupFieldAllowed(context.field) then return false
    session = ""
    if m.global <> invalid then session = textValue(m.global.activeusersession)
    if context.session <> session then return false
    connections = loadConnectionStore(m.registry)
    if connections.readOnly = true then return false
    entry = connectionStoreEntry(connections, context.slot)
    if entry = invalid then return context.connection = "" and connections.entries.count() = 0
    if FormatJson(entry) <> context.connection then return false
    if entry.provider = "dispatcharr"
        if m.registry.read(userProfileStoreKey(entry.id)) <> context.roster then return false
    end if
    return true
end function

function selectedUserProfileGate() as object
    if m.userProfileRecoveryRequired = true then return {allowed: false, reason: "recovery"}
    entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    m.userProfileStore = invalid
    if entry = invalid then return {allowed: m.connectionStore.readOnly <> true, reason: ""}
    if entry.provider <> "dispatcharr" then return {allowed: true, reason: ""}
    m.userProfileStore = loadUserProfileStore(m.registry, entry.id)
    childReady = m.profileChildAccessReady = true
    ownCredential = false
    for each profile in m.userProfileStore.profiles
        if profile.id = m.userProfileStore.active and not profile.addressHeld and (not profile.isDefault or (profile.role = "child" and childReady))
            if entry.remember
                keyName = userProfileKeyName(entry.id, profile.id)
                if profile.isDefault then keyName = connectionRegistryKey(entry.id)
                ownCredential = m.registry.read(keyName) <> ""
                if profile.isDefault and entry.id = "legacy" and not ownCredential then ownCredential = m.registry.read("apiKey") <> ""
            end if
            if type(m.profileSessionKeys) = "roAssociativeArray"
                bucket = preferenceScope(entry.url + "|" + entry.id + "|" + profile.id)
                if m.profileSessionKeys.doesExist(bucket) then ownCredential = textValue(m.profileSessionKeys[bucket]) <> ""
            end if
        end if
    end for
    gate = userProfileStartupGate(m.userProfileStore, ownCredential, childReady)
    if gate.reason = "pin"
        for each profile in m.userProfileStore.profiles
            if profile.id = m.userProfileStore.active
                if userProfilePinGrantMatches(m.profileUnlockGrant, entry.id, profile)
                    if profile.role = "child" then return userProfileStartupGate(m.userProfileStore, ownCredential, childReady, true)
                    return {allowed: true, reason: ""}
                end if
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
    for each selected in m.userProfileStore.profiles
        if selected.id = m.userProfileStore.active and not selected.isDefault
            return ensureConnectedNonDefaultProfile(entry, selected, result)
        end if
    end for
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
    if replacing and entry.id = "legacy" and m.registry.exists("settingsV1")
        originalSettings = loadStrictPreferenceStore(m.registry)
        if originalSettings.readOnly = true then return false
        originalIdentity = m.registry.read("accountIdentity")
        if originalIdentity <> "" and originalSettings.accounts.doesExist(preferenceScope(originalIdentity))
            m.status = "Reconnect the previous account to migrate its legacy settings before replacing this default. Existing data was retained."
            return false
        end if
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
    legacyMigration = {ok: true, moved: false, retireLegacy: false}
    if not replacing
        legacyMigration = legacyOwnerPreferencePlan(m.registry, entry, verified.userId.toStr())
        if not legacyMigration.ok
            m.status = "Could not reconcile this account's legacy settings without losing data. Existing values were retained."
            return false
        end if
        if legacyMigration.moved then moved = legacyMigration
    end if
    if m.registry.exists("settingsV1") and (oldIdentity <> newIdentity or replacing)
        settings = loadStrictPreferenceStore(m.registry)
        if legacyMigration.moved then settings = legacyMigration.store
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
            if legacyMigration.moved and not moved.moved then moved = legacyMigration
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
    if legacyMigration.retireLegacy then prepared.changes["preferences"] = ""
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

' Reconnect is not an own-password recovery or a default replacement. A saved
' nondefault holder must still match BOTH its server ID and username.
function ensureConnectedNonDefaultProfile(entry as object, selected as object, result as object) as boolean
    verified = userProfileFromVerified(entry.id, selected.id, result.verifiedUser, 0)
    if verified = invalid then return false
    if verified.userId <> selected.userId or lcase(verified.username) <> lcase(selected.username)
        m.status = "This profile needs its own Dispatcharr sign-in. Saved profiles and data were retained."
        return false
    end if
    candidate = copyPreferenceValue(m.userProfileStore)
    target = copyPreferenceValue(selected)
    for each field in ["userLevel", "isStaff", "isSuperuser"]
        target = setCanonicalPreference(target, field, verified[field])
    end for
    target = setCanonicalPreference(target, "role", userProfileResolveRole(verified.userLevel, selected.role))
    oldIdentity = userProfilePreferenceIdentity(entry, selected)
    newIdentity = connectionPreferenceIdentity(entry, selected.userId.toStr())
    target = setCanonicalPreference(target, "preferenceAnchor", newIdentity)
    for i = 0 to candidate.profiles.count() - 1
        if candidate.profiles[i].id = selected.id then candidate.profiles[i] = target
    end for
    moved = {ok: true, moved: false}
    if oldIdentity <> newIdentity and m.registry.exists("settingsV1")
        moved = userProfilePreferenceMovePlan(loadStrictPreferenceStore(m.registry), oldIdentity, newIdentity)
        if not moved.ok then return false
    end if
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
        return false
    end if
    m.userProfileStore = candidate
    if moved.moved then m.preferenceStore = moved.store
    return true
end function
