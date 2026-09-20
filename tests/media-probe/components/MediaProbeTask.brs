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
    if m.top.operation <> "" then kind = m.top.operation
    m.probeHttp = right(kind, 5) = "-http"
    m.probeMeta = right(kind, 5) = "-meta"
    if m.probeHttp or m.probeMeta then kind = left(kind, len(kind) - 5)
    if kind = "logs"
        wait(3000, CreateObject("roMessagePort"))
        inspectMediaLogs()
        m.key = ""
        return
    end if
    if kind = "series-audit"
        auditSeriesEpisodes()
        m.key = ""
        return
    end if
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
        media = {kind: kind, url: url, apiKey: m.key, format: "mpegts", sessionId: response.data.session_id}
    else if kind = "episode"
        m.maxResponseBytes = 1048576
        seriesPage = vodPage(requestJson(m.base + "/api/vod/series/?page_size=20&name=Breaking%20Bad"), "series", m.base)
        if not seriesPage.ok or seriesPage.items.count() = 0
            m.top.report = {error: "Representative series unavailable"}
            return
        end if
        print "[media-probe] matching-series="; seriesPage.total
        info = requestJson(m.base + "/api/vod/series/" + seriesPage.items[0].id + "/provider-info/?include_episodes=true")
        originalEpisodeId = ""
        if type(info) = "roAssociativeArray"
            if type(info.episodes) = "roAssociativeArray"
                if type(info.episodes["3"]) = "roArray"
                    for each episode in info.episodes["3"]
                        if textValue(episode.episode_number) = "1" then originalEpisodeId = textValue(episode.id)
                    end for
                end if
            end if
        end if
        m.maxResponseBytes = 8388608
        rawVariants = requestJson(m.base + "/api/vod/series/" + seriesPage.items[0].id + "/providers/")
        m.maxResponseBytes = 1048576
        variants = apiRows(rawVariants)
        if variants = invalid
            if type(rawVariants) = "roAssociativeArray" then print "[media-probe] variant-keys="; FormatJson(rawVariants.keys())
            if type(m.httpFailure) = "roAssociativeArray" then print "[media-probe] variant-failure="; m.httpFailure.category; " status="; m.httpFailure.status
        end if
        if variants <> invalid
            print "[media-probe] series-variants="; variants.count()
            for each variant in variants
                if type(variant.m3u_account) = "roAssociativeArray"
                    if textValue(variant.m3u_account.id) = CreateObject("roAppInfo").getValue("media_probe_provider")
                        m.maxResponseBytes = 8388608
                        info = requestJson(m.base + "/api/vod/series/" + seriesPage.items[0].id + "/provider-info/?include_episodes=true&relation_id=" + textValue(variant.id))
                        if info = invalid and type(m.httpFailure) = "roAssociativeArray" then print "[media-probe] alternate-info-failure="; m.httpFailure.category; " status="; m.httpFailure.status
                        exit for
                    end if
                end if
            end for
        end if
        item = invalid
        if type(info) = "roAssociativeArray"
            print "[media-probe] episodes-fetched="; info.episodes_fetched; " selected-provider="; info.m3u_account.id
            if type(info.episodes) = "roAssociativeArray"
                print "[media-probe] seasons="; FormatJson(info.episodes.keys())
                if type(info.episodes["3"]) = "roArray"
                    for each episode in info.episodes["3"]
                        if textValue(episode.episode_number) = "1" then item = vodNormalize(episode, "episode")
                    end for
                    end if
            end if
        end if
        if item = invalid
            m.top.report = {error: "Representative episode unavailable"}
            return
        end if
        format = item.streamFormat
        print "[media-probe] same-episode-id="; originalEpisodeId = item.id
        if type(info.m3u_account) = "roAssociativeArray"
            item.providerId = textValue(info.m3u_account.id)
            item.explicitProvider = true
            account = invalid
            accounts = apiRows(requestJson(m.base + "/api/m3u/accounts/"))
            if accounts <> invalid
                for each candidate in accounts
                    if textValue(candidate.id) = item.providerId then account = candidate
                end for
            end if
            if type(account) = "roAssociativeArray"
                print "[media-probe] provider-keys="; FormatJson(account.keys())
                print "[media-probe] provider-type="; textValue(account.account_type); " url-shape="; mediaUrlShape(textValue(account.server_url))
                print "[media-probe] provider-is-self="; urlOrigin(textValue(account.server_url)) = urlOrigin(m.base)
                print "[media-probe] provider-status="; textValue(account.status); " active="; account.is_active; " vod="; account.enable_vod
                if type(account.custom_properties) = "roAssociativeArray" then print "[media-probe] provider-property-keys="; FormatJson(account.custom_properties.keys())
            end if
        end if
        if format = "unknown" then format = "mp4"
        print "[media-probe] kind=episode format="; format; " season="; item.season; " episode="; item.episode; " provider="; item.providerId
        url = vodPlaybackUrl(m.base, item, "roku_probe_" + CreateObject("roDeviceInfo").getRandomUUID())
        media = {kind: kind, url: url, apiKey: m.key, format: format, sessionId: ""}
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
        media = {kind: kind, url: url, apiKey: m.key, format: format, sessionId: ""}
    end if
    if m.probeMeta
        m.top.report = {metadataOnly: true}
    else if m.probeHttp
        inspectMediaResponse(media)
    else
        m.top.media = media
    end if
    m.key = ""
end sub

sub auditSeriesEpisodes()
    m.maxResponseBytes = 1048576
    matches = vodPage(requestJson(m.base + "/api/vod/series/?page_size=20&name=Deep%20Space"), "series", m.base)
    if not matches.ok or matches.items.count() = 0
        m.top.report = {error: "DS9 catalog match unavailable"}
        return
    end if
    print "[media-probe] ds9-matches="; matches.total
    for each candidate in matches.items
        print "[media-probe] ds9-title="; candidate.title; " id="; candidate.id; " tmdb="; candidate.tmdbId
    end for
    item = invalid
    for each candidate in matches.items
        if candidate.tmdbId = "580" then item = candidate
    end for
    if item = invalid
        m.top.report = {error: "Exact Deep Space Nine series not found"}
        return
    end if
    url = m.base + "/api/vod/episodes/?page_size=20&page=1&ordering=season_number,episode_number&series=" + item.id
    before = vodPage(requestJson(url), "episode", m.base)
    print "[media-probe] ds9-before ok="; before.ok; " total="; before.total; " rows="; before.items.count()
    info = requestJson(m.base + "/api/vod/series/" + item.id + "/provider-info/?include_episodes=false")
    if type(info) = "roAssociativeArray"
        print "[media-probe] ds9-default fetched="; info.episodes_fetched; " detailed="; info.detailed_fetched
        if type(info.m3u_account) = "roAssociativeArray" then print "[media-probe] ds9-default provider="; info.m3u_account.id
    else if type(m.httpFailure) = "roAssociativeArray"
        print "[media-probe] ds9-default failure="; m.httpFailure.category; " status="; m.httpFailure.status
    end if
    after = vodPage(requestJson(url), "episode", m.base)
    print "[media-probe] ds9-after ok="; after.ok; " total="; after.total; " rows="; after.items.count()
    m.clock = CreateObject("roTimespan")
    m.clock.mark()
    m.deadlineMs = 30000
    repaired = vodHydrateEpisodes(item.id, url, "")
    if not repaired.ok then print "[media-probe] ds9-attempts="; repaired.attempts; " provider-list="; repaired.providerListAvailable
    m.top.report = {audit: true, before: before.total, afterDefault: after.total, hydrated: repaired.ok, total: repaired.total, loaded: repaired.items.count(), elapsedMs: m.clock.totalMilliseconds()}
end sub

sub inspectMediaResponse(media as object)
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    fs = CreateObject("roFileSystem")
    file = "tmp:/media-diagnostic-response"
    transfer.setMessagePort(port)
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.setUrl(media.url)
    transfer.setHeaders({"X-API-Key": m.key, "Range": "bytes=0-1023"})
    transfer.retainBodyOnError(true)
    clock = CreateObject("roTimespan")
    clock.mark()
    report = {status: 0}
    body = ""
    memory = CreateObject("roAppMemoryMonitor")
    if transfer.asyncGetToString()
        while clock.totalSeconds() < 20
            event = wait(50, port)
            if type(event) = "roUrlEvent"
                report.status = event.getResponseCode()
                body = event.getString()
                exit while
            end if
            if memory.getMemoryLimitPercent() > 25 then exit while
        end while
    end if
    transfer.asyncCancel()
    if report.status >= 400
        matches = CreateObject("roRegex", ".*?(https?://[^\s]+)", "i").match(body)
        if matches.count() > 1 then report.targetShape = mediaUrlShape(matches[1])
        report.failure = sanitizePlaybackDiagnostic(left(body, 2000), m.key)
    else
        bytes = CreateObject("roByteArray")
        bytes.fromAsciiString(left(body, 4))
        report.magic = bytes.toHexString()
    end if
    fs.delete(file)
    if media.sessionId <> "" then sessionMutation(m.base + "/api/catchup/sessions/" + media.sessionId + "/", "DELETE")
    m.top.report = report
end sub

function mediaUrlShape(url as string) as string
    origin = urlOrigin(url)
    if origin = "" then return "unknown"
    path = mid(url, len(origin) + 1)
    query = instr(1, path, "?")
    if query > 0 then path = left(path, query - 1)
    shape = "[origin]"
    for each part in path.tokenize("/")
        if part <> ""
            value = "[segment]"
            for each known in ["api", "player_api.php", "get.php", "proxy", "vod", "movie", "movies", "series", "episode", "live", "timeshift", "stream"]
                if lcase(part) = known then value = known
            end for
            if CreateObject("roRegex", "[.](mkv|mp4|ts)$", "i").isMatch(part) then value = "[media]." + part.tokenize(".").peek()
            shape += "/" + value
        end if
    end for
    return shape
end function

sub inspectMediaLogs()
    listing = requestJson(m.base + "/api/core/logs/")
    if type(listing) <> "roAssociativeArray"
        m.top.report = {error: "Log listing unavailable"}
        return
    end if
    if type(listing.files) <> "roArray"
        m.top.report = {error: "Log listing has no file array"}
        return
    end if
    print "[media-probe] log-files="; listing.files.count(); " collector="; listing.collector_running
    m.maxResponseBytes = 33554432 ' isolated diagnostics, server tail cap is24MiB
    encoder = CreateObject("roUrlTransfer")
    readCount = 0
    hits = 0
    for each file in listing.files
        if readCount >= 2 then exit for
        name = textValue(file.name)
        print "[media-probe] log="; name; " bytes="; file.size
        payload = requestJson(m.base + "/api/core/logs/" + encoder.escape(name) + "/")
        readCount++
        if type(payload) = "roAssociativeArray"
            print "[media-probe] log-text-bytes="; len(textValue(payload.content)); " keys="; FormatJson(payload.keys())
            lines = textValue(payload.content).tokenize(chr(10))
            payload = invalid
            for each line in lines
                lower = lcase(line)
                relevant = instr(1, lower, "apps.proxy.vod_proxy") > 0 and (instr(1, line, " ERROR ") > 0 or instr(1, line, " WARNING ") > 0)
                if relevant
                    safe = sanitizePlaybackDiagnostic(line, m.key)
                    safe = CreateObject("roRegex", "host=['" + chr(34) + "][^'" + chr(34) + "]+", "i").replaceAll(safe, "host=[redacted]")
                    safe = CreateObject("roRegex", "[A-Za-z0-9_-]{24,}", "").replaceAll(safe, "[identifier]")
                    print "[media-probe-log] "; safe
                    hits++
                    if hits >= 20 then exit for
                end if
            end for
            lines = invalid
        else
            print "[media-probe] log-read unavailable"
        end if
        if hits >= 20 then exit for
    end for
    m.top.report = {filesRead: readCount, errorsFound: hits}
end sub
