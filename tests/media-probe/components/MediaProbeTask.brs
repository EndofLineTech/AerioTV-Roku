sub init()
    m.top.functionName = "discover"
end sub

sub discover()
    saved = CreateObject("roRegistrySection", "AerioTV")
    m.base = normalizeBaseUrl(saved.read("serverUrl"))
    m.key = saved.read("apiKey")
    m.timeout = 15000
    if m.top.sessionId <> ""
        response = sessionMutation(m.base + "/api/catchup/sessions/" + m.top.sessionId + "/", "DELETE")
        m.key = ""
        m.top.report = {deleted: response.status}
        return
    end if
    user = requestJson(m.base + "/api/accounts/users/me/")
    if type(user) <> "roAssociativeArray"
        m.top.report = {error: "Account unavailable"}
        return
    end if
    kind = CreateObject("roAppInfo").getValue("media_probe_kind")
    if kind = "catchup"
        rows = requestPages("/api/channels/channels/?page_size=200")
        if rows = invalid
            m.top.report = {error: "Channel facts unavailable"}
            return
        end if
        eligible = []
        for each row in rows
            if row.is_catchup = true and textValue(row.catchup_days).toInt() > 0 then eligible.push(row)
        end for
        print "[media-probe] catchup-channels="; eligible.count()
        if eligible.count() = 0
            m.top.report = {error: "No eligible catchup channels"}
            return
        end if
        channel = eligible[0]
        for each candidate in eligible
            if instr(1, lcase(textValue(candidate.name)), "espn") > 0
                channel = candidate
                exit for
            end if
        end for
        stamp = CreateObject("roDateTime")
        start = stamp.asSeconds() - 7200
        stamp.fromSeconds(start)
        response = sessionMutation(m.base + "/api/catchup/sessions/", "POST", {channel_uuid: channel.uuid, start: stamp.toISOString(), duration: 5})
        url = catchupSessionUrl(m.base, channel.uuid, response.data, CreateObject("roDateTime").asSeconds())
        print "[media-probe] session-create-status="; response.status; " valid-url="; url <> ""
        if url = ""
            m.top.report = {error: "Catchup session unavailable", status: response.status}
            return
        end if
        m.top.media = {kind: kind, url: url, apiKey: m.key, format: "mpegts", sessionId: response.data.session_id}
    else if kind = "episode"
        m.maxResponseBytes = 1048576
        seriesPage = vodPage(requestJson(m.base + "/api/vod/series/?page_size=20&name=Breaking%20Bad"), "series", m.base)
        if not seriesPage.ok or seriesPage.items.count() = 0
            m.top.report = {error: "Representative series unavailable"}
            return
        end if
        info = requestJson(m.base + "/api/vod/series/" + seriesPage.items[0].id + "/provider-info/?include_episodes=true")
        item = invalid
        if type(info) = "roAssociativeArray"
            if type(info.episodes) = "roAssociativeArray"
                for each season in info.episodes
                    if type(info.episodes[season]) = "roArray"
                        if info.episodes[season].count() > 0
                            item = vodNormalize(info.episodes[season][0], "episode")
                            exit for
                        end if
                    end if
                end for
            end if
        end if
        if item = invalid
            m.top.report = {error: "Representative episode unavailable"}
            return
        end if
        format = item.streamFormat
        if format = "unknown" then format = "mp4"
        print "[media-probe] kind=episode format="; format
        url = vodPlaybackUrl(m.base, item, "roku_probe_" + CreateObject("roDeviceInfo").getRandomUUID())
        m.top.media = {kind: kind, url: url, apiKey: m.key, format: format, sessionId: ""}
    else
        query = "?page_size=20"
        if kind = "movie" then query += "&name=The%20Matrix&year=1999"
        payload = requestJson(m.base + "/api/vod/" + vodKindPath(kind) + "/" + query)
        page = vodPage(payload, kind, m.base)
        if not page.ok or page.items.count() = 0
            m.top.report = {error: "Catalog unavailable"}
            return
        end if
        item = page.items[0]
        format = "mp4"
        if kind = "movie"
            info = requestJson(m.base + "/api/vod/movies/" + item.id + "/provider-info/")
            if type(info) = "roAssociativeArray"
                extension = lcase(textValue(info.container_extension))
                print "[media-probe] container="; extension
                if extension = "mkv" then format = "mkv"
                if extension = "ts" then format = "mpegts"
            end if
        end if
        print "[media-probe] kind="; kind; " page="; page.items.count(); " total="; page.total
        url = vodPlaybackUrl(m.base, item, "roku_probe_" + CreateObject("roDeviceInfo").getRandomUUID())
        m.top.media = {kind: kind, url: url, apiKey: m.key, format: format, sessionId: ""}
    end if
    m.key = ""
end sub
