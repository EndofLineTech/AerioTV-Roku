function normalizeReminders(raw as dynamic) as object
    result = []
    seen = {}
    if type(raw) <> "roArray" then return result
    for each entry in raw
        if type(entry) = "roAssociativeArray"
            id = textValue(entry.id)
            start = guideEpoch(entry.startsAt)
            finish = guideEpoch(entry.endsAt)
            if id <> "" and start <> invalid and finish <> invalid
                if finish > start and not seen.doesExist(id) and result.count() < 50
                    notified = false
                    if type(entry.notified) = "Boolean" or type(entry.notified) = "roBoolean" then notified = entry.notified
                    unavailable = false
                    if type(entry.unavailable) = "Boolean" or type(entry.unavailable) = "roBoolean" then unavailable = entry.unavailable
                    result.push({id: left(id, 180), channelUuid: left(textValue(entry.channelUuid), 128), title: left(textValue(entry.title), 180), startsAt: start, endsAt: finish, notified: notified, unavailable: unavailable})
                    seen[id] = true
                end if
            end if
        end if
    end for
    return result
end function

function reminderTick(raw as object, now as integer) as object
    result = {items: [], alerts: []}
    for each entry in normalizeReminders(raw)
        if entry.endsAt > now
            if not entry.notified and not entry.unavailable and entry.startsAt <= now + 300
                entry.notified = true
                result.alerts.push(entry)
            end if
            result.items.push(entry)
        end if
    end for
    return result
end function

function hasReminder(reminders as object, channelUuid as string, programId as string) as boolean
    for each entry in reminders
        if entry.id = channelUuid + "|" + programId then return true
    end for
    return false
end function
