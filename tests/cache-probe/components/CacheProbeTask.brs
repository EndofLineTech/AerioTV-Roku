sub init()
    m.top.functionName = "measure"
end sub

function memorySample(stage as string) as object
    value = {stage: stage, percent: m.memory.getMemoryLimitPercent(), availableKB: m.memory.getChannelAvailableMemory()}
    print "[cache-probe-memory] "; FormatJson(value)
    return value
end function

sub measure()
    m.fs = CreateObject("roFileSystem")
    m.memory = CreateObject("roAppMemoryMonitor")
    m.clock = CreateObject("roTimespan")
    m.clock.mark()
    m.deadlineMs = 180000
    m.timeout = 15000
    m.report = {phase: CreateObject("roAppInfo").getValue("cache_probe_phase"), limitsRaw: m.memory.getChannelMemoryLimit(), volumes: [], requests: []}
    for each volume in m.fs.getVolumeList()
        m.report.volumes.push(volume)
    end for
    registry = CreateObject("roRegistry")
    m.report.registryFreeBefore = registry.getSpaceAvailable()
    marker = CreateObject("roRegistrySection", "AerioTVStorageProbe")
    m.report.registryMarkerPresent = marker.read("sentinel") = "cache-probe-v1"
    m.report.tmpMarkerPresent = false
    m.report.cacheMarkerPresent = false
    if m.fs.exists("tmp:/aeriotv-mxz1-probe/sentinel") then m.report.tmpMarkerPresent = ReadAsciiFile("tmp:/aeriotv-mxz1-probe/sentinel") = "cache-probe-v1"
    if m.fs.exists("cachefs:/aeriotv-mxz1-probe/sentinel") then m.report.cacheMarkerPresent = ReadAsciiFile("cachefs:/aeriotv-mxz1-probe/sentinel") = "cache-probe-v1"
    memorySample("start")
    if m.report.phase = "http"
        probeHttpPolicy()
        m.top.report = m.report
        return
    end if
    if m.report.phase = "verify"
        m.report.tmpCleanup = m.fs.delete("tmp:/aeriotv-mxz1-probe")
        m.report.cacheCleanup = m.fs.delete("cachefs:/aeriotv-mxz1-probe")
        m.report.registryCleanup = registry.delete("AerioTVStorageProbe")
        registry.flush()
        m.report.registryFreeAfter = registry.getSpaceAvailable()
        m.top.report = m.report
        return
    end if
    if m.report.registryFreeBefore > 2048
        m.report.registryWrite = marker.write("sentinel", "cache-probe-v1") and marker.flush()
    end if
    m.report.storage = []
    for each volume in ["tmp:/", "cachefs:/"]
        dir = volume + "aeriotv-mxz1-probe"
        ready = m.fs.exists(dir)
        if not ready then ready = m.fs.createDirectory(dir)
        item = {volume: volume, ready: ready, writtenBytes: 0}
        if ready
            item.markerWrite = WriteAsciiFile(dir + "/sentinel", "cache-probe-v1")
            bytes = CreateObject("roByteArray")
            block = "xxxxxxxxxxxxxxxx"
            for expand = 1 to 16
                block = block + block
            end for
            bytes.fromAsciiString(block)
            block = invalid
            item.blockBytes = bytes.count()
            if item.blockBytes <> 1048576
                m.report.fixtureError = "Storage test block was not 1 MiB."
                m.top.report = m.report
                return
            end if
            timer = CreateObject("roTimespan")
            timer.mark()
            for i = 0 to 7
                if m.memory.getMemoryLimitPercent() >= 65 then exit for
                if m.memory.getChannelAvailableMemory() < 49152 then exit for
                file = dir + "/block-" + i.toStr()
                if not bytes.writeFile(file) then exit for
                stat = m.fs.stat(file)
                if type(stat) = "roAssociativeArray" and stat.size <> invalid then item.writtenBytes += stat.size
            end for
            item.writeMs = timer.totalMilliseconds()
            pausePort = CreateObject("roMessagePort")
            wait(1000, pausePort)
            item.memory = memorySample(volume + "after8MiB")
            bytes = invalid
            for i = 0 to 7
                m.fs.delete(dir + "/block-" + i.toStr())
            end for
        end if
        m.report.storage.push(item)
    end for
    saved = CreateObject("roRegistrySection", "AerioTV")
    m.base = normalizeBaseUrl(saved.read("serverUrl"))
    m.key = saved.read("apiKey")
    if saved.read("rememberApiKey") = "false" then m.key = ""
    if m.report.phase = "seed" and m.base <> "" and m.key <> ""
        user = requestJson(m.base + "/api/accounts/users/me/")
        m.report.authenticated = type(user) = "roAssociativeArray"
        user = invalid
        if m.report.authenticated
            probeRequest("channels-summary", "/api/channels/channels/summary/?ordering=channel_number&page_size=20", "channels")
            probeRequest("channel-page", "/api/channels/channels/?page=1&page_size=20", "channels")
            probeRequest("epg-mapping", "/api/epg/epgdata/?page=1&page_size=20", "none")
            now = CreateObject("roDateTime").asSeconds()
            start = CreateObject("roDateTime")
            finish = CreateObject("roDateTime")
            start.fromSeconds(now)
            finish.fromSeconds(now + 10800)
            encoder = CreateObject("roUrlTransfer")
            probeRequest("guide-3h", "/api/epg/grid/?start=" + encoder.escape(start.toISOString()) + "&end=" + encoder.escape(finish.toISOString()), "guide")
            probeRequest("movies-page-1", "/api/vod/movies/?page=1&page_size=20", "vod")
            probeRequest("movies-page-2", "/api/vod/movies/?page=2&page_size=20", "vod")
            probeRequest("series-page", "/api/vod/series/?page=1&page_size=20", "vod")
            probeRequest("vod-size-cap", "/api/vod/movies/?page=1&page_size=101", "vod")
        end if
    end if
    m.key = ""
    m.report.registryFreeAfter = registry.getSpaceAvailable()
    m.report.finalMemory = memorySample("done")
    m.top.report = m.report
end sub

sub probeHttpPolicy()
    saved = CreateObject("roRegistrySection", "AerioTV")
    m.base = normalizeBaseUrl(saved.read("serverUrl"))
    m.key = saved.read("apiKey")
    if saved.read("rememberApiKey") = "false" then m.key = ""
    if m.base = "" or m.key = "" then return
    response = requestJson(m.base + "/api/core/version/")
    m.report.validJson = type(response) = "roAssociativeArray"
    response = invalid
    m.maxResponseBytes = 64
    requestJson(m.base + "/api/channels/channels/summary/")
    m.report.limitCategory = m.httpFailure.category
    m.report.limitAttempts = m.httpAttempts
    m.maxResponseBytes = 8388608
    key = m.key
    m.key = "deliberately-invalid-probe-key"
    requestJson(m.base + "/api/accounts/users/me/")
    m.report.authCategory = m.httpFailure.category
    m.report.authAttempts = m.httpAttempts
    m.key = key
    m.top.cancelRequested = true
    requestJson(m.base + "/api/core/version/")
    m.report.cancelCategory = m.httpFailure.category
    m.report.cancelAttempts = m.httpAttempts
    m.report.remainingStagingFiles = m.fs.match("tmp:/", "aeriotv-http-*.json").count()
    m.key = ""
    key = ""
end sub

sub probeRequest(label as string, path as string, kind as string)
    before = memorySample(label + ":before")
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    transfer.setMessagePort(port)
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.setUrl(m.base + path)
    transfer.setHeaders({"X-API-Key": m.key, "Authorization": "ApiKey " + m.key, "Accept": "application/json"})
    transfer.enableEncodings(true)
    file = "tmp:/aeriotv-mxz1-response.json"
    timer = CreateObject("roTimespan")
    timer.mark()
    item = {label: label, before: before}
    if transfer.asyncGetToFile(file)
        event = wait(20000, port)
        if type(event) = "roUrlEvent"
            item.status = event.getResponseCode()
            item.downloadMs = timer.totalMilliseconds()
            item.hasEtag = false
            headers = event.getResponseHeaders()
            if type(headers) = "roAssociativeArray"
                for each header in headers
                    if lcase(header) = "etag" then item.hasEtag = true
                    if lcase(header) = "content-encoding" then item.encoding = left(textValue(headers[header]), 20)
                end for
            end if
            stat = m.fs.stat(file)
            if type(stat) = "roAssociativeArray" and stat.size <> invalid
                item.bytes = stat.size
                if item.status = 200 and stat.size <= 8388608
                    raw = ReadAsciiFile(file)
                    item.buffered = memorySample(label + ":string")
                    timer.mark()
                    data = ParseJson(raw)
                    item.parseMs = timer.totalMilliseconds()
                    item.parsed = memorySample(label + ":parsed")
                    raw = invalid
                    rows = apiRows(data)
                    if rows <> invalid
                        item.rows = rows.count()
                        item.paginated = false
                        if type(data) = "roAssociativeArray"
                            item.paginated = data.doesExist("results")
                            if data.count <> invalid then item.total = data.count
                            item.hasNext = textValue(data.next) <> ""
                        end if
                        normalized = []
                        timer.mark()
                        for each row in rows
                            if kind = "none" then exit for
                            value = invalid
                            if kind = "channels" then value = normalizeChannel(row)
                            if kind = "guide" then value = normalizeProgram(row)
                            if kind = "vod" then value = {id: textValue(row.id), uuid: textValue(row.uuid), name: left(textValue(row.name), 256), year: textValue(row.year)}
                            if value <> invalid then normalized.push(value)
                            if normalized.count() >= 2500 then exit for
                            if normalized.count() mod 128 = 0
                                if m.memory.getMemoryLimitPercent() >= 65 then exit for
                            end if
                        end for
                        item.normalizedRows = normalized.count()
                        item.normalizeMs = timer.totalMilliseconds()
                        item.normalized = memorySample(label + ":normalized")
                        data = invalid
                        rows = invalid
                        m.top.sample = normalized
                        wait(600, port)
                        normalized = invalid
                        m.top.sample = []
                    end if
                else
                    item.parseSkipped = true
                end if
            end if
        else
            item.timedOut = true
        end if
    end if
    transfer.asyncCancel()
    m.fs.delete(file)
    data = invalid
    rows = invalid
    raw = invalid
    normalized = invalid
    m.report.requests.push(item)
    print "[cache-probe-request] "; FormatJson(item)
end sub
