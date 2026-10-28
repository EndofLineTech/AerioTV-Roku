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
    if phonePk.size <> 32 or nonce.size <> 12 or ciphertext.size < 16 then return phoneSetupFailure(400, "bad_request")
    return {ok: true, phonePk: phonePk, nonce: nonce, ciphertext: ciphertext}
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
    return {generation: generation, startedAt: nowSeconds, expiresAt: nowSeconds + 600, failures: 0, used: false, closed: false}
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
    return result
end function

function phoneSetupSessionCopy(session as object) as object
    return {generation: session.generation, startedAt: session.startedAt, expiresAt: session.expiresAt, failures: session.failures, used: session.used, closed: session.closed}
end function

function phoneSetupFailure(status as integer, reason as string) as object
    return {ok: false, status: status, error: reason}
end function
