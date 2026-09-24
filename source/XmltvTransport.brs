' Task-thread-only bounded download. The caller owns and deletes the tmp file.
function xmltvDownloadToFile(url as string, path as string, maxBytes = 75497472 as integer, timeoutMs = 45000 as integer) as object
    fs = CreateObject("roFileSystem")
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    transfer.setMessagePort(port)
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.setUrl(url)
    transfer.addHeader("User-Agent", dispatcharrUserAgent(textValue(m.global.httpUserAgent)))
    transfer.enableEncodings(true)
    if not transfer.asyncGetToFile(path) then return {ok: false, message: "Could not start XMLTV download."}
    monitor = CreateObject("roAppMemoryMonitor")
    clock = CreateObject("roTimespan")
    clock.mark()
    result = {ok: false, message: "XMLTV download timed out."}
    while clock.totalMilliseconds() < timeoutMs
        if m.top.cancelRequested = true
            result.message = "XMLTV load cancelled."
            exit while
        end if
        stat = fs.stat(path)
        if type(stat) = "roAssociativeArray"
            if GetInterface(stat.size, "ifInt") <> invalid
                if stat.size > maxBytes
                    result.message = "XMLTV feed exceeds this device's file budget."
                    exit while
                end if
            end if
        end if
        if monitor <> invalid
            percent = monitor.getMemoryLimitPercent()
            if percent <> invalid
                if percent >= 75
                    result.message = "Device memory pressure stopped XMLTV download."
                    exit while
                end if
            end if
        end if
        event = wait(50, port)
        if type(event) = "roUrlEvent"
            if event.getInt() = 1
                if event.getResponseCode() = 200
                    result = {ok: true}
                else
                    result.message = "XMLTV server did not return a guide."
                end if
                exit while
            end if
        end if
    end while
    transfer.asyncCancel()
    transfer = invalid
    if result.ok
        stat = fs.stat(path)
        if type(stat) <> "roAssociativeArray" then result = {ok: false, message: "XMLTV file unavailable."}
        if type(stat) = "roAssociativeArray"
            if GetInterface(stat.size, "ifInt") = invalid then result = {ok: false, message: "XMLTV file size unavailable."}
            if GetInterface(stat.size, "ifInt") <> invalid
                if stat.size < 1 or stat.size > maxBytes then result = {ok: false, message: "XMLTV file exceeds this device's budget."}
            end if
        end if
    end if
    if not result.ok then fs.delete(path)
    return result
end function
