' No plaintext is exposed to the caller until GCM Final succeeds and UTF8/JSON
' and payload validation pass. Secrets stay in the receiver Task's memory.
function phoneSetupOpen(body as string, material as object, cancelled = invalid as dynamic) as object
    envelope = validatePhoneSetupEnvelope(body, false)
    if not envelope.ok then return envelope
    phonePk = phoneSetupDecode(envelope.phonePk.encoded)
    shared = setupX25519(setupX25519HexBytes(material.privateHex), phonePk, cancelled)
    if shared = invalid then return phoneSetupFailure(403, "forbidden")
    nonzero = false
    for each value in shared
        if value <> 0 then nonzero = true
    end for
    if not nonzero then return phoneSetupFailure(400, "bad_request")
    salt = CreateObject("roByteArray")
    salt.fromAsciiString(material.code)
    hmac = CreateObject("roHMAC")
    if hmac.setup("sha256", salt) <> 0 then return phoneSetupFailure(403, "forbidden")
    prk = hmac.process(phoneSetupHexBytes(setupX25519Hex(shared)))
    shared = invalid
    if type(prk) <> "roByteArray" then return phoneSetupFailure(403, "forbidden")
    info = CreateObject("roByteArray")
    info.fromAsciiString("aeriotv-setup-v1")
    info.append(phonePk)
    info.append(phoneSetupHexBytes(material.publicHex))
    info.push(1)
    if hmac.setup("sha256", prk) <> 0 then return phoneSetupFailure(403, "forbidden")
    key = hmac.process(info)
    prk = invalid
    hmac = invalid
    if type(key) <> "roByteArray" then return phoneSetupFailure(403, "forbidden")
    sealed = phoneSetupDecode(envelope.ciphertext.encoded)
    encoded = sealed.toHexString()
    ciphertext = phoneSetupHexBytes(left(encoded, len(encoded) - 32))
    tag = phoneSetupHexBytes(right(encoded, 32))
    nonce = phoneSetupDecode(envelope.nonce.encoded)
    cipher = CreateObject("roEVPCipher")
    if cipher.setup(false, "aes-256-gcm", key.toHexString(), nonce.toHexString(), 0) <> 0 then return phoneSetupFailure(403, "forbidden")
    key = invalid
    cipher.setTag(tag)
    plaintext = cipher.update(ciphertext)
    tail = cipher.final()
    cipher = invalid
    if type(plaintext) <> "roByteArray" or type(tail) <> "roByteArray" then return phoneSetupFailure(403, "wrong_code")
    plaintext.append(tail)
    if not phoneSetupUtf8Valid(plaintext) then return phoneSetupFailure(400, "bad_request")
    result = validatePhoneSetupPayload(parseJson(plaintext.toAsciiString()))
    plaintext = invalid
    return result
end function

function phoneSetupHexBytes(text as string) as object
    bytes = CreateObject("roByteArray")
    bytes.fromHexString(text)
    return bytes
end function

function phoneSetupDecode(text as string) as object
    bytes = CreateObject("roByteArray")
    bytes.fromBase64String(text)
    return bytes
end function

function phoneSetupFingerprint(publicHex as string) as string
    digest = CreateObject("roEVPDigest")
    digest.setup("sha256")
    hash = lcase(digest.process(phoneSetupHexBytes(publicHex)))
    alphabet = "0123456789abcdef"
    value = 0
    for i = 1 to 5
        value = value * 16 + instr(1, alphabet, mid(hash, i, 1)) - 1
    end for
    alphabet = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
    result = ""
    for i = 3 to 0 step -1
        result += mid(alphabet, int(value / (32 ^ i)) mod 32 + 1, 1)
    end for
    return result
end function
