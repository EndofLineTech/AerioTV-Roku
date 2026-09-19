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
