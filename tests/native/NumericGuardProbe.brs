' All inputs are local fixtures. Exercise public model entry points, not replicas
' of their type predicates. Record mismatches instead of stopping at the first.
sub runNumericGuardProbe(native as boolean)
    m.numericGuardRows = 0
    m.numericGuardMismatches = 0
    m.numericGuardCallerMismatches = 0
    m.numericGuardObservations = 0

    numericHttp("primitive-int", 1048577, 1048576, "at-least-1-mib")
    numericHttp("default-cap", 16000001, 16000000, "at-least-16-mb")
    numericHttp("cap-boundary", 1048576, 1048576, "")
    numericHttp("mapping-small-cap", 65537, 65536, "")
    numericHttp("direct-len", len("ab") + 1048575, 1048576, "at-least-1-mib")
    for each row in [
        {name: "aa-int", bytes: 1048577, cap: 1048576, bucket: "at-least-1-mib"},
        {name: "long", bytes: 1048577&, cap: 1048576&, bucket: ""},
        {name: "wide-long", bytes: 2147483648&, cap: 2147483648&, bucket: ""},
        {name: "float-whole", bytes: 1048577.0!, cap: 1048576.0!, bucket: ""},
        {name: "float-fractional", bytes: 1048577.5!, cap: 1048576.5!, bucket: ""},
        {name: "double-whole", bytes: 1048577.0#, cap: 1048576.0#, bucket: ""},
        {name: "double-fractional", bytes: 1048577.5#, cap: 1048576.5#, bucket: ""},
        {name: "invalid", bytes: invalid, cap: invalid, bucket: ""},
        {name: "bool", bytes: true, cap: true, bucket: ""},
        {name: "string", bytes: "1048577", cap: "1048576", bucket: ""}
    ]
        numericHttp(row.name + "/response", row.bytes, 1048576, row.bucket)
        numericHttp(row.name + "/cap", 1048577, row.cap, row.bucket)
    end for
    for each row in [
        {name: "int", bytes: "1048577", cap: "1048576", bucket: "at-least-1-mib"},
        {name: "long", bytes: "2147483648", cap: "2147483648", bucket: ""},
        {name: "decimal-whole", bytes: "1048577.0", cap: "1048576.0", bucket: "observe"},
        {name: "exponent-whole", bytes: "1048577e0", cap: "1048576e0", bucket: "observe"},
        {name: "fractional", bytes: "1048577.5", cap: "1048576.5", bucket: ""},
        {name: "null", bytes: "null", cap: "null", bucket: ""},
        {name: "bool", bytes: "true", cap: "true", bucket: ""},
        {name: "string", bytes: """1048577""", cap: """1048576""", bucket: ""}
    ]
        parsedHttp = ParseJson("{""bytes"":" + row.bytes + ",""cap"":" + row.cap + "}")
        numericHttp("parsed-" + row.name + "/response", parsedHttp.bytes, 1048576, row.bucket)
        numericHttp("parsed-" + row.name + "/cap", 1048577, parsedHttp.cap, row.bucket)
    end for
    ' Mirrors the transport result and m.maxResponseBytes override independently.
    response = {bytes: 1048577}
    m.numericGuardCap = 1048576
    numericHttp("transport-aa-shape", response.bytes, 1048576, "at-least-1-mib", "caller-shape")
    numericHttp("task-cap-shape", 1048577, m.numericGuardCap, "at-least-1-mib", "caller-shape")
    if native then numericNativeHttp()

    numericPrimitiveControls(1, 1700000, native)
    entry = metadataCacheEnvelope("scope", "channels", "key", "gen", 1700000, [])
    numericCache("constructed-envelope", entry, "fresh", "synthetic")
    numericCache("persisted-roundtrip", ParseJson(FormatJson(entry)), "fresh", "caller")
    epoch = "1700000000".toInt()
    entry = metadataCacheEnvelope("scope", "channels", "key", "gen", epoch, [])
    numericCache("epoch-roundtrip", ParseJson(FormatJson(entry)), "fresh", "caller", epoch + 1)

    for each row in [
        {name: "aa-int", value: 1, fetched: 1700000, expected: true},
        {name: "long", value: 1&, fetched: 1700000&, expected: false},
        {name: "wide-long", value: 2147483648&, fetched: 2147483648&, expected: false},
        {name: "float-whole", value: 1.0!, fetched: 1700000.0!, expected: false},
        {name: "float-fractional", value: 1.5!, fetched: 1700000.5!, expected: false},
        {name: "double-whole", value: 1.0#, fetched: 1700000.0#, expected: false},
        {name: "double-fractional", value: 1.5#, fetched: 1700000.5#, expected: false},
        {name: "invalid", value: invalid, fetched: invalid, expected: false},
        {name: "bool", value: true, fetched: true, expected: false},
        {name: "string", value: "1", fetched: "1700000", expected: false}
    ]
        expectedCache = "miss"
        if row.expected then expectedCache = "fresh"
        entry = numericCacheJson("1", "1700000")
        entry.schema = row.value
        numericCache(row.name + "/schema", entry, expectedCache, "synthetic")
        entry = numericCacheJson("1", "1700000")
        entry.fetched = row.fetched
        numericCache(row.name + "/fetched", entry, expectedCache, "synthetic")
        prefs = {schema: row.value, device: {}, accounts: {probe: {favoriteIds: ["probe"]}}}
        numericGuardReport("preferences/model", row.name, type(prefs.schema), numericPreferenceState(normalizePreferenceStore(prefs)), numericPreferenceExpected(row.expected), "synthetic")
    end for

    for each row in [
        {name: "int", schema: "1", fetched: "1700000", cache: "fresh", prefs: "kept", strict: "kept"},
        {name: "wrong-int", schema: "2", fetched: "0", cache: "miss", prefs: "future", strict: "refused"},
        {name: "wide", schema: "2147483648", fetched: "2147483648", cache: "miss", prefs: "default", strict: "refused"},
        {name: "decimal-whole", schema: "1.0", fetched: "1700000.0", cache: "observe", prefs: "observe", strict: "observe"},
        {name: "exponent-whole", schema: "1e0", fetched: "17e5", cache: "observe", prefs: "observe", strict: "observe"},
        {name: "fractional", schema: "1.5", fetched: "1700000.5", cache: "miss", prefs: "default", strict: "refused"},
        {name: "null", schema: "null", fetched: "null", cache: "miss", prefs: "default", strict: "refused"},
        {name: "bool", schema: "true", fetched: "true", cache: "miss", prefs: "default", strict: "refused"},
        {name: "string", schema: """1""", fetched: """1700000""", cache: "miss", prefs: "default", strict: "refused"}
    ]
        numericCache("parsed-" + row.name + "/schema", numericCacheJson(row.schema, "1700000"), row.cache, "wire")
        numericCache("parsed-" + row.name + "/fetched", numericCacheJson("1", row.fetched), row.cache, "wire")
        numericPreferenceLoad(row.name, row.schema, row.prefs, row.strict, native)
    end for
    numericPreferenceRoundTrip(native)

    raw = {playlist: {type: "m3u", name: "Probe", url: "probe", guideDays: 1, catchupOffsetMinutes: 1, channelProfileIds: [1]}, profiles: [{username: "probe", displayName: "Probe", order: 1}]}
    numericPhoneFieldResult(raw, raw.playlist.guideDays, "guideDays", "synthetic", "literal-field", "accepted")
    numericPhoneFieldResult(raw, raw.playlist.catchupOffsetMinutes, "catchupOffsetMinutes", "synthetic", "literal-field", "accepted")
    numericPhoneFieldResult(raw, raw.playlist.channelProfileIds[0], "channelProfileIds", "synthetic", "literal-field", "accepted")
    numericPhoneFieldResult(raw, raw.profiles[0].order, "order", "synthetic", "literal-field", "accepted")

    for each row in [
        {name: "aa-int", value: 1, expected: "accepted"},
        {name: "long", value: 1&, expected: "accepted"},
        {name: "wide-long", value: 2147483648&, expected: "accepted"},
        {name: "float-whole", value: 1.0!, expected: "accepted"},
        {name: "float-fractional", value: 1.5!, expected: "refused"},
        {name: "double-whole", value: 1.0#, expected: "accepted"},
        {name: "double-fractional", value: 1.5#, expected: "refused"},
        {name: "invalid", value: invalid, expected: "default"},
        {name: "bool", value: true, expected: "refused"},
        {name: "string", value: "1", expected: "refused"}
    ]
        numericPhoneFields("synthetic", "typed-" + row.name, row.value, row.expected, native)
    end for
    for each row in [
        {name: "int", token: "1", version: "accepted", payload: "accepted"},
        {name: "wrong-int", token: "2", version: "refused", payload: "accepted"},
        {name: "guide-range", token: "15", version: "refused", payload: "accepted"},
        {name: "wide", token: "2147483648", version: "refused", payload: "accepted"},
        {name: "decimal-whole", token: "1.0", version: "accepted", payload: "accepted"},
        {name: "exponent-whole", token: "1e0", version: "accepted", payload: "accepted"},
        {name: "fractional", token: "1.5", version: "refused", payload: "refused"},
        {name: "null", token: "null", version: "refused", payload: "default"},
        {name: "bool", token: "true", version: "refused", payload: "refused"},
        {name: "string", token: """1""", version: "refused", payload: "refused"}
    ]
        numericPhoneVersion(row.name, row.token, row.version)
        numericPhoneFields("wire", row.name, row.token, row.payload, native)
    end for

    print "[numeric-guard] COMPLETE "; FormatJson({native: native, rows: m.numericGuardRows, mismatches: m.numericGuardMismatches, callerMismatches: m.numericGuardCallerMismatches, observations: m.numericGuardObservations})
end sub

sub numericPrimitiveControls(one as integer, fetched as integer, native as boolean)
    ' Show the declared primitive immediately before insertion and the field
    ' types afterward. Only HTTP accepts a free-standing numeric argument.
    print "[numeric-guard] PRIMITIVES "; FormatJson({one: type(one), fetched: type(fetched)})
    entry = numericCacheJson("1", "1700000")
    entry.schema = one
    numericCache("primitive-assigned/schema", entry, "fresh", "synthetic")
    entry = numericCacheJson("1", "1700000")
    entry.fetched = fetched
    numericCache("primitive-assigned/fetched", entry, "fresh", "synthetic")
    prefs = {device: {}, accounts: {probe: {favoriteIds: ["probe"]}}}
    prefs.schema = one
    numericGuardReport("preferences/model", "primitive-assigned", type(prefs.schema), numericPreferenceState(normalizePreferenceStore(prefs)), "kept", "synthetic")
    numericPhoneFields("synthetic", "primitive-assigned", one, "accepted", native)
end sub

sub numericGuardReport(target as string, name as string, kinds as string, actual as string, expected as string, lane as string)
    m.numericGuardRows++
    if expected = "observe"
        m.numericGuardObservations++
    else if actual <> expected
        m.numericGuardMismatches++
        if lane = "caller" or lane = "caller-shape" then m.numericGuardCallerMismatches++
    end if
    print "[numeric-guard] "; FormatJson({target: target, name: name, kinds: kinds, actual: actual, expected: expected, lane: lane})
end sub

sub numericHttp(name as string, bytes as dynamic, cap as dynamic, expected as string, lane = "synthetic" as string)
    failure = httpFailure(0, {}, 0, "too-large", bytes, cap)
    actual = failure.sizeBucket
    if failure.category <> "response-too-large" then actual = "bad-category"
    numericGuardReport("http/failure", name, type(bytes) + "/" + type(cap), actual, expected, lane)
end sub

sub numericNativeHttp()
    ' Local filesystem only. Same source of byte count as HttpTransport, without a transfer.
    blob = "x"
    for i = 1 to 20
        blob += blob
    end for
    blob += "x"
    numericHttp("native-len", len(blob), 1048576, "at-least-1-mib", "caller-shape")
    octets = CreateObject("roByteArray")
    octets.fromAsciiString(blob)
    response = {bytes: octets.count()}
    numericHttp("native-byte-array-count", response.bytes, 1048576, "at-least-1-mib", "caller-shape")
    path = "tmp:/numeric-guard-probe.tmp"
    fs = CreateObject("roFileSystem")
    if WriteAsciiFile(path, blob)
        stat = fs.stat(path)
        fs.delete(path)
        if type(stat) = "roAssociativeArray"
            response.bytes = stat.size
            numericHttp("native-stat-size", response.bytes, 1048576, "at-least-1-mib", "caller-shape")
            return
        end if
    end if
    numericGuardReport("http/failure", "native-stat-size", "", "fixture-error", "at-least-1-mib", "fixture")
end sub

function numericCacheJson(schema as string, fetched as string) as dynamic
    return ParseJson("{""schema"":" + schema + ",""fetched"":" + fetched + ",""scope"":""scope"",""kind"":""channels"",""key"":""key"",""generation"":""gen"",""complete"":true,""payload"":[]}")
end function

sub numericCache(name as string, entry as dynamic, expected as string, lane as string, now = 1700001 as integer)
    if type(entry) <> "roAssociativeArray"
        numericGuardReport("metadata/state", name, type(entry), "fixture-error", expected, "fixture")
        return
    end if
    numericGuardReport("metadata/state", name, type(entry.schema) + "/" + type(entry.fetched), metadataCacheState(entry, "scope", "channels", "key", "gen", now, true, 256), expected, lane)
end sub

function numericPreferenceExpected(accepted as boolean) as string
    if accepted then return "kept"
    return "default"
end function

function numericPreferenceState(store as object) as string
    if store.readOnly = true then return "refused"
    if store.schema > 1 then return "future"
    if type(store.accounts.probe) = "roAssociativeArray"
        if type(store.accounts.probe.favoriteIds) = "roArray"
            if store.accounts.probe.favoriteIds[0] = "probe" then return "kept"
        end if
    end if
    return "default"
end function

sub numericPreferenceLoad(name as string, schema as string, expected as string, strictExpected as string, native as boolean)
    registry = numericPreferenceRegistry("{""schema"":" + schema + ",""device"":{},""accounts"":{""probe"":{""favoriteIds"":[""probe""]}}}")
    decoded = ParseJson(registry.value)
    numericGuardReport("preferences/load", name, type(decoded.schema), numericPreferenceState(loadPreferenceStore(registry)), expected, "wire")
    if native
        precise = ParseJson(registry.value, "d")
        kind = type(precise.schema)
        lane = "wire"
        if name = "int" then lane = "caller"
        strict = loadStrictPreferenceStore(registry)
        strictState = numericPreferenceState(strict)
        numericGuardReport("preferences/strict", name, kind + "/" + type(strict.schema), strictState, strictExpected, lane)
        afterStrict = "observe"
        if strictExpected = "refused" then afterStrict = "refused"
        if strictExpected = "kept" then afterStrict = "kept"
        numericGuardReport("preferences/cold-load", name, kind, numericPreferenceState(loadPreferenceStore(registry, true)), afterStrict, lane)
    end if
end sub

sub numericPreferenceRoundTrip(native as boolean)
    store = defaultPreferenceStore()
    store.accounts.probe = {favoriteIds: ["probe"]}
    registry = numericPreferenceRegistry("")
    if not savePreferenceStore(registry, store)
        numericGuardReport("preferences/roundtrip", "writer", type(store.schema), "fixture-error", "kept", "fixture")
        return
    end if
    decoded = ParseJson(registry.value)
    if native then decoded = ParseJson(registry.value, "d")
    numericGuardReport("preferences/roundtrip", "writer", type(store.schema) + "/" + type(decoded.schema), numericPreferenceState(loadPreferenceStore(registry, native)), "kept", "caller")
end sub

function numericPreferenceRegistry(raw as string) as object
    return {value: raw,
        read: function(key as string) as string
            return m.value
        end function,
        exists: function(key as string) as boolean
            return true
        end function,
        write: function(key as string, value as string) as boolean
            m.value = value
            return true
        end function,
        flush: function() as boolean
            return true
        end function}
end function

sub numericPhoneVersion(name as string, token as string, expected as string)
    ' Correct base64url shapes; no cryptography or credentials.
    body = "{""v"":" + token + ",""phonePk"":""AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"",""nonce"":""AAAAAAAAAAAAAAAA"",""ciphertext"":""AAAAAAAAAAAAAAAAAAAAAAA""}"
    envelope = ParseJson(body)
    result = validatePhoneSetupEnvelope(body, false)
    actual = numericPhoneResult(result)
    lane = "wire"
    if name = "int" then lane = "caller"
    numericGuardReport("phone/envelope", name, type(envelope.v), actual, expected, lane)
end sub

function numericPhoneResult(result as object) as string
    if result.ok = true then return "accepted"
    if result.status = 400 and result.error = "bad_request" then return "refused"
    if result.probeException = true then return "runtime-exception"
    return "bad-result"
end function

sub numericPhoneFields(lane as string, name as string, input as dynamic, expected as string, native as boolean)
    for each field in ["guideDays", "catchupOffsetMinutes", "channelProfileIds", "order"]
        raw = {playlist: {type: "m3u", name: "Probe", url: "probe"}, profiles: [{username: "probe", displayName: "Probe"}]}
        if lane = "wire"
            playlist = "{""type"":""m3u"",""name"":""Probe"",""url"":""probe"""
            profile = "{""username"":""probe"",""displayName"":""Probe"""
            if field = "order"
                profile += ",""order"":" + input
            else if field = "channelProfileIds"
                playlist += ",""channelProfileIds"":[" + input + "]"
            else
                playlist += ",""" + field + """:" + input
            end if
            raw = ParseJson("{""playlist"":" + playlist + "},""profiles"":[" + profile + "}]}")
        else if field = "order"
            raw.profiles[0].order = input
        else if field = "channelProfileIds"
            raw.playlist.channelProfileIds = [input]
        else
            raw.playlist[field] = input
        end if
        value = raw.playlist[field]
        if field = "order" then value = raw.profiles[0].order
        if field = "channelProfileIds" then value = raw.playlist.channelProfileIds[0]
        if not native and type(value) = "Double"
            ' The host brs Fix() rejects Double and aborts the interpreter.
            numericGuardReport("phone/payload/" + field, name, type(value), "host-fix-unsupported", "observe", "host-only")
        else
            numericPhoneFieldResult(raw, value, field, lane, name, expected)
        end if
    end for
end sub

sub numericPhoneFieldResult(raw as object, value as dynamic, field as string, lane as string, name as string, expected as string)
    result = numericValidatePhonePayload(raw)
    actual = numericPhoneResult(result)
    fieldExpected = expected
    if field = "channelProfileIds" and expected = "default" then fieldExpected = "refused"
    if field = "guideDays" and (name = "guide-range" or name = "wide" or name = "typed-wide-long") then fieldExpected = "refused"
    if result.ok
        output = result.payload.playlist[field]
        fallback = 0
        if field = "guideDays" then fallback = 7
        if field = "order"
            output = result.payload.profiles[0].order
            fallback = -1
        else if field = "channelProfileIds"
            if type(output) = "roArray" then output = output[0]
        end if
        if value = invalid
            if output = fallback then actual = "default" else actual = "bad-default"
        else if output <> value
            actual = "changed-value"
        end if
    end if
    rowLane = lane
    if lane = "wire" and name = "int" then rowLane = "caller"
    numericGuardReport("phone/payload/" + field, name, type(value), actual, fieldExpected, rowLane)
end sub
