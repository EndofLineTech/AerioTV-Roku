' Shared import ordering and bounded credential-attempt policy. No IO.
function phoneSetupProfileSyncOffer(incoming as dynamic, choice as object) as boolean
    if type(incoming) <> "roAssociativeArray" then return false
    return incoming.provider = "dispatcharr" and incoming.enabled = true and choice.enabled <> true and choice.declined <> true
end function

function phoneSetupProfileNextAttempt(attempt as string, hasPassword as boolean, result as dynamic) as string
    if type(result) <> "roAssociativeArray" then return "skip"
    if result.ok = true then return "accept"
    if result.rateLimited = true or result.requestGateReason = "parked" then return "stop"
    if attempt = "key" and hasPassword
        if result.relogin = true or result.identityChanged = true or result.requestGateReason = "rejected-key" then return "password"
    end if
    return "skip"
end function

function phoneSetupProfileQueue(rows as object) as object
    denied = {ok: false}
    if type(rows) <> "roArray" then return denied
    defaultRow = invalid
    queue = []
    for each row in rows
        if type(row) <> "roAssociativeArray" then return denied
        if row.isDefault = true
            if defaultRow <> invalid then return denied
            defaultRow = row
        else
            group = 1
            if row.role = "child" then group = 2
            rank = 2147483647
            if userProfileInteger(row.order)
                if row.order >= 0 then rank = row.order
            end if
            item = {row: row, group: group, rank: rank}
            position = queue.count()
            for i = 0 to queue.count() - 1
                if group < queue[i].group or (group = queue[i].group and rank < queue[i].rank) then position = i : exit for
            end for
            queue.push(item)
            for i = queue.count() - 1 to position + 1 step -1
                queue[i] = queue[i - 1]
            end for
            queue[position] = item
        end if
    end for
    return {ok: true, defaultRow: defaultRow, queue: queue}
end function
