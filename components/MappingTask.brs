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
    if not m.top.bypassCache then cached = metadataCacheRead(m.top.scope, "mapping", "epg-links", m.top.generation, now, true)
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
        rows = []
        ' Explicit channel assignments require their authoritative mapped tvg_id.
        ' Dispatcharr 0.31 ignores pagination here. Retain the legacy query and
        ' next-link support, but the HTTP response ceiling still bounds the list.
        if allowed.count() > 0 then rows = requestPages("/api/epg/epgdata/?page=1&page_size=500")
        if rows <> invalid
            links = {}
            for each row in rows
                if type(row) = "roAssociativeArray"
                    id = textValue(row.id)
                    if allowed.doesExist(id) then links[id] = textValue(row.tvg_id)
                end if
            end for
            rows = invalid
            metadataCacheWrite(m.top.scope, "mapping", "epg-links", m.top.generation, now, links)
        end if
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
