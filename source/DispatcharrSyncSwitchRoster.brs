' Pure target-protection staging. No registry, network, key publication or runtime
' adoption. The controller must bind the actual auth/read nodes and atomically
' validate storage before applying this plan or asking for its new target PIN.
function dispatcharrSyncSwitchRosterPlan(connection as object, previous as object, targetId as string, verified as object, decoded as object, enabled as boolean, now as integer, nonce as string, activeNonce as string, outgoing as dynamic, activeOutgoing as dynamic, localPending = false as boolean) as object
    denied = {ok: false, applied: false, reason: "stale-context", store: previous, removed: [], suggestions: [], needsDefaultSwitch: false}
    if userProfileLocalId(nonce) = "" or nonce <> activeNonce then return denied
    if not userProfileSameSession(outgoing, activeOutgoing) then return denied
    if nonce = outgoing.sessionId then return denied
    if connection.provider <> "dispatcharr" or connection.id <> previous.playlistId then return denied
    if outgoing.playlistId <> connection.id or outgoing.profileId <> previous.active then return denied
    if outgoing.preferenceIdentity <> connectionPreferenceIdentity(connection, outgoing.accountId) then return denied
    store = normalizeUserProfileStore(previous, connection.id)
    if store.readOnly = true or now <= 0 then return denied
    if store.pendingRoster and not localPending
        denied.reason = "outgoing-pending"
        return denied
    end if
    for each profile in store.profiles
        if profile.id = outgoing.profileId and textValue(profile.userId) <> outgoing.accountId then return denied
    end for
    result = dispatcharrSyncSwitchRosterContentPlan(connection, store, targetId, verified, decoded, enabled, now)
    if not result.ok then result.store = previous
    return result
end function

' An unavailable Child has no outgoing authenticated session to borrow or
' fabricate. Its actual empty actor/key and current adult-purpose admission are
' separate inputs; storage/controller callers must freshly bind those inputs.
' Private controller/storage callers use this without inventing a Child scope.
function dispatcharrSyncUnavailableChildRosterPlan(connection as object, previous as object, targetId as string, verified as object, decoded as object, enabled as boolean, now as integer, nonce as string, activeNonce as string, activeOutgoing as dynamic, activeKey as string, deviceAdmin as dynamic, management as dynamic, managementNonce as string) as object
    denied = {ok: false, applied: false, reason: "stale-context", store: previous, removed: [], suggestions: [], needsDefaultSwitch: false}
    if userProfileLocalId(nonce) = "" or nonce <> activeNonce then return denied
    if activeOutgoing <> invalid or activeKey <> "" then return denied
    if connection.provider <> "dispatcharr" or connection.id <> previous.playlistId then return denied
    store = normalizeUserProfileStore(previous, connection.id)
    if store.readOnly = true or now <= 0 then return denied
    child = false
    for each profile in store.profiles
        if profile.id = store.active then child = profile.role = "child"
    end for
    if not child then return denied
    if not userProfileManagementGrantMatches(store, deviceAdmin, management, managementNonce) then return denied
    ' Until writer settlement exists, never erase a pending local roster edit.
    if store.pendingRoster
        denied.reason = "outgoing-pending"
        return denied
    end if
    result = dispatcharrSyncSwitchRosterContentPlan(connection, store, targetId, verified, decoded, enabled, now)
    if not result.ok then result.store = previous
    return result
end function

' Content-only pure calculation shared AFTER the authenticated-session or
' unavailable-Child admission wrapper. It grants no persistence/runtime access.
function dispatcharrSyncSwitchRosterContentPlan(connection as object, store as object, targetId as string, verified as object, decoded as object, enabled as boolean, now as integer, allowTargetRemoval = false as boolean, allowOutgoingRemoval = false as boolean) as object
    denied = {ok: false, applied: false, reason: "stale-context", store: store, removed: [], suggestions: [], needsDefaultSwitch: false}
    target = invalid
    originalOutgoing = invalid
    targetIndex = -1
    for i = 0 to store.profiles.count() - 1
        profile = store.profiles[i]
        if profile.id = store.active then originalOutgoing = profile
        if profile.id = targetId
            target = profile
            targetIndex = i
        end if
    end for
    if target = invalid or originalOutgoing = invalid then return denied
    if target.id = originalOutgoing.id or target.addressHeld or target.addOrigin = "paused" then return denied
    if verified.ok <> true or verified.phase <> "verified" or verified.verifiedBaseUrl <> connection.url then return denied
    if GetInterface(verified.apiKey, "ifString") = invalid then return denied
    if verified.apiKey = "" or len(verified.apiKey) > 512 then return denied
    facts = userProfileFromVerified(connection.id, target.id, verified.verifiedUser, now)
    if facts = invalid then return denied
    if facts.userId <> target.userId or lcase(facts.username) <> lcase(target.username) then return denied
    if textValue(verified.accountId) <> target.userId.toStr() or lcase(textValue(verified.accountUsername)) <> lcase(target.username) then return denied
    originalTarget = target
    for each field in ["userLevel", "isStaff", "isSuperuser"]
        target = setCanonicalPreference(target, field, facts[field])
    end for
    target = setCanonicalPreference(target, "role", userProfileResolveRole(facts.userLevel, target.role))
    store.profiles[targetIndex] = target
    result = {ok: true, applied: false, reason: "", store: store, target: target, removed: [], suggestions: [], pinChanged: false, outgoingProtectionChanged: false, needsDefaultSwitch: false}
    ' Import authority belongs to the authenticated target, not to whichever
    ' outgoing profile happens still to own the playing/rollback scope.
    if target.role = "child" or not enabled then return result
    staging = copyJson(store)
    staging.active = target.id
    merged = dispatcharrSyncRosterMerge(staging, decoded, enabled, now)
    if not merged.ok then return denied
    targetRemoved = false
    outgoingRemoved = false
    ' Actual actor retirement wins independently of roster ordering when both
    ' the selected target and the outgoing holder have tombstones.
    if not allowOutgoingRemoval
        for each removed in merged.removed
            if removed.id = originalOutgoing.id
                denied.reason = "outgoing-removal"
                denied.needsDefaultSwitch = true
                return denied
            end if
        end for
    end if
    for each removed in merged.removed
        if removed.id = target.id
            if not allowTargetRemoval
                denied.reason = "target-removed"
                denied.needsDefaultSwitch = true
                return denied
            end if
            targetRemoved = true
        end if
        if removed.id = originalOutgoing.id
            if not allowOutgoingRemoval
                denied.reason = "outgoing-removal"
                denied.needsDefaultSwitch = true
                return denied
            end if
            outgoingRemoved = true
        end if
    end for
    if merged.needsDefaultSwitch and not targetRemoved then return denied
    merged.store.active = originalOutgoing.id
    if outgoingRemoved
        for each profile in merged.store.profiles
            if profile.isDefault then merged.store.active = profile.id
        end for
    end if
    for each profile in merged.store.profiles
        if profile.id = target.id then target = profile
        if profile.id = originalOutgoing.id then result.outgoingProtectionChanged = userProfileSwitchProtectionSnapshot(profile) <> userProfileSwitchProtectionSnapshot(originalOutgoing)
    end for
    result.store = merged.store
    result.targetRemoved = targetRemoved
    result.needsDefaultSwitch = outgoingRemoved
    result.target = target
    if targetRemoved then result.target = invalid
    result.applied = merged.applied
    result.removed = merged.removed
    result.suggestions = merged.suggestions
    if not targetRemoved then result.pinChanged = target.pinType <> originalTarget.pinType or target.pinHash <> originalTarget.pinHash or target.pinSalt <> originalTarget.pinSalt
    return result
end function
