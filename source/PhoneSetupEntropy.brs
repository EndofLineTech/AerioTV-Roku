' Owner-approved Beta device-key source, qualified by functional native tests.
' This does not claim a vendor-documented CSPRNG guarantee. No network, signing
' key changes, registry writes, UUID/Rnd or fixed-key fallback are permitted.
' Ciphertext and its digest are secret material: never log or persist them.
function phoneSetupRandomBytes(count as integer) as dynamic
    if count < 1 or count > 32 then return invalid
    crypto = invalid
    if m.phoneSetupDeviceCryptoFactory <> invalid
        crypto = m.phoneSetupDeviceCryptoFactory()
    else
        crypto = CreateObject("roDeviceCrypto")
    end if
    if crypto = invalid then return invalid
    input = CreateObject("roByteArray")
    input.fromAsciiString("AerioTV/phone-setup/key-material/v1/" + count.toStr())
    encrypted = crypto.encrypt(input, "device")
    if type(encrypted) <> "roByteArray" then return invalid
    if encrypted.count() < 32 then return invalid
    recovered = crypto.decrypt(encrypted, "device")
    crypto = invalid
    if type(recovered) <> "roByteArray" then return invalid
    if recovered.toHexString() <> input.toHexString() then return invalid
    recovered = invalid
    digest = CreateObject("roEVPDigest")
    if digest.setup("sha256") <> 0 then return invalid
    hex = digest.process(encrypted)
    encrypted = invalid
    digest = invalid
    accepted = phoneSetupAcceptDeviceDraw(hex, count)
    hex = ""
    if accepted = invalid then return invalid
    bytes = CreateObject("roByteArray")
    bytes.fromHexString(accepted)
    accepted = ""
    return bytes
end function

function phoneSetupAcceptDeviceDraw(hex as dynamic, count as integer) as dynamic
    if count < 1 or count > 32 then return invalid
    if type(hex) <> "String" and type(hex) <> "roString" then return invalid
    if len(hex) <> 64 then return invalid
    if not CreateObject("roRegex", "^[0-9a-fA-F]{64}$", "").isMatch(hex) then return invalid
    hex = lcase(hex)
    if type(m.phoneSetupRecentDraws) <> "roArray" then m.phoneSetupRecentDraws = []
    for each previous in m.phoneSetupRecentDraws
        if previous = hex then return invalid
    end for
    m.phoneSetupRecentDraws.push(hex)
    if m.phoneSetupRecentDraws.count() > 32 then m.phoneSetupRecentDraws.shift()
    return left(hex, count * 2)
end function

function phoneSetupNewMaterial(cancelled = invalid as dynamic) as dynamic
    raw = phoneSetupRandomBytes(32)
    if type(raw) <> "roByteArray" then return invalid
    if raw.count() <> 32 then return invalid
    digest = CreateObject("roEVPDigest")
    digest.setup("sha256")
    private = phoneSetupHexBytes(digest.process(raw))
    raw = invalid
    private[0] = int(private[0] / 8) * 8
    private[31] = 64 + (private[31] mod 64)
    code = invalid
    for attempt = 0 to 31
        draw = phoneSetupRandomBytes(4)
        if type(draw) <> "roByteArray" then return invalid
        code = phoneSetupCodeFromDraw(draw)
        draw = invalid
        if code <> invalid then exit for
    end for
    if code = invalid then return invalid
    public = setupX25519(private, setupX25519HexBytes("09" + string(62, "0")), cancelled)
    if public = invalid then return invalid
    return {privateHex: private.toHexString(), publicHex: setupX25519Hex(public), code: code}
end function
