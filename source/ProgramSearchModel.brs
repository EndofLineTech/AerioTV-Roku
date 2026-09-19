function programSearchParameters(query as string, field as string, page as integer, now as integer) as dynamic
    query = left(query.trim(), 120)
    if len(query) < 2 or page < 1 then return invalid
    if field <> "title" and field <> "description" then return invalid
    lowerBound = CreateObject("roDateTime")
    lowerBound.fromSeconds(now - 259200)
    upperBound = CreateObject("roDateTime")
    upperBound.fromSeconds(now + 604800)
    return {query: query, field: field, page: page, pageSize: 50, endAfter: lowerBound.toISOString(), startBefore: upperBound.toISOString()}
end function

function programSearchResults(rows as dynamic, channels as object, now as integer, limit = 200 as integer) as object
    result = {items: [], truncated: false}
    if type(rows) <> "roArray" then return result
    allowed = {}
    for each channel in channels
        allowed[channel.id] = channel
    end for
    seen = guideDictionary()
    for each row in rows
        program = normalizeProgram(row)
        if program <> invalid
            if program.endsAt > now - 259200 and program.startsAt < now + 604800 and type(row.channels) = "roArray"
                for each reference in row.channels
                    if type(reference) = "roAssociativeArray"
                        id = textValue(reference.id)
                        if allowed.doesExist(id)
                            channel = allowed[id]
                            ' Search serializer links base assignments; the effective guide
                            ' mapping and connected-account lineup remain authoritative.
                            if program.key <> "" and (channel.epgKey = program.key or channel.uuid = program.key)
                                key = FormatJson([channel.uuid, program.id, program.startsAt, program.endsAt, program.title])
                                if not seen.doesExist(key)
                                    if result.items.count() >= limit
                                        result.truncated = true
                                        return result
                                    end if
                                    seen[key] = true
                                    result.items.push({channel: channel, program: program, startsAt: program.startsAt})
                                end if
                            end if
                        end if
                    end if
                end for
            end if
        end if
    end for
    result.items.sortBy("startsAt")
    return result
end function

function programSearchState(program as object, now as integer) as string
    if program.endsAt <= now then return "Past"
    if program.startsAt > now then return "Upcoming"
    return "Now"
end function
