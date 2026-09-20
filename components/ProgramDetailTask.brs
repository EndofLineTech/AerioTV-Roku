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
    result = {id: id, ok: false, message: "No indexed details for this program."}
    if CreateObject("roRegex", "^[0-9]+$", "").isMatch(id)
        raw = requestJson(m.base + "/api/epg/programs/" + id + "/")
        program = normalizeProgram(raw)
        if program <> invalid
            if program.poster = "" and m.top.tmdbKey <> ""
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
            result = {id: id, ok: true, program: program}
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
