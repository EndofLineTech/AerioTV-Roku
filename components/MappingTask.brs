sub init()
    m.top.functionName = "loadMappings"
end sub

sub loadMappings()
    m.base = m.top.baseUrl
    m.key = m.top.apiKey
    m.timeout = 30000
    if m.top.cancelRequested
        m.key = ""
        m.top.apiKey = ""
        m.top.channels = []
        return
    end if
    channels = m.top.channels
    now = CreateObject("roDateTime").asSeconds()
    cached = {state: "miss"}
    if not m.top.bypassCache then cached = metadataCacheRead(m.top.scope, "mapping", "epg-links", m.top.generation, now, requestGateAccessAllowed(m.base, m.key))
    links = invalid
    source = "network"
    if cached.state = "fresh"
        links = cached.payload
        source = "cache"
    else
        allowed = {}
        for each channel in channels
            if channel.epgId <> "" then allowed[channel.epgId] = true
        end for
        if allowed.count() = 0
            links = {}
        else if allowed.count() <= 100
            ' Small lineups avoid the unpaginated server-wide list altogether.
            ' Detail requests are bounded and use only freshly authorized IDs.
            links = requestMappedDetails(allowed)
            source = "details"
        else
            ' On larger lineups, one list is cheaper than many detail requests.
            ' Dispatcharr 0.31 ignores pagination; retain the existing byte cap.
            rows = requestPages("/api/epg/epgdata/?page=1&page_size=500")
            if rows = invalid and type(m.httpFailure) = "roAssociativeArray"
                if m.httpFailure.category = "response-too-large" and not m.top.cancelRequested
                    links = requestMappedDetails(allowed)
                    source = "details"
                end if
            end if
            if rows <> invalid
                links = {}
                for each row in rows
                    if type(row) = "roAssociativeArray"
                        id = textValue(row.id)
                        if allowed.doesExist(id) then links[id] = textValue(row.tvg_id)
                    end if
                end for
                rows = invalid
            end if
        end if
        if links <> invalid then metadataCacheWrite(m.top.scope, "mapping", "epg-links", m.top.generation, now, links)
    end if
    m.key = ""
    m.top.apiKey = ""
    m.top.channels = []
    if m.top.cancelRequested then return
    if links = invalid
        failure = {ok: false, source: source, message: m.failure}
        if type(m.httpFailure) = "roAssociativeArray"
            failure.category = textValue(m.httpFailure.category)
            failure.sizeBucket = textValue(m.httpFailure.sizeBucket)
        end if
        m.top.result = failure
    else
        m.top.result = {ok: true, links: links, source: source}
    end if
end sub
