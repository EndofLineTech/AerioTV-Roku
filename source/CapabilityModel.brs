function compatibleAacProfile(rows as dynamic) as dynamic
    if type(rows) <> "roArray" then return invalid
    for each row in rows
        if type(row) = "roAssociativeArray"
            id = textValue(row.id)
            command = textValue(row.command)
            parameters = textValue(row.parameters)
            active = false
            if type(row.is_active) = "Boolean" or type(row.is_active) = "roBoolean" then active = row.is_active
            if active and CreateObject("roRegex", "^[1-9][0-9]*$", "").isMatch(id)
                if CreateObject("roRegex", "(^|/)ffmpeg$", "i").isMatch(command)
                    audio = CreateObject("roRegex", "(^|\s)-(c:a|acodec)\s+aac(\s|$)", "i").isMatch(parameters)
                    video = CreateObject("roRegex", "(^|\s)-(c:v|vcodec)\s+copy(\s|$)", "i").isMatch(parameters)
                    if audio and video then return {id: id, name: sanitizePlaybackDiagnostic(textValue(row.name))}
                end if
            end if
        end if
    end for
    return invalid
end function

function permissionFlag(raw as dynamic, permitted as boolean) as string
    if not permitted then return "denied"
    if raw = invalid then return "allowed"
    if type(raw) <> "Boolean" and type(raw) <> "roBoolean" then return "unknown"
    if raw then return "allowed"
    return "denied"
end function

function normalizeCapabilities(user as dynamic, version as dynamic, settings as dynamic, fetchedAt as integer) as object
    result = {accountId: "", level: -1, switchStreams: "unknown", movies: "unknown", series: "unknown", catchup: "unknown", dvr: "unknown", version: "", fetchedAt: fetchedAt}
    if type(version) = "roAssociativeArray" then result.version = textValue(version.version)
    if type(user) <> "roAssociativeArray" then return result
    result.accountId = textValue(user.id)
    level = textValue(user.user_level)
    if not CreateObject("roRegex", "^[0-9]+$", "").isMatch(level) then return result
    result.level = level.toInt()
    props = user.custom_properties
    if type(props) <> "roAssociativeArray" then props = {}
    ' Dispatcharr 0.31 IsAdmin checks user_level >= 10, not is_staff alone.
    result.switchStreams = "denied"
    if result.level >= 10 then result.switchStreams = "allowed"
    standard = result.level >= 1
    result.movies = permissionFlag(props.vod_movies_enabled, standard)
    result.series = permissionFlag(props.vod_series_enabled, standard)
    result.catchup = permissionFlag(props.catchup_enabled, standard)
    result.dvr = "none"
    if result.level >= 10
        result.dvr = "manage"
    else if standard
        result.dvr = "view"
        dvr = textValue(props.dvr_access)
        if dvr = "none" or dvr = "manage" or dvr = "view" then result.dvr = dvr
    end if
    rows = apiRows(settings)
    systemKnown = false
    if rows <> invalid
        for each row in rows
            if type(row) = "roAssociativeArray"
                if textValue(row.key) = "system_settings" and type(row.value) = "roAssociativeArray"
                    systemKnown = true
                    policy = permissionFlag(row.value.catchup_enabled, true)
                    if policy = "denied" then result.catchup = "denied"
                    if policy = "unknown" and result.catchup = "allowed" then result.catchup = "unknown"
                end if
            end if
        end for
    end if
    if not systemKnown and result.catchup = "allowed" then result.catchup = "unknown"
    return result
end function

function normalizeChannelCapabilities(rows as dynamic) as object
    result = {}
    if type(rows) <> "roArray" then return result
    for each row in rows
        if type(row) = "roAssociativeArray"
            id = textValue(row.id)
            days = textValue(row.catchup_days).toInt()
            if days < 0 then days = 0
            if days > 30 then days = 30
            catchup = false
            if type(row.is_catchup) = "Boolean" or type(row.is_catchup) = "roBoolean" then catchup = row.is_catchup
            if not catchup then days = 0
            if id <> "" then result[id] = {catchupDays: days}
        end if
    end for
    return result
end function

function sourceClientSnapshot(status as dynamic) as dynamic
    if type(status) <> "roAssociativeArray" then return invalid
    if type(status.clients) <> "roArray" then return invalid
    count = textValue(status.client_count)
    if not CreateObject("roRegex", "^[0-9]+$", "").isMatch(count) then return invalid
    clients = {}
    clients.setModeCaseSensitive()
    for each client in status.clients
        if type(client) <> "roAssociativeArray" then return invalid
        id = textValue(client.client_id)
        if id = "" then return invalid
        clients[id] = true
    end for
    ' A truncated, duplicate or malformed list cannot establish continuity.
    if clients.count() <> count.toInt() then return invalid
    return clients
end function

function sourceClientContinuity(before as dynamic, after as dynamic) as object
    result = {state: "unknown", beforeCount: -1, afterCount: -1, missingCount: -1}
    original = sourceClientSnapshot(before)
    current = sourceClientSnapshot(after)
    if original = invalid or current = invalid then return result
    result.beforeCount = original.count()
    result.afterCount = current.count()
    if original.count() = 0 then return result
    result.missingCount = 0
    for each id in original
        if not current.doesExist(id) then result.missingCount++
    end for
    result.state = "preserved"
    if result.missingCount > 0 then result.state = "changed"
    ' Only counts/state leave this function. Do not expose client IPs or IDs.
    return result
end function

function normalizeStreamChoices(rows as dynamic, status as dynamic) as object
    result = []
    if type(rows) <> "roArray" then return result
    activeId = ""
    activeUrl = ""
    if type(status) = "roAssociativeArray"
        activeId = textValue(status.stream_id)
        activeUrl = textValue(status.url)
    end if
    for each row in rows
        if type(row) = "roAssociativeArray"
            id = textValue(row.id)
            if CreateObject("roRegex", "^[0-9]+$", "").isMatch(id)
                title = textValue(row.name)
                if title = "" then title = "Stream " + id
                title = sanitizePlaybackDiagnostic(title)
                exact = activeUrl <> "" and textValue(row.url) = activeUrl
                reported = id = activeId
                prefix = ""
                if reported then prefix = "[Reported active] "
                if exact then prefix = "[Active] "
                result.push({id: id, title: prefix + title, active: exact, reported: reported})
            end if
        end if
    end for
    return result
end function
