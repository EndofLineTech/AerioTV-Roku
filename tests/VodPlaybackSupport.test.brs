sub main()
    base = "http://server.test:9191"
    other = "http://other.test:9191"
    store = loadVodUnsupported(vodSupportRegistry(""))
    assertEqual(store.keys.count(), 0, "missing record loads empty")
    assertEqual(loadVodUnsupported(vodSupportRegistry("not-json")).keys.count(), 0, "corrupt record loads empty")
    assertEqual(vodUnsupportedKey(base, "bad uuid/../x"), "", "unsafe catalog uuid is not stored")
    assertEqual(vodUnsupportedKey("", "abc"), "", "missing server is not stored")
    store = markVodUnsupported(store, base, "uuid-1")
    assertEqual(vodUnsupportedMarked(store, base, "uuid-1"), true, "refused title is marked")
    assertEqual(vodUnsupportedMarked(store, other, "uuid-1"), false, "marks are scoped to the server")
    assertEqual(vodUnsupportedMarked(store, base + "/", "uuid-1"), true, "server URL normalization does not split marks")
    assertEqual(instr(1, FormatJson(store), "server.test"), 0, "stored marks do not retain the server URL")
    again = markVodUnsupported(store, base, "uuid-1")
    assertEqual(again.keys.count(), 1, "marking twice keeps one entry")
    long = "u0123456789012345678901234567890123456789012345678901234567890123456789"
    big = {schema: 1, keys: []}
    for i = 1 to vodUnsupportedLimit()
        big = markVodUnsupported(big, base, long + i.toStr())
    end for
    assertEqual(len(FormatJson(big)) <= vodUnsupportedMaxBytes(), true, "long uuids stay within the registry byte budget")
    assertEqual(vodUnsupportedMarked(big, base, long + vodUnsupportedLimit().toStr()), true, "byte eviction keeps the newest mark")
    for i = 2 to vodUnsupportedLimit() + 5
        store = markVodUnsupported(store, base, "uuid-" + i.toStr())
    end for
    assertEqual(store.keys.count(), vodUnsupportedLimit(), "store is bounded")
    assertEqual(vodUnsupportedMarked(store, base, "uuid-1"), false, "oldest mark is evicted first")
    assertEqual(vodUnsupportedMarked(store, base, "uuid-" + (vodUnsupportedLimit() + 5).toStr()), true, "newest mark is retained")
    store = markVodUnsupported(store, base, "uuid-6")
    store = markVodUnsupported(store, base, "uuid-new")
    assertEqual(vodUnsupportedMarked(store, base, "uuid-6"), true, "re-marking refreshes recency")
    cleared = clearVodUnsupported(store, base, "uuid-6")
    assertEqual(vodUnsupportedMarked(cleared, base, "uuid-6"), false, "later playback clears the mark")
    assertEqual(vodUnsupportedMarked(store, base, "uuid-6"), true, "clearing does not mutate the original")
    registry = vodSupportRegistry("")
    assertEqual(saveVodUnsupported(registry, cleared), true, "marks persist")
    reloaded = loadVodUnsupported(registry)
    assertEqual(reloaded.keys.count(), cleared.keys.count(), "persisted marks reload")
    assertEqual(vodUnsupportedMarked(reloaded, base, "uuid-new"), true, "reloaded mark survives relaunch")
    registry.failFlush = true
    previous = registry.data
    assertEqual(saveVodUnsupported(registry, markVodUnsupported(reloaded, base, "uuid-x")), false, "failed flush reports failure")
    assertEqual(registry.data, previous, "failed flush restores the previous record")
    tampered = vodSupportRegistry(FormatJson({schema: 1, keys: ["0123456789abcdef:abc", 5, "no-separator", "0123456789abcdef:../y", "0123456789ABCDEF:abc"]}))
    assertEqual(loadVodUnsupported(tampered).keys.count(), 1, "invalid stored entries are dropped")
    lookup = vodUnsupportedLookup(reloaded, base)
    assertEqual(lookup["uuid-new"], true, "view lookup is keyed by catalog uuid for one server")
    assertEqual(vodUnsupportedLookup(reloaded, other).count(), 0, "view lookup excludes other servers")
    checkSceneMarksRefusals()
    print "ALL TESTS PASSED"
end sub

function vodSupportRegistry(data as string) as object
    return {data: data, failFlush: false
        read: function(key as string) as string
            if key <> "vodUnsupportedV1" then return ""
            return m.data
        end function
        write: function(key as string, value as string) as boolean
            if key <> "vodUnsupportedV1" then return false
            m.data = value
            return true
        end function
        delete: function(key as string) as boolean
            m.data = ""
            return true
        end function
        flush: function() as boolean
            return not m.failFlush
        end function
    }
end function

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label
        stop
    end if
end sub

' Host brs does not implement Roku's roEVPDigest or roByteArray.fromAsciiString.
' Deterministic lowercase hex stand-in; distinct for the servers used here.
function metadataCacheDigest(value as string) as string
    digits = "0123456789abcdef"
    result = ""
    for round = 1 to 4
        hash = round * 7919
        for i = 1 to len(value)
            hash = (hash * 31 + asc(mid(value, i, 1))) mod 65521
        end for
        for j = 1 to 4
            result += mid(digits, (hash mod 16) + 1, 1)
            hash = hash \ 16
        end for
    end for
    return result
end function

sub checkSceneMarksRefusals()
    base = "http://server.test:9191"
    m.global = {activeusersession: "holder"}
    m.registry = vodSupportRegistry("")
    m.baseUrl = base
    m.vod = {}
    m.mediaPlayer = {serial: 1, isSameNode: function(other as dynamic) as boolean
        return other <> invalid and other.serial = m.serial
    end function}
    m.mediaItem = vodNormalize({id: 7, uuid: "wide-uuid", name: "Wide"}, "movie")
    m.mediaIdentity = "roku_current"
    m.diagnostics = []
    wide = ":pump:Image width too high: ISO/IEC 14496-10, MPEG-4 part 10 Annex-B, H.264, AVC"
    onMediaDiagnostic(sceneDiagnosticEvent(m.mediaPlayer, "roku_current", -1, "HTTP 500"))
    assertEqual(m.registry.data, "", "network failures are not format evidence")
    onMediaDiagnostic(sceneDiagnosticEvent(m.mediaPlayer, "roku_previous", -5, wide))
    assertEqual(m.registry.data, "", "a stale reader cannot mark the current title")
    onMediaDiagnostic(sceneDiagnosticEvent(m.mediaPlayer, "roku_current", -5, wide))
    assertEqual(vodUnsupportedMarked(loadVodUnsupported(m.registry), base, "wide-uuid"), true, "native width refusal is persisted for the title")
    assertEqual(m.vod.unsupportedTitles["wide-uuid"], true, "library view receives the mark")
    m.userProfileRecoveryRequired = true
    rememberVodUnsupported("roku_current", false)
    assertEqual(vodUnsupportedMarked(loadVodUnsupported(m.registry), base, "wide-uuid"), true, "recovery mode does not write the registry")
    assertEqual(m.vod.unsupportedTitles.count(), 0, "recovery mode still updates the session view")
    m.userProfileRecoveryRequired = false
    m.vodUnsupported = invalid
    m.accountIdentity = "account"
    m.accountPreferences = {vod: {}, vodRecent: []}
    m.lastVodWrite = 0
    m.lastVodState = ""
    m.mediaHistoryRecorded = false
    onMediaProgress(sceneProgressEvent(m.mediaPlayer, "roku_current", m.mediaItem.key, "buffering", 0))
    assertEqual(vodUnsupportedMarked(loadVodUnsupported(m.registry), base, "wide-uuid"), true, "buffering does not clear the mark")
    onMediaProgress(sceneProgressEvent(m.mediaPlayer, "roku_previous", m.mediaItem.key, "playing", 5))
    assertEqual(vodUnsupportedMarked(loadVodUnsupported(m.registry), base, "wide-uuid"), true, "a stale reader cannot clear the mark")
    onMediaProgress(sceneProgressEvent(m.mediaPlayer, "roku_current", m.mediaItem.key, "playing", 5))
    assertEqual(vodUnsupportedMarked(loadVodUnsupported(m.registry), base, "wide-uuid"), false, "actual playback clears the persisted mark")
    m.global = invalid
end sub

function sceneDiagnosticEvent(node as object, identity as string, code as integer, message as string) as object
    data = userViewEvent({mode: "vod", account: "account", identity: identity, code: code, message: message}, "holder")
    return {node: node, data: data, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as object
        return m.data
    end function}
end function

function sceneProgressEvent(node as object, identity as string, key as string, state as string, position as integer) as object
    data = userViewEvent({account: "account", identity: identity, key: key, mode: "vod", position: position, duration: 600, finished: false, state: state, closing: false}, "holder")
    return {node: node, data: data, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as object
        return m.data
    end function}
end function

function persistAccountPreferences() as boolean
    return true
end function

sub recordDiagnostic(stage as string, code as integer, message as string, elapsedMs = 0 as integer)
    m.diagnostics.push(stage)
end sub
