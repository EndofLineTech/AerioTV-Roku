' Pure bounded scheduling, not request/storage authority. Callers still prove the
' current own actor/key/roots and broker on every Task request. Scheduling only
' sees a digest of local wire-relevant roster inputs, never the inputs themselves.
function dispatcharrSyncRosterIntentDigest(store as object) as string
    rows = []
    for each p in store.profiles
        ' The merge uses the raw order for ties, presentation claims and
        ' add freshness. Launch choices, PIN entry length and local address
        ' bookkeeping aren't roster write inputs.
        rows.push([p.userId, p.username, p.displayName, p.pinType, p.pinHash, p.pinSalt, p.role, p.userLevel, p.updatedAt, p.avatar.icon, p.avatar.color, p.order, p.isDefault, p.createdAt, p.addOrigin, p.displayNameClaimed, p.avatarClaimed])
    end for
    return requestGateCredentialHash(FormatJson([rows, store.removed]))
end function

function dispatcharrSyncScheduleBind(previous as dynamic, scope as dynamic, now as integer) as dynamic
    if type(scope) <> "roAssociativeArray" or now <= 0 then return invalid
    if userProfileLocalId(textValue(scope.sessionId)) = "" or userProfileLocalId(textValue(scope.profileId)) = "" then return invalid
    captured = {}
    for each field in ["playlistId", "profileId", "accountId", "preferenceIdentity", "authorizationGeneration", "sessionId"]
        if GetInterface(scope[field], "ifString") = invalid or scope[field] = "" then return invalid
        captured[field] = scope[field]
    end for
    slots = []
    sequence = 0
    if type(previous) = "roAssociativeArray"
        slots = copyPreferenceValue(previous.pickerSlots)
        sequence = previous.sequence
    end if
    return {scope: captured, pickerSlots: slots, sequence: sequence, dueAt: now, rereadAt: 0, periodicAt: now + 900, dirtyAt: 0, dirtyIntent: "", pending: false, retryAt: 0, failures: 0, pause: "", writeBlockedRoot: "", creationBlocked: false, flight: invalid}
end function

function dispatcharrSyncScheduleDirty(previous as object, scope as dynamic, intent as string, pending as boolean, now as integer, localChange = true as boolean) as object
    if not userProfileSameSession(previous.scope, scope) or now <= 0 then return previous
    state = copyPreferenceValue(previous)
    state.pending = pending
    if not pending
        state.dirtyAt = 0
    else if not previous.pending or intent <> state.dirtyIntent
        state.dirtyAt = now + 1
        if localChange
            state.writeBlockedRoot = ""
            if state.pause = "too-large" then state.pause = ""
        end if
    end if
    state.dirtyIntent = intent
    return state
end function

function dispatcharrSyncScheduleRequest(previous as object, scope as dynamic, event as string, now as integer) as object
    if not userProfileSameSession(previous.scope, scope) or now <= 0 then return previous
    if event <> "picker" and event <> "network-return" then return previous
    state = copyPreferenceValue(previous)
    if event = "network-return" and state.pause = "" then state.retryAt = 0
    if event = "picker"
        found = false
        for each slot in state.pickerSlots
            if slot.id = scope.playlistId
                if now < slot.last + 30 then return previous
                slot.last = now
                found = true
            end if
        end for
        if not found
            if state.pickerSlots.count() >= 4 then return previous
            state.pickerSlots.push({id: scope.playlistId, last: now})
        end if
        state.rereadAt = now + 2
    end if
    state.dueAt = now
    return state
end function

function dispatcharrSyncScheduleTake(previous as object, scope as dynamic, now as integer, allowed as boolean, pullRequired = false as boolean) as object
    denied = {run: false, state: previous}
    if not allowed or now <= 0 or not userProfileSameSession(previous.scope, scope) then return denied
    if previous.flight <> invalid or now < previous.retryAt then return denied
    due = pullRequired or (previous.dueAt > 0 and now >= previous.dueAt)
    due = due or (previous.rereadAt > 0 and now >= previous.rereadAt) or now >= previous.periodicAt
    due = due or (previous.pending and previous.writeBlockedRoot = "" and previous.dirtyAt > 0 and now >= previous.dirtyAt)
    if not due then return denied
    state = copyPreferenceValue(previous)
    push = not pullRequired and state.pending and state.writeBlockedRoot = "" and (state.dirtyAt = 0 or now >= state.dirtyAt)
    if state.dueAt > 0 and now >= state.dueAt then state.dueAt = 0
    if state.rereadAt > 0 and now >= state.rereadAt then state.rereadAt = 0
    if push then state.dirtyAt = 0
    state.periodicAt = now + 900
    state.sequence++
    state.flight = {id: state.sequence, scope: copyPreferenceValue(state.scope), intent: state.dirtyIntent, push: push}
    return {run: true, push: push, state: state, ticket: state.flight}
end function

function dispatcharrSyncScheduleComplete(previous as object, ticket as dynamic, ok as boolean, now as integer, failure = "retry" as string, creationBlocked = false as boolean) as object
    if previous.flight = invalid or type(ticket) <> "roAssociativeArray" or now <= 0 then return previous
    if not userProfileSameSession(previous.scope, ticket.scope) then return previous
    if FormatJson(previous.flight) <> FormatJson(ticket) then return previous
    state = copyPreferenceValue(previous)
    state.flight = invalid
    state.retryAt = 0
    state.pause = ""
    if not ok
        ' An oversize result applies only to the body prepared for this ticket.
        ' Leave a newer observed edit's debounce and queued reads intact.
        if ticket.push and failure = "too-large" and ticket.intent <> state.dirtyIntent then return state
        state.failures++
        delay = 30
        if state.failures = 2 then delay = 120
        if state.failures >= 3 then delay = 600
        if failure = "signin-required" or failure = "authorization-unavailable" or failure = "storage-full"
            state.pause = failure
            delay = 900
        end if
        ' Advertised quota is a fresh observation, not a confirmed max_apps
        ' response. Only the latter disables creation for this own session.
        if ticket.push and failure = "storage-full" and creationBlocked then state.creationBlocked = true
        if ticket.push and failure = "too-large"
            state.pause = failure
            state.writeBlockedRoot = ticket.intent
            state.dirtyAt = 0
            state.dueAt = 0
            return state
        end if
        state.retryAt = now + delay
        state.dueAt = state.retryAt
    else
        state.failures = 0
        if state.writeBlockedRoot <> "" then state.pause = "too-large"
    end if
    return state
end function
