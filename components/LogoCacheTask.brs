sub init()
    m.top.functionName = "downloadLogos"
end sub

sub downloadLogos()
    fs = CreateObject("roFileSystem")
    port = CreateObject("roMessagePort")
    clock = CreateObject("roTimespan")
    clock.mark()
    pending = []
    for each id in m.top.ids
        if CreateObject("roRegex", "^[0-9]+$", "").isMatch(id) then pending.push(id)
    end for
    active = {}
    created = []
    assets = []
    failed = []
    while (pending.count() > 0 or active.count() > 0) and clock.totalMilliseconds() < 20000 and not m.top.cancelled
        while active.count() < 2 and pending.count() > 0
            id = pending.shift()
            path = m.top.prefix + "-" + id + ".part"
            created.push(path)
            transfer = CreateObject("roUrlTransfer")
            transfer.setMessagePort(port)
            transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
            transfer.setUrl(m.top.baseUrl + "/api/channels/logos/" + id + "/cache/")
            headers = dispatcharrRequestHeaders(m.top.apiKey, textValue(m.global.authHeaderMode), textValue(m.global.httpUserAgent))
            transfer.setHeaders(headers)
            if transfer.asyncGetToFile(path)
                active[transfer.getIdentity().toStr()] = {id: id, path: path, transfer: transfer}
            else
                failed.push(id)
            end if
        end while
        event = wait(25, port)
        if type(event) = "roUrlEvent"
            key = event.getSourceIdentity().toStr()
            if event.getInt() = 1 and active.doesExist(key)
                job = active[key]
                stat = fs.stat(job.path)
                size = 0
                if type(stat) = "roAssociativeArray"
                    if stat.size <> invalid then size = stat.size
                end if
                valid = false
                if event.getResponseCode() = 200
                    if size > 0 and size <= 2097152
                        bytes = CreateObject("roByteArray")
                        if bytes.readFile(job.path, 0, 12)
                            ext = logoExtension(bytes)
                            if ext <> ""
                                uri = m.top.prefix + "-" + job.id + ext
                                fs.delete(uri)
                                if fs.rename(job.path, uri)
                                    created.push(uri)
                                    asset = {id: job.id, uri: uri, bytes: size}
                                    assets.push(asset)
                                    m.top.asset = asset
                                    valid = true
                                end if
                            end if
                        end if
                    end if
                end if
                if not valid
                    failed.push(job.id)
                    fs.delete(job.path)
                end if
                active.delete(key)
            end if
        end if
        for each key in active.keys()
            job = active[key]
            stat = fs.stat(job.path)
            if type(stat) = "roAssociativeArray"
                size = 0
                if stat.size <> invalid then size = stat.size
                if size > 2097152
                    job.transfer.asyncCancel()
                    fs.delete(job.path)
                    failed.push(job.id)
                    active.delete(key)
                end if
            end if
        end for
    end while
    for each key in active
        job = active[key]
        job.transfer.asyncCancel()
        fs.delete(job.path)
        failed.push(job.id)
    end for
    failed.append(pending)
    if m.top.cancelled
        for each path in created
            fs.delete(path)
        end for
    end if
    m.top.apiKey = ""
    m.top.result = {assets: assets, failed: failed}
end sub

function logoExtension(bytes as object) as string
    if bytes.count() >= 3
        if bytes[0] = 255 and bytes[1] = 216 and bytes[2] = 255 then return ".jpg"
    end if
    if bytes.count() >= 8
        if bytes[0] = 137 and bytes[1] = 80 and bytes[2] = 78 and bytes[3] = 71 then return ".png"
    end if
    if bytes.count() >= 12
        if bytes[0] = 82 and bytes[1] = 73 and bytes[2] = 70 and bytes[3] = 70 and bytes[8] = 87 and bytes[9] = 69 and bytes[10] = 66 and bytes[11] = 80 then return ".webp"
    end if
    return ""
end function
