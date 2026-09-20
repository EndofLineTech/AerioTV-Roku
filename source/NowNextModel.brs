' Pure schedule selection. These times describe the broadcast schedule, never
' the player's position or a retained rewind buffer.
function selectNowNext(programs as object, now as integer) as object
    sorted = []
    sorted.append(programs)
    sorted.sortBy("startsAt")
    result = {current: invalid, next: invalid, nextStartsAt: 0}
    cursor = now
    for each program in sorted
        if program.endsAt > program.startsAt and program.endsAt > cursor
            if result.current = invalid and program.startsAt <= now
                result.current = program
                cursor = program.endsAt
            else
                result.next = program
                result.nextStartsAt = program.startsAt
                if result.nextStartsAt < cursor then result.nextStartsAt = cursor
                exit for
            end if
        end if
    end for
    return result
end function

function scheduleProgress(program as dynamic, now as integer) as float
    if program = invalid then return 0.0
    duration = program.endsAt - program.startsAt
    if duration <= 0 then return 0.0
    if now <= program.startsAt then return 0.0
    if now >= program.endsAt then return 1.0
    return (now - program.startsAt) / duration
end function

function playbackWindowStarts(now as integer, programs as object) as object
    first = guideWindowStart(now)
    result = [first, first + 10800]
    info = selectNowNext(programs, now)
    if info.current <> invalid
        boundary = guideWindowStart(info.current.endsAt)
        if boundary >= first + 21600 and boundary <= guideWindowStart(now + 604799)
            result.push(boundary)
        end if
    end if
    return result
end function

function playbackSnapshot(cache as object, failures as object, channel as object, now as integer, cacheNow = invalid as dynamic) as object
    if cacheNow = invalid then cacheNow = now
    key = channel.epgKey
    for each window in cache.entries
        if cache.entries[window].index.doesExist(channel.uuid) then key = channel.uuid
    end for
    allPrograms = guideCachePrograms(cache, key, now, now + 604800)
    windows = playbackWindowStarts(now, allPrograms)
    relevant = {entries: {}}
    missing = false
    stale = false
    failed = false
    for each start in windows
        id = start.toStr()
        if failures.doesExist(id) then failed = true
        if cache.entries.doesExist(id)
            relevant.entries[id] = cache.entries[id]
            if not guideCacheHas(cache, start, cacheNow) then stale = true
        else
            missing = true
        end if
    end for
    status = "ready"
    if stale then status = "stale"
    if missing then status = "loading"
    if failed then status = "unavailable"
    return {
        channelUuid: channel.uuid, status: status, windows: windows
        programs: guideCachePrograms(relevant, key, now, now + 604800)
    }
end function
