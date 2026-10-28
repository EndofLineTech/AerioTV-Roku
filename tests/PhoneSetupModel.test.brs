sub main()
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
    return {v: 1, phonePk: "//////////////////////////////////////////8=", nonce: "AAAAAAAAAAAAAAAA", ciphertext: "AAAAAAAAAAAAAAAAAAAAAA=="}
end function

sub check(condition as boolean, label as string)
    if not condition
        print "FAIL: "; label
        stop
    end if
end sub
