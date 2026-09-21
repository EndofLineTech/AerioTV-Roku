' Task-thread transport. GET bodies stage in tmp and are size-checked before
' reading/ParseJSON. tmp is not a hard byte quota: also abort on memory pressure.
function httpTransferOnce(url as string, body as dynamic, bearer as string, timeoutMs as integer, maxBytes as integer) as object
    result = {status: 0, headers: {}, body: "", bytes: -1, error: ""}
    port = CreateObject("roMessagePort")
    transfer = CreateObject("roUrlTransfer")
    transfer.setMessagePort(port)
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.setUrl(url)
    transfer.addHeader("Accept", "application/json")
    transfer.addHeader("User-Agent", "AerioTV-Roku/0.3")
    transfer.enableEncodings(true)
    if bearer <> ""
        transfer.addHeader("Authorization", "Bearer " + bearer)
    else if m.key <> ""
        transfer.addHeader("X-API-Key", m.key)
        transfer.addHeader("Authorization", "ApiKey " + m.key)
    end if
    file = ""
    fs = CreateObject("roFileSystem")
    monitor = CreateObject("roAppMemoryMonitor")
    if body = invalid
        file = "tmp:/aeriotv-http-" + CreateObject("roDeviceInfo").getRandomUUID() + ".json"
        started = transfer.asyncGetToFile(file)
    else
        transfer.addHeader("Content-Type", "application/json")
        started = transfer.asyncPostFromString(FormatJson(body))
    end if
    clock = CreateObject("roTimespan")
    clock.mark()
    if not started then result.error = "network"
    while started and clock.totalMilliseconds() < timeoutMs
        if httpIsCancelled()
            result.error = "cancelled"
            exit while
        end if
        if monitor <> invalid
            available = monitor.getChannelAvailableMemory()
            if monitor.getMemoryLimitPercent() >= 75 or (available > 0 and available < 32768)
                result.error = "memory"
                exit while
            end if
        end if
        if file <> ""
            stat = fs.stat(file)
            if type(stat) = "roAssociativeArray" and stat.size <> invalid
                result.bytes = stat.size
                if stat.size > maxBytes
                    result.error = "too-large"
                    exit while
                end if
            end if
        end if
        event = wait(50, port)
        if type(event) = "roUrlEvent"
            if event.getInt() = 1
                result.status = event.getResponseCode()
                result.headers = event.getResponseHeaders()
                if result.status >= 200 and result.status < 300
                    if file <> ""
                        stat = fs.stat(file)
                        if type(stat) <> "roAssociativeArray" or stat.size = invalid
                            result.error = "invalid-response"
                        else if stat.size > maxBytes
                            result.bytes = stat.size
                            result.error = "too-large"
                        else
                            result.body = ReadAsciiFile(file)
                            result.bytes = len(result.body)
                        end if
                    else
                        ' Native POST responses are buffered before this check.
                        result.body = event.getString()
                        result.bytes = len(result.body)
                        if len(result.body) > maxBytes then result.error = "too-large"
                    end if
                end if
                exit while
            end if
        end if
    end while
    if result.status = 0 and result.error = "" then result.error = "timeout"
    transfer.asyncCancel()
    transfer = invalid
    if file <> "" then fs.delete(file)
    return result
end function

function httpGuideWindowUrl(base as string, startTime as string, endTime as string) as string
    encoder = CreateObject("roUrlTransfer")
    return base + "/api/epg/grid/?start=" + encoder.escape(startTime) + "&end=" + encoder.escape(endTime)
end function
