sub init()
    m.top.functionName = "holdConnection"
end sub

sub holdConnection()
    m.base = m.top.baseUrl
    m.key = m.top.apiKey
    m.timeout = 1500
    before = requestJson(m.base + "/proxy/ts/status/" + m.top.channelUuid)
    if type(before) <> "roAssociativeArray" or m.top.release
        m.top.apiKey = ""
        m.key = ""
        m.top.result = {ok: false, message: "Server status permission is required for guarded recovery."}
        return
    end if
    ' A bounded temporary client keeps the shared upstream alive during a local
    ' decoder restart. Never call the server's shared-channel Stop endpoint.
    nonce = CreateObject("roDeviceInfo").getRandomUUID()
    path = "tmp:/aeriotv-bridge-" + nonce + ".ts"
    agent = "AerioTV-Roku/decoder-recovery/" + nonce
    fs = CreateObject("roFileSystem")
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    transfer.setMessagePort(port)
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.setUrl(m.top.url)
    transfer.addHeader("X-API-Key", m.top.apiKey)
    transfer.addHeader("Authorization", "ApiKey " + m.top.apiKey)
    transfer.addHeader("User-Agent", agent)
    clock = CreateObject("roTimespan")
    clock.mark()
    received = false
    reason = "Could not establish a temporary playback connection."
    nextPoll = 0
    if transfer.asyncGetToFile(path)
        while clock.totalMilliseconds() < 12000 and not m.top.release
            event = wait(50, port)
            if type(event) = "roUrlEvent"
                if event.getInt() = 1 then exit while
            end if
            if clock.totalMilliseconds() >= nextPoll
                current = requestJson(m.base + "/proxy/ts/status/" + m.top.channelUuid)
                nextPoll = clock.totalMilliseconds() + 500
                if type(current) = "roAssociativeArray"
                    if type(current.clients) = "roArray"
                        for each client in current.clients
                            if textValue(client.user_agent) = agent
                                if not received
                                    received = true
                                    m.top.ready = true
                                end if
                                if textValue(client.bytes_sent).toInt() > 33554432
                                    reason = "Recovery transfer limit reached."
                                    m.top.release = true
                                end if
                            end if
                        end for
                    end if
                end if
            end if
            stat = fs.stat(path)
            if type(stat) = "roAssociativeArray"
                size = 0
                if stat.size <> invalid then size = stat.size
                if size > 33554432
                    reason = "Recovery buffer limit reached."
                    exit while
                end if
                if not received and size >= 376
                    bytes = CreateObject("roByteArray")
                    if bytes.readFile(path, 0, 376)
                        if bytes.count() >= 376
                            if bytes[0] = 71 and bytes[188] = 71
                                received = true
                                m.top.ready = true
                            end if
                        end if
                    end if
                end if
            end if
        end while
    end if
    m.top.ready = false
    transfer.asyncCancel()
    wait(250, port)
    fs.delete(path)
    after = requestJson(m.base + "/proxy/ts/status/" + m.top.channelUuid)
    fs.delete(path)
    source = "unknown"
    beforeCount = -1
    afterCount = -1
    if type(before) = "roAssociativeArray" and type(after) = "roAssociativeArray"
        if textValue(before.url) <> "" and textValue(after.url) <> ""
            source = "changed"
            if before.url = after.url then source = "same"
        end if
        beforeCount = textValue(before.client_count).toInt()
        afterCount = textValue(after.client_count).toInt()
    end if
    m.key = ""
    m.top.apiKey = ""
    m.top.url = ""
    m.top.result = {ok: received, released: m.top.release, message: reason, source: source, beforeCount: beforeCount, afterCount: afterCount}
end sub
