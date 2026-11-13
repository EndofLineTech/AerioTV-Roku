sub main()
    testSetupPayload()
    testSetupHttpHead()
    envelope = setupFixtureEnvelope()
    body = formatJson(envelope)
    request = validatePhoneSetupEnvelope(body, false)
    check(request.ok, "valid standard base64 envelope")
    check(request.phonePk.size = 32 and request.nonce.size = 12, "decoded lengths")
    envelope.phonePk = "__________________________________________8"
    check(validatePhoneSetupEnvelope(formatJson(envelope), false).ok, "unpadded URL-safe key")
    envelope.phonePk = "__________________________________________8="
    check(validatePhoneSetupEnvelope(formatJson(envelope), false).ok, "padded URL-safe key")
    check(not validatePhoneSetupEnvelope(body, true).ok, "Origin refused")
    check(validatePhoneSetupEnvelope(body, true).error = "forbidden", "Origin status")
    check(validatePhoneSetupEnvelope(string(262145, "x"), false).status = 413, "body capped before JSON parse")
    check(validatePhoneSetupEnvelope("null", false).error = "bad_request", "null rejected")
    check(validatePhoneSetupEnvelope("[]", false).error = "bad_request", "array rejected")
    check(validatePhoneSetupEnvelope("{", false).error = "bad_request", "broken JSON rejected")
    envelope = setupFixtureEnvelope()
    envelope.v = "1"
    check(not validatePhoneSetupEnvelope(formatJson(envelope), false).ok, "version string rejected")
    envelope.v = 2
    check(not validatePhoneSetupEnvelope(formatJson(envelope), false).ok, "future version rejected")
    envelope = setupFixtureEnvelope()
    envelope.phonePk = "AA=="
    check(not validatePhoneSetupEnvelope(formatJson(envelope), false).ok, "short key rejected")
    envelope = setupFixtureEnvelope()
    envelope.nonce = "AA=="
    check(not validatePhoneSetupEnvelope(formatJson(envelope), false).ok, "short nonce rejected")
    envelope = setupFixtureEnvelope()
    envelope.ciphertext = "AA=="
    check(not validatePhoneSetupEnvelope(formatJson(envelope), false).ok, "missing tag rejected")
    envelope.ciphertext = "AAAAAAAAAAAAAAAAAAAAAA=="
    check(not validatePhoneSetupEnvelope(formatJson(envelope), false).ok, "tag-only rejected before crypto")
    for each value in ["!AAA", "A", "AA=A", "AAAA====", "AA==AAAA", "AA A", "AB=="]
        check(phoneSetupBase64(value) = invalid, "invalid or noncanonical base64 rejected")
    end for
    check(phoneSetupBase64(123) = invalid, "nonstring base64 rejected")

    session = newPhoneSetupSession("generation-a", 100)
    check(phoneSetupSessionGate(session, "generation-a", 699).ok, "session before expiry")
    check(phoneSetupSessionGate(session, "generation-a", 700).error = "expired", "exact 10-minute expiry")
    check(phoneSetupSessionGate(session, "generation-b", 101).error = "forbidden", "stale generation")
    check(phoneSetupSessionGate(session, "generation-a", 99).error = "expired", "regressed clock")
    result = finishPhoneSetupAttempt(session, "generation-a", 101, "bad_request")
    check(result.session.failures = 0, "malformed payload does not spend attempt")
    result = finishPhoneSetupAttempt(session, "generation-a", 101, "wrong_code")
    check(result.session.failures = 1 and not result.rotateRequired, "first wrong code")
    check(session.failures = 0, "transition does not mutate old snapshot")
    result = finishPhoneSetupAttempt(result.session, "generation-a", 102, "wrong_code")
    result = finishPhoneSetupAttempt(result.session, "generation-a", 103, "wrong_code")
    check(result.rotateRequired and result.session.closed, "third wrong code closes old key generation")
    check(not phoneSetupSessionGate(result.session, "generation-a", 104).ok, "no fourth attempt on old keys")
    rotated = rotatePhoneSetupSession(result.session, "generation-b", 104)
    check(rotated.ok and rotated.session.failures = 0, "rotation resets attempts")
    check(rotated.session.startedAt = 100 and rotated.session.expiresAt = 700, "rotation never extends session")
    check(not rotatePhoneSetupSession(result.session, "generation-a", 104).ok, "rotation needs a new generation")
    check(not rotatePhoneSetupSession(result.session, "generation-b", 700).ok, "rotation cannot revive expired session")
    check(not rotatePhoneSetupSession(cancelPhoneSetupSession(result.session), "generation-b", 104).ok, "cancel during key generation prevents rotation")
    check(not rotatePhoneSetupSession(cancelPhoneSetupSession(session), "generation-b", 104).ok, "cancel cannot rotate")
    session = newPhoneSetupSession("generation-b", 104)
    check(not finishPhoneSetupAttempt(session, "generation-a", 105, "accepted").ok, "late decrypt cannot consume new session")
    check(not finishPhoneSetupAttempt(session, "generation-b", 704, "accepted").ok, "expiry during decrypt")
    result = finishPhoneSetupAttempt(session, "generation-b", 105, "accepted")
    check(result.ok and result.session.used, "one accepted payload")
    check(not finishPhoneSetupAttempt(result.session, "generation-b", 106, "accepted").ok, "replay refused")
    check(not phoneSetupSessionGate(cancelPhoneSetupSession(session), "generation-b", 105).ok, "cancel closes session")
    check(not finishPhoneSetupAttempt(session, "generation-b", 105, "unexpected").ok, "unknown outcome fails closed")
    print "ALL TESTS PASSED"
end sub

function setupFixtureEnvelope() as object
    return {v: 1, phonePk: "//////////////////////////////////////////8=", nonce: "AAAAAAAAAAAAAAAA", ciphertext: "AAAAAAAAAAAAAAAAAAAAAAA="}
end function

sub testSetupPayload()
    raw = {playlist: {type: "m3u", name: "Home", url: "http://192.168.1.10/a.m3u"}}
    result = validatePhoneSetupPayload(raw)
    check(result.ok, "minimal supplied M3U payload")
    check(result.payload.playlist.guideDays = 7 and result.payload.playlist.vodEnabled, "playlist defaults")
    check(result.payload.playlist.channelProfileIds.count() = 0 and result.payload.profiles.count() = 0, "empty list defaults")
    check(raw.playlist.guideDays = invalid, "validation does not mutate input")
    for each field in ["xmltvUrl", "localUrl", "userAgent", "name", "url", "type", "catchupOffsetMinutes", "vodEnabled", "channelProfileIds", "credential"]
        candidate = parseJson(formatJson(raw))
        candidate.playlist[field] = {}
        if field = "credential" then candidate.playlist[field] = []
        check(not validatePhoneSetupPayload(candidate).ok, "playlist field wrong type: " + field)
    end for
    raw.unknownFutureField = {ignored: true}
    raw.playlist.unknownFutureField = 99
    check(validatePhoneSetupPayload(raw).payload.playlist.unknownFutureField = invalid, "unknown fields ignored")
    for each source in ["dispatcharr", "xtream", "m3u"]
        raw.playlist.type = source
        check(validatePhoneSetupPayload(raw).ok, "all source families accepted")
    end for
    raw.playlist.type = "dispatcharr"
    raw.playlist.credential = {apiKey: "synthetic-api-key-sam-0002"}
    raw.playlist.channelProfileIds = [2, 3, 4]
    raw.profiles = [{username: "sam", displayName: "Sam", isDefault: true, order: 0}]
    raw.sync = {provider: "dispatcharr", enabled: true}
    for each field in ["username", "displayName", "role", "order", "isDefault", "pinType", "pinHash", "pinSalt", "avatar", "credential"]
        candidate = parseJson(formatJson(raw))
        candidate.profiles[0][field] = []
        check(not validatePhoneSetupPayload(candidate).ok, "profile field wrong type: " + field)
    end for
    for each field in ["apiKey", "username", "password"]
        candidate = parseJson(formatJson(raw))
        candidate.playlist.credential[field] = true
        check(not validatePhoneSetupPayload(candidate).ok, "credential field wrong type: " + field)
    end for
    candidate = parseJson(formatJson(raw))
    candidate.sync.enabled = "true"
    check(not validatePhoneSetupPayload(candidate).ok, "sync boolean never coerced")
    result = validatePhoneSetupPayload(raw)
    check(result.ok, "API key needs no playlist username")
    check(result.payload.playlist.channelProfileIds.count() = 3, "multiple channel profile ids retained")
    check(result.payload.profiles[0].pinType = "none", "profile defaults")
    future = parseJson(formatJson(raw))
    future.profiles.push({username: "future", displayName: "Future", role: "future-role", pinType: "future-pin", pinHash: string(64, "a"), pinSalt: string(32, "b")})
    normalized = validatePhoneSetupPayload(future)
    check(normalized.ok, "unknown profile enums do not reject entire payload")
    check(normalized.payload.profiles[1].role = "" and normalized.payload.profiles[1].pinType = "none", "unknown role and PIN type map to safe contract defaults")
    check(normalized.payload.profiles[1].pinHash = "" and normalized.payload.profiles[1].pinSalt = "", "unknown PIN type retains no material")
    result.payload.playlist.channelProfileIds.push(5)
    check(raw.playlist.channelProfileIds.count() = 3, "normalized lists do not alias raw payload")
    check(result.payload.sync.enabled, "sync request preserved, not applied")
    decoded = validatePhoneSetupPayload(parseJson(formatJson(raw)))
    check(decoded.ok, "decoded JSON profile fields retain wire casing")
    check(decoded.payload.playlist.credential.apiKey = "synthetic-api-key-sam-0002", "decoded apiKey retained")
    check(decoded.payload.profiles[0].displayName = "Sam", "decoded displayName retained")
    check(decoded.payload.playlist.channelProfileIds.count() = 3, "decoded channelProfileIds retained")
    raw.profiles[0].pinType = "numbers"
    raw.profiles[0].pinHash = "bad0b4f7cae08eb7c1b5acc763a8ed25242e2c9173e81f3f624b1fa5303cf6ce"
    raw.profiles[0].pinSalt = "000102030405060708090a0b0c0d0e0f"
    check(validatePhoneSetupPayload(raw).payload.profiles[0].pinType = "numbers", "valid v2 PIN metadata")
    raw.profiles[0].pinSalt = "bad"
    result = validatePhoneSetupPayload(raw)
    check(result.ok and result.payload.profiles[0].pinType = "none", "invalid PIN metadata downgraded")
    raw.playlist.guideDays = invalid
    raw.playlist.xmltvUrl = invalid
    raw.sync = invalid
    check(validatePhoneSetupPayload(raw).payload.playlist.guideDays = 7, "null optionals use defaults")
    for each value in ["7", -1, 15, 1.5, true]
        raw.playlist.guideDays = value
        check(not validatePhoneSetupPayload(raw).ok, "invalid guide days rejected")
    end for
    raw.playlist.guideDays = 0
    check(validatePhoneSetupPayload(raw).ok, "all available guide days")
    raw.playlist.channelProfileIds = [2, "3"]
    check(not validatePhoneSetupPayload(raw).ok, "profile ids must be integers")
    raw.playlist.channelProfileIds = []
    raw.profiles = {}
    check(not validatePhoneSetupPayload(raw).ok, "profiles object rejected")
    raw.profiles = [123]
    check(not validatePhoneSetupPayload(raw).ok, "nonobject profile rejected")
    raw.profiles = [{username: "sam"}]
    check(not validatePhoneSetupPayload(raw).ok, "display name required")
    raw.profiles = []
    for each field in ["name", "url", "type"]
        previous = raw.playlist[field]
        raw.playlist[field] = ""
        check(not validatePhoneSetupPayload(raw).ok, "required playlist string not empty")
        raw.playlist[field] = previous
    end for
    raw.playlist.type = "plex"
    check(not validatePhoneSetupPayload(raw).ok, "unknown source rejected")
    for each value in [invalid, [], "not json", {playlist: []}, {}]
        check(not validatePhoneSetupPayload(value).ok, "invalid payload shape rejected")
    end for
end sub

sub testSetupHttpHead()
    crlf = chr(13) + chr(10)
    head = "POST /setup?test=1 HTTP/1.1" + crlf
    check(validatePhoneSetupRequestHead(head + "Content-Length: 262144" + crlf + crlf, false).ok, "exact limit and query allowed")
    check(validatePhoneSetupRequestHead(head + "Content-Length: 262145" + crlf + crlf, false).status = 413, "oversized from header")
    check(validatePhoneSetupRequestHead(head + "Content-Length: 999999999999999999999" + crlf + crlf, false).status = 413, "no content length integer overflow")
    check(validatePhoneSetupRequestHead(head + crlf, false).status = 400, "length required")
    check(validatePhoneSetupRequestHead(head + "Content-Length: 2" + crlf + "Transfer-Encoding:" + crlf + crlf, false).status = 400, "any transfer encoding rejected")
    check(validatePhoneSetupRequestHead(head + "ORIGIN:" + crlf + "Content-Length: 999999" + crlf + crlf, false).status = 403, "empty case insensitive Origin precedes size")
    check(validatePhoneSetupRequestHead("GET /Setup HTTP/1.1" + crlf + "Origin:" + crlf + crlf, true).status = 404, "route precedes forbidden")
    check(validatePhoneSetupRequestHead(head + crlf, true).status = 403, "used or expired session precedes length")
    for each length in ["-1", "+2", "1.5", "2,2", "", "2x"]
        check(validatePhoneSetupRequestHead(head + "Content-Length: " + length + crlf + crlf, false).status = 400, "invalid content length")
    end for
    check(validatePhoneSetupRequestHead(head + "Content-Length: 2" + crlf + "content-length: 2" + crlf + crlf, false).status = 400, "ambiguous duplicate length rejected")
    check(validatePhoneSetupRequestHead(string(32769, "x"), false).status = 400, "head bounded")
end sub

sub check(condition as boolean, label as string)
    if not condition
        print "FAIL: "; label
        stop
    end if
end sub
