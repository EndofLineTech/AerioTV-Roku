' Per-holder, device-local verification policy. Never serializes a PIN, digest
' or salt, and never creates new PIN material.
function userProfilePinBackoffDefault() as object
    return {failures: 0, round: 0, until: 0}
end function

function userProfilePinBackoffValid(state as dynamic) as boolean
    if type(state) <> "roAssociativeArray" then return false
    for each field in ["failures", "round", "until"]
        if not userProfileInteger(state[field]) then return false
    end for
    return state.failures >= 0 and state.failures < 5 and state.round >= 0 and state.round <= 11 and state.until >= 0
end function

function userProfilePinBackoffResult(state as dynamic, verified as boolean, now as integer) as dynamic
    if not userProfilePinBackoffValid(state) or now < 0 then return invalid
    result = {failures: state.failures, round: state.round, until: state.until}
    if state.until > now then return result
    if verified then return userProfilePinBackoffDefault()
    result.failures++
    if result.failures = 5
        result.failures = 0
        result.round++
        if result.round > 11 then result.round = 11
        result.until = now + int(30 * (2 ^ (result.round - 1)))
    end if
    return result
end function

function userProfilePinVerifyAttempt(record as object, state as dynamic, entries as dynamic, now as integer) as object
    result = {verified: false, validInput: false, locked: false, remaining: 0, state: state}
    if not userProfilePinBackoffValid(state) or now < 0 then return result
    if state.until > now
        result.locked = true
        result.remaining = state.until - now
        return result
    end if
    if not userProfilePinRecordValid(record) then return result
    normalized = userProfilePinNormalize(record.pinType, entries)
    if normalized = invalid then return result
    result.validInput = true
    actual = invalid
    if m.pinPolicyDigest <> invalid
        actual = m.pinPolicyDigest(record.pinSalt, normalized)
    else
        actual = userProfilePinHash(record.pinSalt, normalized)
    end if
    if type(actual) <> "String" and type(actual) <> "roString"
        result.validInput = false
        return result
    end if
    result.verified = userProfilePinDigestMatches(actual, record.pinHash)
    result.state = userProfilePinBackoffResult(state, result.verified, now)
    result.remaining = result.state.until - now
    if result.remaining < 0 then result.remaining = 0
    result.locked = result.remaining > 0
    return result
end function

function userProfileHasExitPin(profiles as object, deviceAdmin as dynamic) as boolean
    if userProfilePinRecordValid(deviceAdmin) then return true
    for each profile in profiles
        if userProfileFullAccess(profile.role) and userProfilePinRecordValid(profile) then return true
    end for
    return false
end function

function userProfilePinAttemptStored(registry as object, slotId as string, holder as string, record as object, entries as dynamic, now as integer) as object
    denied = {verified: false, validInput: false, locked: false, remaining: 0, recoveryRequired: true}
    key = userProfilePinBackoffKey(slotId, holder)
    if key = "" then return denied
    profileStore = invalid
    profileIndex = -1
    if record.id <> invalid
        if record.id <> holder then return denied
        profileStore = loadUserProfileStore(registry, slotId)
        if profileStore.readOnly = true then return denied
        for i = 0 to profileStore.profiles.count() - 1
            candidate = profileStore.profiles[i]
            if candidate.id = holder
                if candidate.pinType <> record.pinType or candidate.pinHash <> record.pinHash or candidate.pinSalt <> record.pinSalt then return denied
                profileIndex = i
            end if
        end for
        if profileIndex < 0 then return denied
    end if
    state = userProfilePinBackoffDefault()
    if registry.exists(key)
        parsed = ParseJson(registry.read(key))
        state = userProfileCanonicalFields(parsed, ["failures", "round", "until"])
        if not userProfilePinBackoffValid(state) then return denied
    end if
    checked = userProfilePinVerifyAttempt(record, state, entries, now)
    checked.recoveryRequired = false
    if checked.locked and not checked.validInput then return checked
    if not checked.validInput then return checked
    changes = {}
    changes[key] = FormatJson(checked.state)
    if checked.verified and profileStore <> invalid
        profileStore.profiles[profileIndex] = setCanonicalPreference(profileStore.profiles[profileIndex], "pinLength", entries.count())
        profileText = FormatJson(profileStore)
        if userProfileUtf8ByteCount(profileText) > 8192 then return denied
        changes[userProfileStoreKey(slotId)] = profileText
    end if
    saved = userProfileRegistryTransaction(registry, changes)
    if not saved.ok
        checked.verified = false
        checked.recoveryRequired = true
    end if
    return checked
end function
