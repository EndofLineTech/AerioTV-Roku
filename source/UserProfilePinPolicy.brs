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

' Adult gates reveal no holder names. Both PIN types and the reserved per-slot
' Device Admin holder count, even when that holder has no usable server key.
function userProfileAdultPinHolders(profiles as object, deviceAdmin as dynamic) as dynamic
    holders = []
    for each profile in profiles
        if type(profile) <> "roAssociativeArray" then return invalid
        if userProfileFullAccess(profile.role)
            if profile.pinType <> "none"
                if not userProfilePinRecordValid(profile) then return invalid
                if userProfileLocalId(profile.id) = "" then return invalid
                holders.push({id: profile.id, record: profile})
            end if
        end if
    end for
    if deviceAdmin <> invalid
        if not userProfilePinRecordValid(deviceAdmin) then return invalid
        holders.push({id: "device-admin", record: deviceAdmin})
    end if
    return holders
end function

function userProfileAdultPinLockSummary(holders as object, states as object, inputType as string, now as integer) as object
    allLocked = holders.count() > 0
    typeLocked = true
    matching = 0
    earliest = 0
    selectedEarliest = 0
    for each holder in holders
        state = states[holder.id]
        remaining = state.until - now
        if remaining <= 0
            allLocked = false
        else
            if earliest = 0 or remaining < earliest then earliest = remaining
        end if
        if holder.record.pinType = inputType
            matching++
            if remaining <= 0
                typeLocked = false
            else
                if selectedEarliest = 0 or remaining < selectedEarliest then selectedEarliest = remaining
            end if
        end if
    end for
    if matching = 0 then typeLocked = false
    remaining = 0
    if typeLocked then remaining = selectedEarliest
    if allLocked then remaining = earliest
    return {locked: allLocked, typeLocked: typeLocked, remaining: remaining, matching: matching}
end function

' Plan every ledger change before a single persistence transaction. A valid
' adult PIN resets only that holder; it never penalizes another household PIN.
function userProfileAdultPinPlan(holders as dynamic, states as object, entries as dynamic, inputType as string, now as integer) as object
    result = {verified: false, validInput: false, locked: false, typeLocked: false, remaining: 0, recoveryRequired: false, noPins: false, holder: "", writes: {}, inputTypes: []}
    if type(holders) <> "roArray" or now < 0
        result.recoveryRequired = true
        return result
    end if
    if holders.count() = 0
        result.noPins = true
        return result
    end if
    current = {}
    seenTypes = {}
    for each holder in holders
        if type(holder) <> "roAssociativeArray" then result.recoveryRequired = true : return result
        if not userProfilePinRecordValid(holder.record) then result.recoveryRequired = true : return result
        if type(holder.id) <> "String" and type(holder.id) <> "roString" then result.recoveryRequired = true : return result
        if holder.id = "" or current.doesExist(holder.id) then result.recoveryRequired = true : return result
        state = userProfilePinBackoffDefault()
        if states.doesExist(holder.id) then state = states[holder.id]
        if not userProfilePinBackoffValid(state) then result.recoveryRequired = true : return result
        current[holder.id] = state
        if not seenTypes.doesExist(holder.record.pinType)
            result.inputTypes.push(holder.record.pinType)
            seenTypes[holder.record.pinType] = true
        end if
    end for
    lock = userProfileAdultPinLockSummary(holders, current, inputType, now)
    result.locked = lock.locked
    result.typeLocked = lock.typeLocked
    result.remaining = lock.remaining
    if lock.locked or lock.typeLocked or lock.matching = 0 then return result
    if userProfilePinNormalize(inputType, entries) = invalid then return result
    result.validInput = true
    attempts = {}
    for each holder in holders
        if holder.record.pinType = inputType and current[holder.id].until <= now
            checked = userProfilePinVerifyAttempt(holder.record, current[holder.id], entries, now)
            if not checked.validInput
                result.validInput = false
                result.recoveryRequired = true
                return result
            end if
            if checked.verified
                result.verified = true
                result.holder = holder.id
                result.writes[holder.id] = checked.state
                return result
            end if
            attempts[holder.id] = checked.state
        end if
    end for
    result.writes = attempts
    for each id in attempts
        current[id] = attempts[id]
    end for
    lock = userProfileAdultPinLockSummary(holders, current, inputType, now)
    result.locked = lock.locked
    result.typeLocked = lock.typeLocked
    result.remaining = lock.remaining
    return result
end function

function userProfileNormalizeDeviceAdminPin(raw as dynamic) as dynamic
    canonical = userProfileCanonicalFields(raw, ["pinType", "pinHash", "pinSalt", "pinLength"])
    if not userProfilePinRecordValid(canonical) then return invalid
    length = 0
    if canonical.doesExist("pinLength")
        length = canonical["pinLength"]
        if not userProfileInteger(length) then return invalid
        if length <> 0 and (length < 4 or length > 6) then return invalid
    end if
    record = ParseJson("{}")
    record["pinType"] = canonical.pinType
    record["pinHash"] = canonical.pinHash
    record["pinSalt"] = canonical.pinSalt
    record["pinLength"] = length
    return record
end function

' Existing records only. This loader is not a Device Admin creation/import API;
' the reserved per-slot record is never read from sync or a setup payload.
function userProfileLoadDeviceAdminPin(registry as object, slotId as string) as object
    denied = {ok: false, record: invalid}
    key = userProfileDeviceAdminKey(slotId)
    if key = "" then return denied
    if not registry.exists(key) then return {ok: true, record: invalid}
    record = userProfileNormalizeDeviceAdminPin(ParseJson(registry.read(key)))
    if record = invalid then return denied
    return {ok: true, record: record}
end function

' All matching-holder ledgers (and a learned length) share one Flush/rollback.
' A changed captured roster/admin record requires reopening the protected gate.
function userProfileAdultPinAttemptStored(registry as object, slotId as string, previous as object, expectedAdmin as dynamic, entries as dynamic, inputType as string, now as integer) as object
    denied = {verified: false, validInput: false, locked: false, typeLocked: false, remaining: 0, recoveryRequired: true, noPins: false, holder: "", writes: {}, inputTypes: []}
    actual = loadUserProfileStore(registry, slotId)
    captured = normalizeUserProfileStore(previous, slotId)
    if actual.readOnly = true or captured.readOnly = true then return denied
    if FormatJson(actual) <> FormatJson(captured) then return denied
    admin = userProfileLoadDeviceAdminPin(registry, slotId)
    if not admin.ok then return denied
    if expectedAdmin <> invalid
        expectedAdmin = userProfileNormalizeDeviceAdminPin(expectedAdmin)
        if expectedAdmin = invalid then return denied
    end if
    if FormatJson(admin.record) <> FormatJson(expectedAdmin) then return denied
    holders = userProfileAdultPinHolders(actual.profiles, admin.record)
    if type(holders) <> "roArray" then return denied
    states = {}
    for each holder in holders
        key = userProfilePinBackoffKey(slotId, holder.id)
        if key = "" then return denied
        state = userProfilePinBackoffDefault()
        if registry.exists(key)
            state = userProfileCanonicalFields(ParseJson(registry.read(key)), ["failures", "round", "until"])
            if not userProfilePinBackoffValid(state) then return denied
        end if
        states[holder.id] = state
    end for
    planned = userProfileAdultPinPlan(holders, states, entries, inputType, now)
    if planned.recoveryRequired or planned.writes.count() = 0 then return planned
    changes = {}
    for each id in planned.writes
        changes[userProfilePinBackoffKey(slotId, id)] = FormatJson(planned.writes[id])
    end for
    if planned.verified
        if planned.holder = "device-admin"
            admin.record = setCanonicalPreference(admin.record, "pinLength", entries.count())
            changes[userProfileDeviceAdminKey(slotId)] = FormatJson(admin.record)
        else
            for i = 0 to actual.profiles.count() - 1
                if actual.profiles[i].id = planned.holder then actual.profiles[i] = setCanonicalPreference(actual.profiles[i], "pinLength", entries.count())
            end for
            profileText = FormatJson(actual)
            if userProfileUtf8ByteCount(profileText) > 8192 then return denied
            changes[userProfileStoreKey(slotId)] = profileText
        end if
    end if
    saved = userProfileRegistryTransaction(registry, changes)
    if not saved.ok
        planned.verified = false
        planned.recoveryRequired = true
        return planned
    end if
    planned.store = actual
    planned.deviceAdmin = admin.record
    return planned
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
