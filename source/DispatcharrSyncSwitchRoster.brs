' Pure target-protection staging. No registry, network, key publication or runtime
' adoption. The controller must bind the actual auth/read nodes and atomically
' validate storage before applying this plan or asking for its new target PIN.
function dispatcharrSyncSwitchRosterPlan(connection as object, previous as object, targetId as string, verified as object, decoded as object, enabled as boolean, now as integer, nonce as string, activeNonce as string, outgoing as dynamic, activeOutgoing as dynamic) as object
    denied = {ok: false, applied: false, reason: "stale-context", store: previous, removed: [], suggestions: [], needsDefaultSwitch: false}
    if userProfileLocalId(nonce) = "" or nonce <> activeNonce then return denied
    if not userProfileSameSession(outgoing, activeOutgoing) then return denied
    if nonce = outgoing.sessionId then return denied
    if connection.provider <> "dispatcharr" or connection.id <> previous.playlistId then return denied
    if outgoing.playlistId <> connection.id or outgoing.profileId <> previous.active then return denied
    if outgoing.preferenceIdentity <> connectionPreferenceIdentity(connection, outgoing.accountId) then return denied
    store = normalizeUserProfileStore(previous, connection.id)
    if store.readOnly = true or now <= 0 then return denied
    if store.pendingRoster
        denied.reason = "outgoing-pending"
        return denied
    end if
    target = invalid
    originalOutgoing = invalid
    targetIndex = -1
    for i = 0 to store.profiles.count() - 1
        profile = store.profiles[i]
        if profile.id = outgoing.profileId then originalOutgoing = profile
        if profile.id = targetId
            target = profile
            targetIndex = i
        end if
    end for
    if target = invalid or originalOutgoing = invalid then return denied
    if target.id = originalOutgoing.id or target.addressHeld then return denied
    if textValue(originalOutgoing.userId) <> outgoing.accountId then return denied
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
    for each removed in merged.removed
        if removed.id = target.id
            denied.reason = "target-removed"
            denied.needsDefaultSwitch = true
            return denied
        end if
        if removed.id = outgoing.profileId
            denied.reason = "outgoing-removal"
            denied.needsDefaultSwitch = true
            return denied
        end if
    end for
    if merged.needsDefaultSwitch then return denied
    merged.store.active = outgoing.profileId
    for each profile in merged.store.profiles
        if profile.id = target.id then target = profile
        if profile.id = outgoing.profileId then result.outgoingProtectionChanged = FormatJson(profile) <> FormatJson(originalOutgoing)
    end for
    result.store = merged.store
    result.target = target
    result.applied = merged.applied
    result.removed = merged.removed
    result.suggestions = merged.suggestions
    result.pinChanged = target.pinType <> originalTarget.pinType or target.pinHash <> originalTarget.pinHash or target.pinSalt <> originalTarget.pinSalt
    return result
end function
