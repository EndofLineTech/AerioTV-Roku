sub init()
    m.top.functionName = "loadDetails"
end sub

sub loadDetails()
    m.base = m.top.baseUrl
    m.key = m.top.apiKey
    m.clock = CreateObject("roTimespan")
    m.clock.mark()
    m.deadlineMs = 30000
    id = m.top.programId
    selected = m.top.selectedAiring
    explicit = type(selected) = "roAssociativeArray"
    result = {id: id, ok: false, explicit: explicit, message: "No indexed details for this program."}
    if CreateObject("roRegex", "^[0-9]{1,20}$", "").isMatch(id)
        raw = requestJson(m.base + "/api/epg/programs/" + id + "/")
        program = normalizeProgram(raw, m.base)
        if program <> invalid and program.id <> id then program = invalid
        if program <> invalid and explicit
            if not sameProgramDetailAiring(selected, program) then program = invalid
        end if
        if program = invalid and m.httpFailure <> invalid
            if m.httpFailure.status = 404 and explicit and m.top.cancelRequested <> true
                program = recoverSelectedProgramDetail(selected, id)
            end if
        end if
        if program <> invalid
            if programArtworkUri(m.base, program.poster) = "" and m.top.tmdbKey <> ""
                m.key = ""
                encoder = CreateObject("roUrlTransfer")
                matches = apiRows(requestJson("https://api.themoviedb.org/3/search/multi?api_key=" + encoder.escape(m.top.tmdbKey) + "&query=" + encoder.escape(program.title)))
                if matches <> invalid
                    matchCount = 0
                    matchedPath = ""
                    for each match in matches
                        if type(match) = "roAssociativeArray"
                            title = textValue(match.title)
                            if title = "" then title = textValue(match.name)
                            path = textValue(match.poster_path)
                            if lcase(title) = lcase(program.title) and (match.media_type = "movie" or match.media_type = "tv")
                                if CreateObject("roRegex", "^/[A-Za-z0-9_-]+\.(jpg|png)$", "i").isMatch(path)
                                    matchCount++
                                    matchedPath = path
                                end if
                            end if
                        end if
                    end for
                    if matchCount = 1
                        program.poster = "https://image.tmdb.org/t/p/w342" + matchedPath
                        program.artSource = "TMDB"
                    end if
                end if
            end if
            result = {id: id, ok: true, explicit: explicit, program: program}
        else
            result.message = m.failure
        end if
    end if
    m.key = ""
    m.top.apiKey = ""
    m.top.tmdbKey = ""
    if m.top.cancelRequested = true then return
    m.top.result = result
end sub

function sameProgramDetailAiring(selected as object, candidate as object) as boolean
    return selected.key <> "" and selected.key = candidate.key and selected.startsAt = candidate.startsAt and selected.endsAt = candidate.endsAt and selected.title = candidate.title
end function

' Teamarr refresh can replace the row between guide render and selection.
' One narrow grid read and at most one follow-up detail read; never scan a
' listing or remember a process-wide alias for a reused ID.
function recoverSelectedProgramDetail(selected as object, oldId as string) as dynamic
    if selected.id <> oldId or textValue(selected.key) = "" then return invalid
    if selected.startsAt < 60 or selected.endsAt <= selected.startsAt then return invalid
    start = CreateObject("roDateTime")
    finish = CreateObject("roDateTime")
    start.fromSeconds(selected.startsAt - 60)
    finish.fromSeconds(selected.startsAt + 60)
    m.maxResponseBytes = 2000000
    rows = apiRows(requestJson(httpGuideWindowUrl(m.base, start.toISOString(), finish.toISOString())))
    m.maxResponseBytes = invalid
    if rows = invalid or m.top.cancelRequested then return invalid
    candidate = invalid
    numeric = CreateObject("roRegex", "^[0-9]{1,20}$", "")
    for each row in rows
        if type(row) = "roAssociativeArray"
            if textValue(row.tvg_id) = selected.key and guideEpoch(row.start_time) = selected.startsAt
                p = normalizeProgram(row, m.base)
                if p <> invalid
                    if sameProgramDetailAiring(selected, p)
                        if candidate <> invalid or p.id = oldId or not numeric.isMatch(p.id) then return invalid
                        candidate = p
                    end if
                end if
            end if
        end if
    end for
    if candidate = invalid then return invalid
    program = normalizeProgram(requestJson(m.base + "/api/epg/programs/" + candidate.id + "/"), m.base)
    if program = invalid
        ' Fresh grid art already identified the selected airing.
        if m.httpFailure = invalid then return invalid
        if m.httpFailure.status <> 404 then return invalid
        if candidate.poster = "" then return invalid
        program = candidate
    else
        if program.id <> candidate.id or not sameProgramDetailAiring(selected, program) then return invalid
        if program.poster = "" then program.poster = candidate.poster
    end if
    program.id = oldId
    return program
end function
