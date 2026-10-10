' Fetch only the EPG assignments referenced by the freshly authorized lineup.
' Eight bounded, file-backed requests avoid the unpaginated /epgdata/ list and
' never hold all response bodies or unrelated provider metadata in memory.
function mappingDetailIds(allowed as object) as object
    ids = []
    numeric = CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "")
    for each id in allowed
        if numeric.isMatch(id) then ids.push(id)
    end for
    return ids
end function

function mappingDetailKey(row as dynamic, id as string) as dynamic
    if type(row) <> "roAssociativeArray" then return invalid
    if textValue(row.id) <> id or not row.doesExist("tvg_id") then return invalid
    return textValue(row.tvg_id)
end function

function requestMappedDetails(allowed as object) as dynamic
    ids = mappingDetailIds(allowed)
    if ids.count() <> allowed.count()
        m.httpFailure = httpFailure(0, {}, 0, "invalid-response")
        m.failure = "The channel lineup contains an invalid EPG assignment ID."
        return invalid
    end if
    if ids.count() = 0 then return {}
    port = CreateObject("roMessagePort")
    fs = CreateObject("roFileSystem")
    clock = CreateObject("roTimespan")
    clock.mark()
    active = {}
    links = {}
    failed = false
    index = 0
    while (index < ids.count() or active.count() > 0) and not failed and not m.top.cancelRequested
        while active.count() < 8 and index < ids.count() and not failed
            id = ids[index]
            index++
            file = "tmp:/aeriotv-mapping-" + CreateObject("roDeviceInfo").getRandomUUID() + ".json"
            transfer = CreateObject("roUrlTransfer")
            transfer.setMessagePort(port)
            transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
            transfer.setUrl(m.base + "/api/epg/epgdata/" + id + "/")
            transfer.enableEncodings(true)
            headers = dispatcharrRequestHeaders(m.key, textValue(m.global.authHeaderMode), textValue(m.global.httpUserAgent))
            transfer.setHeaders(headers)
            if transfer.asyncGetToFile(file)
                active[transfer.getIdentity().toStr()] = {id: id, file: file, transfer: transfer, started: clock.totalMilliseconds()}
            else
                fs.delete(file)
                m.httpFailure = httpFailure(-1, {}, 0, "network")
                failed = true
            end if
        end while
        if failed then exit while
        event = wait(50, port)
        if type(event) = "roUrlEvent" and event.getInt() = 1
            key = event.getSourceIdentity().toStr()
            if active.doesExist(key)
                job = active[key]
                status = event.getResponseCode()
                stat = fs.stat(job.file)
                bytes = 0
                if type(stat) = "roAssociativeArray" and stat.size <> invalid then bytes = stat.size
                if status = 200 and bytes > 0 and bytes <= 65536
                    row = ParseJson(ReadAsciiFile(job.file))
                    mapped = mappingDetailKey(row, job.id)
                    if mapped <> invalid
                        links[job.id] = mapped
                    else
                        m.httpFailure = httpFailure(status, {}, 0, "invalid-response")
                        failed = true
                    end if
                else if status <> 404
                    problem = ""
                    if status = 200 and bytes > 65536 then problem = "too-large"
                    if status = 200 and bytes = 0 then problem = "invalid-response"
                    m.httpFailure = httpFailure(status, {}, 0, problem, bytes, 65536)
                    failed = true
                end if
                fs.delete(job.file)
                job.transfer.asyncCancel()
                active.delete(key)
            end if
        end if
        for each key in active.keys()
            job = active[key]
            stat = fs.stat(job.file)
            bytes = 0
            if type(stat) = "roAssociativeArray" and stat.size <> invalid then bytes = stat.size
            if bytes > 65536
                m.httpFailure = httpFailure(0, {}, 0, "too-large", bytes, 65536)
                failed = true
            else if clock.totalMilliseconds() - job.started > 20000 or clock.totalMilliseconds() > 120000
                m.httpFailure = httpFailure(0, {}, 0, "timeout")
                failed = true
            end if
        end for
    end while
    for each key in active
        job = active[key]
        job.transfer.asyncCancel()
        fs.delete(job.file)
    end for
    if failed
        m.failure = m.httpFailure.message
        return invalid
    end if
    if m.top.cancelRequested then return invalid
    return links
end function
