' All guide times are UTC epoch seconds. Local time is a presentation concern.
function guideDictionary() as object
    result = {}
    result.setModeCaseSensitive()
    return result
end function

function guideEpoch(value as dynamic) as dynamic
    if value = invalid then return invalid
    if GetInterface(value, "ifString") = invalid
        if GetInterface(value, "ifInt") <> invalid then return value
        if GetInterface(value, "ifFloat") <> invalid then return int(value)
        return invalid
    end if
    pattern = CreateObject("roRegex", "^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(\.\d+)?(Z|[+-]\d{2}:\d{2})$", "")
    parts = pattern.match(value)
    if parts.count() = 0 then return invalid
    date = CreateObject("roDateTime")
    date.fromISO8601String(parts[1] + "Z")
    if left(date.toISOString(), 19) <> parts[1] then return invalid
    seconds = date.asSeconds()
    zone = parts[3]
    if zone <> "Z"
        hours = val(mid(zone, 2, 2))
        minutes = val(right(zone, 2))
        if hours > 23 or minutes > 59 then return invalid
        offset = hours * 3600 + minutes * 60
        if left(zone, 1) = "+" then seconds -= offset else seconds += offset
    end if
    return seconds
end function

function normalizeProgram(raw as dynamic) as dynamic
    if type(raw) <> "roAssociativeArray" then return invalid
    startsAt = guideEpoch(raw.start_time)
    endsAt = guideEpoch(raw.end_time)
    if startsAt = invalid or endsAt = invalid then return invalid
    if endsAt <= startsAt then return invalid
    title = textValue(raw.title)
    if title = "" then title = "Untitled program"
    return {
        id: textValue(raw.id), title: left(title, 256)
        description: left(textValue(raw.description), 1500)
        subtitle: left(textValue(raw.sub_title), 256)
        startsAt: startsAt, endsAt: endsAt, key: textValue(raw.tvg_id)
    }
end function

function guideClamp(value as integer, now as integer) as integer
    if value < now - 259200 then return now - 259200
    if value >= now + 604800 then return now + 604799
    return value
end function

function guideWindowStart(value as integer) as integer
    ' Integer division avoids float32 rounding at modern epoch magnitudes on Roku.
    return (value \ 10800) * 10800
end function

function guideNavigate(anchor as integer, cell as dynamic, direction as integer, now as integer) as integer
    if cell = invalid then return guideClamp(anchor, now)
    if direction < 0 then return guideClamp(cell.startsAt - 1, now)
    return guideClamp(cell.endsAt, now)
end function

function guideChannelKey(channel as object, index as object) as string
    if index.doesExist(channel.uuid) then return channel.uuid
    return channel.epgKey
end function

' Produce complete, disjoint focus regions. Gaps have no invented program data.
function guideCells(programs as object, startsAt as integer, endsAt as integer) as object
    sorted = []
    sorted.append(programs)
    sorted.sortBy("startsAt")
    cells = []
    cursor = startsAt
    for each program in sorted
        if program.endsAt > cursor and program.startsAt < endsAt
            start = program.startsAt
            if start < cursor then start = cursor
            finish = program.endsAt
            if finish > endsAt then finish = endsAt
            if start > cursor then cells.push({startsAt: cursor, endsAt: start, program: invalid})
            cells.push({startsAt: start, endsAt: finish, program: program})
            cursor = finish
        end if
    end for
    if cursor < endsAt then cells.push({startsAt: cursor, endsAt: endsAt, program: invalid})
    return cells
end function

function guideCellAt(cells as object, anchor as integer) as dynamic
    for each cell in cells
        if cell.startsAt <= anchor and cell.endsAt > anchor then return cell
    end for
    return invalid
end function

function guideNewCache() as object
    return {entries: {}, order: [], limit: 3}
end function

sub guideCacheTouch(cache as object, start as integer)
    key = start.toStr()
    order = []
    for each old in cache.order
        if old <> key then order.push(old)
    end for
    order.push(key)
    cache.order = order
end sub

sub guideCachePut(cache as object, start as integer, index as object, now as integer, ttl = 300 as integer)
    key = start.toStr()
    cache.entries[key] = {index: index, expiresAt: now + ttl}
    guideCacheTouch(cache, start)
    while cache.order.count() > cache.limit
        oldest = cache.order.shift()
        cache.entries.delete(oldest)
    end while
end sub

function guideCacheHas(cache as object, start as integer, now as integer) as boolean
    key = start.toStr()
    if not cache.entries.doesExist(key) then return false
    return cache.entries[key].expiresAt > now
end function

function guideCachePrograms(cache as object, key as string, startsAt as integer, endsAt as integer) as object
    result = []
    seen = guideDictionary()
    for each window in cache.entries
        index = cache.entries[window].index
        if index.doesExist(key)
            for each program in index[key]
                if program.endsAt > startsAt and program.startsAt < endsAt
                    identity = program.id + ":" + program.startsAt.toStr() + ":" + program.endsAt.toStr()
                    if not seen.doesExist(identity)
                        result.push(program)
                        seen[identity] = true
                    end if
                end if
            end for
        end if
    end for
    return result
end function
