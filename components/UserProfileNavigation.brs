' Startup/default migration only. Authenticated switching remains gated until
' scoped state, early roster import, PIN/Child rules and request safety land.
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
    if FormatJson(candidate) = FormatJson(m.userProfileStore) then return true
    saved = commitUserProfileStore(m.registry, m.userProfileStore, candidate, {}, entry.remember)
    if not saved.ok
        m.userProfileRecoveryRequired = saved.recoveryRequired
        m.status = "Could not save profiles. Existing profile protection was retained; restart before retrying if storage needs recovery."
        return false
    end if
    m.userProfileStore = candidate
    return true
end function
