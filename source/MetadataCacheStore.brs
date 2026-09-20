' Task thread only. Optional cache: every failure becomes a miss, never data loss.
function metadataCacheRoot() as string
    return "cachefs:/aeriotv-metadata-v1"
end function

function metadataCacheFiles(fs as object) as object
    rows = []
    root = metadataCacheRoot()
    if not fs.exists(root) then return rows
    pattern = CreateObject("roRegex", "^([0-9a-f]{64})-([0-9]{10})-([0-9a-f]{64})[.]json$", "")
    for each name in fs.getDirectoryListing(root)
        parts = pattern.match(name)
        if parts.count() = 4
            stat = fs.stat(root + "/" + name)
            if stat <> invalid
                if stat.size <> invalid then rows.push({name: name, stamp: parts[2].toInt(), bytes: stat.size, scope: parts[1]})
            end if
        end if
    end for
    rows.sortBy("stamp")
    return rows
end function

function metadataCacheRead(scope as string, kind as string, key as string, generation as string, now as integer, authorized as boolean) as object
    miss = {state: "miss"}
    if not authorized or not metadataCacheScopeValid(scope) then return miss
    policy = metadataCachePolicy(kind)
    if policy = invalid then return miss
    fs = CreateObject("roFileSystem")
    files = metadataCacheFiles(fs)
    suffix = "-" + metadataCacheDigest(kind + "|" + key + "|" + generation) + ".json"
    for i = files.count() - 1 to 0 step -1
        file = files[i]
        if file.scope = scope and right(file.name, len(suffix)) = suffix and file.bytes <= policy.maxBytes
            raw = ReadAsciiFile(metadataCacheRoot() + "/" + file.name)
            if raw <> ""
                entry = ParseJson(raw)
                raw = invalid
                state = metadataCacheState(entry, scope, kind, key, generation, now, authorized, file.bytes)
                if state <> "miss"
                    if GetInterface(entry.checksum, "ifString") <> invalid
                        if metadataCacheDigest(FormatJson(entry.payload)) = entry.checksum
                            return {state: state, payload: entry.payload, fetched: entry.fetched}
                        end if
                    end if
                end if
            end if
        end if
    end for
    return miss
end function

function metadataCacheScopeValid(scope as string) as boolean
    return CreateObject("roRegex", "^[0-9a-f]{64}$", "").isMatch(scope)
end function

function metadataCacheWriteAllowed() as boolean
    if m.top.hasField("cancelRequested")
        if m.top.cancelRequested then return false
    end if
    if m.top.hasField("cacheEpoch") and m.global.hasField("cacheEpoch")
        if m.top.cacheEpoch <> m.global.cacheEpoch then return false
    end if
    return true
end function

function metadataCacheWrite(scope as string, kind as string, key as string, generation as string, now as integer, payload as dynamic) as boolean
    if not metadataCacheScopeValid(scope) or not metadataCacheWriteAllowed() then return false
    policy = metadataCachePolicy(kind)
    if policy = invalid then return false
    entry = metadataCacheEnvelope(scope, kind, key, generation, now, payload)
    if entry = invalid then return false
    entry.checksum = metadataCacheDigest(FormatJson(payload))
    raw = FormatJson(entry)
    encoded = CreateObject("roByteArray")
    encoded.fromAsciiString(raw)
    rawBytes = encoded.count()
    encoded = invalid
    if raw = "" or rawBytes > policy.maxBytes then return false
    fs = CreateObject("roFileSystem")
    root = metadataCacheRoot()
    if not fs.exists(root)
        if not fs.createDirectory(root) then return false
    end if
    session = "default"
    if m.global.hasField("metadataSession") then session = m.global.metadataSession
    lock = root + "/lock-" + session
    if not fs.createDirectory(lock) then return false ' another writer; caching is optional
    ' Only one writer in this app session. Remove leftovers from interrupted writes
    ' before counting committed bytes; previous app sessions cannot still be running.
    for each name in fs.getDirectoryListing(root)
        if right(name, 5) = ".part"
            if not fs.delete(root + "/" + name)
                fs.delete(lock)
                return false
            end if
        else if left(name, 5) = "lock-" and root + "/" + name <> lock
            fs.delete(root + "/" + name)
        end if
    end for
    result = metadataCacheWriteLocked(fs, scope, kind, key, generation, now, raw, rawBytes)
    fs.delete(lock)
    return result
end function

function metadataCacheWriteLocked(fs as object, scope as string, kind as string, key as string, generation as string, now as integer, raw as string, rawBytes as integer) as boolean
    root = metadataCacheRoot()
    files = metadataCacheFiles(fs)
    bytes = 0
    for each file in files
        bytes += file.bytes
    end for
    while files.count() >= 64 or bytes + rawBytes > 8388608
        if files.count() = 0 then return false
        victim = files.shift()
        if not fs.delete(root + "/" + victim.name) then return false
        bytes -= victim.bytes
    end while
    suffix = "-" + metadataCacheDigest(kind + "|" + key + "|" + generation) + ".json"
    name = scope + "-" + now.toStr() + suffix
    part = root + "/" + scope + "-pending-" + CreateObject("roDeviceInfo").getRandomUUID() + ".part"
    ok = WriteAsciiFile(part, raw)
    stat = fs.stat(part)
    if stat = invalid
        ok = false
    else if stat.size <> rawBytes
        ok = false
    end if
    if ok and metadataCacheWriteAllowed()
        fs.delete(root + "/" + name)
        ok = fs.rename(part, root + "/" + name)
        if ok
            for each file in files
                if file.scope = scope and right(file.name, len(suffix)) = suffix and file.name <> name then fs.delete(root + "/" + file.name)
            end for
        end if
    else
        ok = false
    end if
    fs.delete(part)
    return ok
end function

sub metadataCacheClear(scope as string)
    if not metadataCacheScopeValid(scope) then return
    fs = CreateObject("roFileSystem")
    root = metadataCacheRoot()
    if not fs.exists(root) then return
    for each name in fs.match(root, scope + "-*")
        if instr(1, name, "/") = 0 and instr(1, name, "..") = 0 then fs.delete(root + "/" + name)
    end for
end sub
