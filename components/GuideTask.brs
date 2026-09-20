sub init()
    m.top.functionName = "loadWindow"
end sub

sub loadWindow()
    m.base = m.top.baseUrl
    m.key = m.top.apiKey
    m.timeout = 45000
    windowStart = m.top.windowStart
    allowedKeys = m.top.allowedKeys
    now = CreateObject("roDateTime").asSeconds()
    cached = {state: "miss"}
    if not m.top.bypassCache then cached = metadataCacheRead(m.top.scope, "guide", windowStart.toStr(), m.top.generation, now, true)
    if m.top.cancelRequested
        m.key = ""
        m.top.apiKey = ""
        return
    end if
    if cached.state <> "miss"
        restored = {ok: true, windowStart: windowStart, index: cached.payload, fetched: cached.fetched, source: "cache"}
        if cached.state = "fresh"
            m.key = ""
            m.top.apiKey = ""
            m.top.result = restored
            return
        end if
        m.top.cached = restored
    end if
    start = CreateObject("roDateTime")
    finish = CreateObject("roDateTime")
    start.fromSeconds(windowStart)
    finish.fromSeconds(windowStart + 10800)
    url = httpGuideWindowUrl(m.base, start.toISOString(), finish.toISOString())
    payload = requestJson(url)
    rows = apiRows(payload)
    result = {ok: false, windowStart: windowStart, message: m.failure}
    if rows = invalid
        if result.message = "" then result.message = "Unexpected guide response."
    else
        index = guideDictionary()
        count = 0
        for each row in rows
            program = normalizeProgram(row)
            if program <> invalid
                if allowedKeys.doesExist(program.key)
                    if program.endsAt > windowStart and program.startsAt < windowStart + 10800
                        if not index.doesExist(program.key) then index[program.key] = []
                        index[program.key].push(program)
                        count++
                        if count > 24000 then exit for
                    end if
                end if
            end if
        end for
        if count > 24000
            result.message = "Guide window exceeds the 24,000-program limit."
        else
            for each key in index
                index[key].sortBy("startsAt")
            end for
            now = CreateObject("roDateTime").asSeconds()
            metadataCacheWrite(m.top.scope, "guide", windowStart.toStr(), m.top.generation, now, metadataCacheGuidePayload(index))
            result = {ok: true, windowStart: windowStart, index: index, fetched: now, source: "network"}
        end if
    end if
    m.key = ""
    m.top.apiKey = ""
    if m.top.cancelRequested = true then return
    m.top.result = result
end sub
