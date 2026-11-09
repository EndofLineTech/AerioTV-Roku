' Wire-v1 validation only. No listener or credential import is enabled here.
' The receiver must cap bytes WHILE receiving, before constructing this string.
function validatePhoneSetupEnvelope(body as dynamic, hasOrigin as boolean) as object
    if hasOrigin then return phoneSetupFailure(403, "forbidden")
    if type(body) <> "String" and type(body) <> "roString" then return phoneSetupFailure(400, "bad_request")
    if len(body) > 262144 then return phoneSetupFailure(413, "too_large")
    envelope = parseJson(body)
    if type(envelope) <> "roAssociativeArray" then return phoneSetupFailure(400, "bad_request")
    kind = type(envelope.v)
    if kind <> "Integer" and kind <> "roInt" and kind <> "Float" and kind <> "roFloat" and kind <> "Double" and kind <> "roDouble" then return phoneSetupFailure(400, "bad_request")
    if envelope.v <> 1 then return phoneSetupFailure(400, "bad_request")
    phonePk = phoneSetupBase64(envelope.phonePk)
    nonce = phoneSetupBase64(envelope.nonce)
    ciphertext = phoneSetupBase64(envelope.ciphertext)
    if phonePk = invalid or nonce = invalid or ciphertext = invalid then return phoneSetupFailure(400, "bad_request")
    if phonePk.size <> 32 or nonce.size <> 12 or ciphertext.size <= 16 then return phoneSetupFailure(400, "bad_request")
    return {ok: true, phonePk: phonePk, nonce: nonce, ciphertext: ciphertext}
end function

' Called with a complete HTTP head, including CRLF CRLF. The socket owner must
' bound bytes as they arrive and close incomplete/idle connections after 15 s.
' unavailable covers used/expired/closed sessions; it is never a wire error name.
function validatePhoneSetupRequestHead(head as string, unavailable as boolean) as object
    crlf = chr(13) + chr(10)
    if len(head) > 32768 or right(head, 4) <> crlf + crlf then return phoneSetupFailure(400, "bad_request")
    lines = head.split(crlf)
    request = lines[0].split(" ")
    if request.count() <> 3 then return phoneSetupFailure(400, "bad_request")
    path = request[1].split("?")[0]
    if request[0] <> "POST" or path <> "/setup" then return phoneSetupFailure(404, "bad_request")
    headers = {}
    duplicateLength = false
    for i = 1 to lines.count() - 3
        colon = instr(1, lines[i], ":")
        if colon <= 1 then return phoneSetupFailure(400, "bad_request")
        name = lcase(left(lines[i], colon - 1))
        if not CreateObject("roRegex", "^[!#$%&'*+.^_`|~0-9a-z-]+$", "").isMatch(name) then return phoneSetupFailure(400, "bad_request")
        if name = "content-length" and headers.doesExist(name) then duplicateLength = true
        headers[name] = mid(lines[i], colon + 1).trim()
    end for
    if headers.doesExist("origin") or unavailable then return phoneSetupFailure(403, "forbidden")
    lengthText = headers["content-length"]
    if lengthText <> invalid
        if not CreateObject("roRegex", "^[0-9]+$", "").isMatch(lengthText) then return phoneSetupFailure(400, "bad_request")
        ' Compare as decimal text before toInt so oversized lengths cannot wrap.
        while len(lengthText) > 1 and left(lengthText, 1) = "0"
            lengthText = mid(lengthText, 2)
        end while
        if len(lengthText) > 6 then return phoneSetupFailure(413, "too_large")
        if len(lengthText) = 6 and lengthText > "262144" then return phoneSetupFailure(413, "too_large")
    end if
    if lengthText = invalid or duplicateLength or headers.doesExist("transfer-encoding") then return phoneSetupFailure(400, "bad_request")
    if request[2] <> "HTTP/1.1" then return phoneSetupFailure(400, "bad_request")
    return {ok: true, contentLength: lengthText.toInt()}
end function

' Decrypted JSON object only. A crypto adapter must verify the GCM tag AND
' strict UTF-8 before ParseJson, then call this before consuming the code.
' No credentials are persisted, no sign-in is attempted, and sync is only data.
function validatePhoneSetupPayload(raw as dynamic) as object
    failure = phoneSetupFailure(400, "bad_request")
    if type(raw) <> "roAssociativeArray" then return failure
    playlist = phoneSetupFields(raw.playlist, [
        ["type", "string"], ["name", "string"], ["url", "string"], ["xmltvUrl", "string"]
        ["localUrl", "string"], ["userAgent", "string"], ["guideDays", "int"]
        ["catchupOffsetMinutes", "int"], ["vodEnabled", "bool"], ["channelProfileIds", "array"]
    ], {guideDays: 7, catchupOffsetMinutes: 0, vodEnabled: true, channelProfileIds: []})
    if playlist = invalid then return failure
    for each field in ["type", "name", "url"]
        if playlist[field] = invalid then return failure
        if playlist[field] = "" then return failure
    end for
    if playlist.type <> "dispatcharr" and playlist.type <> "xtream" and playlist.type <> "m3u" then return failure
    if playlist.guideDays < 0 or playlist.guideDays > 14 then return failure
    ids = []
    for each id in playlist.channelProfileIds
        if not phoneSetupTypeMatches(id, "int") then return failure
        ids.push(id)
    end for
    playlist.channelProfileIds = ids
    if raw.playlist.credential <> invalid
        credential = phoneSetupCredential(raw.playlist.credential)
        if credential = invalid then return failure
        playlist.credential = credential
    end if
    profiles = []
    if raw.profiles <> invalid
        if type(raw.profiles) <> "roArray" then return failure
        for each entry in raw.profiles
            profile = phoneSetupProfile(entry)
            if profile = invalid then return failure
            profiles.push(profile)
        end for
    end if
    payload = {playlist: playlist, profiles: profiles}
    if raw.sync <> invalid
        sync = phoneSetupFields(raw.sync, [["provider", "string"], ["enabled", "bool"]], {})
        if sync = invalid then return failure
        if sync.provider = invalid or sync.enabled = invalid then return failure
        payload.sync = sync
    end if
    return {ok: true, payload: payload}
end function

function phoneSetupCredential(raw as dynamic) as dynamic
    return phoneSetupFields(raw, [["apiKey", "string"], ["username", "string"], ["password", "string"]], {})
end function

function phoneSetupProfile(raw as dynamic) as dynamic
    profile = phoneSetupFields(raw, [
        ["username", "string"], ["displayName", "string"], ["role", "string"], ["order", "int"]
        ["isDefault", "bool"], ["pinType", "string"], ["pinHash", "string"], ["pinSalt", "string"]
    ], {role: "", order: -1, isDefault: false, pinType: "none", pinHash: "", pinSalt: ""})
    if profile = invalid then return invalid
    if profile.username = invalid or profile.displayName = invalid then return invalid
    if profile.role <> "" and profile.role <> "admin" and profile.role <> "user" and profile.role <> "child" then return invalid
    if profile.pinType <> "none" and profile.pinType <> "numbers" and profile.pinType <> "directions" then return invalid
    hashValid = CreateObject("roRegex", "^[0-9a-fA-F]{64}$", "").isMatch(profile.pinHash)
    saltValid = CreateObject("roRegex", "^[0-9a-fA-F]{32}$", "").isMatch(profile.pinSalt)
    if not hashValid or not saltValid then profile.pinType = "none"
    if profile.pinType = "none"
        profile.pinHash = ""
        profile.pinSalt = ""
    end if
    if raw.avatar <> invalid
        avatar = phoneSetupFields(raw.avatar, [["icon", "string"], ["color", "string"]], {})
        if avatar = invalid then return invalid
        profile.avatar = avatar
    end if
    if raw.credential <> invalid
        credential = phoneSetupCredential(raw.credential)
        if credential = invalid then return invalid
        profile.credential = credential
    end if
    return profile
end function

' Wire names must be string values, not literal-AA schema keys: native Roku
' lowercases enumerated literal keys, but ParseJson preserves mixed-case keys.
' Copy only known fields; null means absent, never coerce strings or booleans.
function phoneSetupFields(raw as dynamic, schema as object, defaults as object) as dynamic
    if type(raw) <> "roAssociativeArray" then return invalid
    result = {}
    result.append(defaults)
    for each spec in schema
        field = spec[0]
        value = raw[field]
        if value <> invalid
            if not phoneSetupTypeMatches(value, spec[1]) then return invalid
            result[field] = value
        end if
    end for
    return result
end function

function phoneSetupTypeMatches(value as dynamic, expected as string) as boolean
    kind = type(value)
    if expected = "string" then return kind = "String" or kind = "roString"
    if expected = "bool" then return kind = "Boolean" or kind = "roBoolean"
    if expected = "array" then return kind = "roArray"
    if expected = "int"
        if kind = "Integer" or kind = "roInt" or kind = "LongInteger" or kind = "roLongInteger" then return true
        if kind = "Float" or kind = "roFloat" or kind = "Double" or kind = "roDouble" then return value = fix(value)
    end if
    return false
end function

' Accept standard or URL-safe alphabets, padded or not. Validate unused bits
' before the native crypto adapter decodes the canonical padded string.
function phoneSetupBase64(value as dynamic) as dynamic
    if type(value) <> "String" and type(value) <> "roString" then return invalid
    if value = "" or len(value) > 262144 then return invalid
    canonical = value.replace("-", "+").replace("_", "/")
    if not CreateObject("roRegex", "^[A-Za-z0-9+/]+={0,2}$", "").isMatch(canonical) then return invalid
    unpadded = canonical.replace("=", "")
    remainder = len(unpadded) mod 4
    if remainder = 1 then return invalid
    padding = ""
    if remainder = 2 then padding = "=="
    if remainder = 3 then padding = "="
    if canonical <> unpadded and canonical <> unpadded + padding then return invalid
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    lastValue = instr(1, alphabet, right(unpadded, 1)) - 1
    if remainder = 2 and lastValue mod 16 <> 0 then return invalid
    if remainder = 3 and lastValue mod 4 <> 0 then return invalid
    return {encoded: unpadded + padding, size: int(len(unpadded) * 3 / 4)}
end function

' nowSeconds must come from a monotonic clock. generation identifies a fresh
' code/key pair; this model never generates either and never stores secrets.
function newPhoneSetupSession(generation as string, nowSeconds as integer) as object
    return {generation: generation, startedAt: nowSeconds, expiresAt: nowSeconds + 600, failures: 0, used: false, closed: false, cancelled: false}
end function

function phoneSetupSessionGate(session as object, generation as string, nowSeconds as integer) as object
    if session.closed or session.used or generation = "" or generation <> session.generation then return phoneSetupFailure(403, "forbidden")
    if nowSeconds < session.startedAt or nowSeconds >= session.expiresAt then return phoneSetupFailure(403, "expired")
    return {ok: true}
end function

' Call only on a serialized receiver owner, rechecking after async decryption.
' accepted means AEAD authentication AND payload validation already succeeded.
' A closed generation must be replaced with fresh keys before advertising again.
function finishPhoneSetupAttempt(session as object, generation as string, nowSeconds as integer, outcome as string) as object
    nextSession = phoneSetupSessionCopy(session)
    result = phoneSetupSessionGate(session, generation, nowSeconds)
    result.session = nextSession
    result.rotateRequired = false
    if not result.ok then return result
    if outcome = "accepted"
        nextSession.used = true
        result.status = 200
        return result
    end if
    result.ok = false
    result.status = 400
    result.error = "bad_request"
    if outcome = "wrong_code"
        result.status = 403
        result.error = "wrong_code"
        nextSession.failures++
        if nextSession.failures >= 3
            nextSession.closed = true
            result.rotateRequired = true
        end if
    end if
    return result
end function

function cancelPhoneSetupSession(session as object) as object
    result = phoneSetupSessionCopy(session)
    result.closed = true
    result.cancelled = true
    return result
end function

' Invoke only AFTER writing the third wrong_code response and generating new
' keys/code. The serialized listener keeps its port and waits during rotation.
function rotatePhoneSetupSession(session as object, generation as string, nowSeconds as integer) as object
    if session.used or session.cancelled = true or not session.closed or session.failures <> 3 then return phoneSetupFailure(403, "forbidden")
    if generation = "" or generation = session.generation then return phoneSetupFailure(403, "forbidden")
    if nowSeconds < session.startedAt or nowSeconds >= session.expiresAt then return phoneSetupFailure(403, "expired")
    result = phoneSetupSessionCopy(session)
    result.generation = generation
    result.failures = 0
    result.closed = false
    return {ok: true, session: result}
end function

function phoneSetupSessionCopy(session as object) as object
    return {generation: session.generation, startedAt: session.startedAt, expiresAt: session.expiresAt, failures: session.failures, used: session.used, closed: session.closed, cancelled: session.cancelled = true}
end function

function phoneSetupFailure(status as integer, reason as string) as object
    return {ok: false, status: status, error: reason}
end function
