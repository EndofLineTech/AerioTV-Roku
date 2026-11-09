' Synthetic offline X25519 -> HKDF -> authenticated GCM -> payload validation.
' Not a listener, production decoder, credential importer, or entropy source.
sub Main()
    port = CreateObject("roMessagePort")
    screen = CreateObject("roSGScreen")
    screen.setMessagePort(port)
    scene = screen.createScene("PhoneSetupProbe")
    screen.show()
    rows = parseJson(ReadAsciiFile("pkg:/handoff-fixtures.json"))
    allPassed = true
    maximumMs = 0
    for each row in rows
        timer = CreateObject("roTimespan")
        timer.mark()
        passed = setupHandoffCheck(row)
        elapsed = timer.totalMilliseconds()
        allPassed = allPassed and passed
        if elapsed > maximumMs then maximumMs = elapsed
        print "[setup-handoff] "; formatJson({id: row.id, passed: passed, elapsedMs: elapsed, stage: m.setupHandoffStage})
        scene.findNode("results").text = "Synthetic setup decrypt" + chr(10) + row.id + chr(10) + elapsed.toStr() + " ms"
    end for
    print "[setup-handoff] "; formatJson({complete: true, passed: allPassed, maximumMs: maximumMs})
    print "[setup-handoff] complete-v1"
    while true
        event = wait(0, port)
        if type(event) = "roSGScreenEvent"
            if event.isScreenClosed() then exit while
        end if
    end while
end sub

function setupHandoffCheck(row as object) as boolean
    m.setupHandoffStage = "envelope"
    envelope = validatePhoneSetupEnvelope(row.envelopeJson, false)
    if not envelope.ok then return false
    m.setupHandoffStage = "shared"
    phonePk = CreateObject("roByteArray")
    phonePk.fromBase64String(envelope.phonePk.encoded)
    shared = setupX25519(setupX25519HexBytes(row.secret), phonePk)
    nonzero = false
    for each value in shared
        if value <> 0 then nonzero = true
    end for
    if not nonzero then return false
    m.setupHandoffStage = "hkdf-extract"
    salt = CreateObject("roByteArray")
    salt.fromAsciiString(row.code)
    sharedBytes = setupHandoffBytes(setupX25519Hex(shared))
    hmac = CreateObject("roHMAC")
    if hmac.setup("sha256", salt) <> 0 then return false
    prk = hmac.process(sharedBytes)
    if type(prk) <> "roByteArray" then return false
    if lcase(prk.toHexString()) <> row.prkHex then return false
    m.setupHandoffStage = "hkdf-expand"
    info = CreateObject("roByteArray")
    info.fromAsciiString("aeriotv-setup-v1")
    info.append(phonePk)
    info.append(setupHandoffBytes(row.tvPublicHex))
    info.push(1)
    if hmac.setup("sha256", prk) <> 0 then return false
    key = hmac.process(info)
    if type(key) <> "roByteArray" then return false
    if lcase(key.toHexString()) <> row.keyHex then return false
    m.setupHandoffStage = "gcm"
    nonce = CreateObject("roByteArray")
    nonce.fromBase64String(envelope.nonce.encoded)
    sealed = CreateObject("roByteArray")
    sealed.fromBase64String(envelope.ciphertext.encoded)
    sealedHex = sealed.toHexString()
    body = setupHandoffBytes(left(sealedHex, len(sealedHex) - 32))
    tag = setupHandoffBytes(right(sealedHex, 32))
    cipher = CreateObject("roEVPCipher")
    if cipher.setup(false, "aes-256-gcm", key.toHexString(), nonce.toHexString(), 0) <> 0 then return false
    cipher.setTag(tag)
    plaintext = cipher.update(body)
    tail = cipher.final()
    if type(tail) <> "roByteArray" or type(plaintext) <> "roByteArray" then return false
    plaintext.append(tail)
    m.setupHandoffStage = "plaintext"
    ' Fixtures are ASCII-only; strict external UTF-8 validation is still needed
    ' before this conversion in a real receiver. Never parse before Final.
    if plaintext.toAsciiString() <> row.plaintext then return false
    m.setupHandoffStage = "payload"
    raw = parseJson(plaintext.toAsciiString())
    accepted = validatePhoneSetupPayload(raw).ok
    if not accepted
        ' Type-only synthetic diagnostics, never values or credential content.
        if raw.profiles <> invalid
            for each profile in raw.profiles
                if phoneSetupProfile(profile) = invalid
                    m.setupHandoffStage = "profile"
                    print "[setup-handoff] "; formatJson({diagnostic: true, orderType: type(profile.order), defaultType: type(profile.isDefault), roleType: type(profile.role)})
                end if
            end for
        end if
    end if
    if not accepted then return false
    normalized = validatePhoneSetupPayload(raw).payload
    for each field in ["guideDays", "catchupOffsetMinutes", "vodEnabled", "xmltvUrl", "localUrl", "userAgent"]
        if raw.playlist[field] <> invalid
            if normalized.playlist[field] <> raw.playlist[field] then return false
        end if
    end for
    if raw.playlist.credential <> invalid
        for each field in ["apiKey", "username", "password"]
            if normalized.playlist.credential[field] <> raw.playlist.credential[field] then return false
        end for
    end if
    for i = 0 to normalized.profiles.count() - 1
        for each field in ["username", "displayName", "role", "order", "isDefault", "pinType", "pinHash", "pinSalt"]
            if normalized.profiles[i][field] <> raw.profiles[i][field] then return false
        end for
    end for
    return true
end function

function setupHandoffBytes(value as string) as object
    result = CreateObject("roByteArray")
    result.fromHexString(value)
    return result
end function
