' Full-app developer pairing tests only. Not an approved shipping CSPRNG.
' Ciphertext/digests are secret seed material: never log or persist them.
function phoneSetupRandomBytes(count as integer) as dynamic
    if count < 1 or count > 32 then return invalid
    crypto = CreateObject("roDeviceCrypto")
    if crypto = invalid then return invalid
    input = CreateObject("roByteArray")
    input.fromAsciiString("AerioTV/device-key-entropy-experiment/v1/" + count.toStr())
    encrypted = crypto.encrypt(input, "device")
    if type(encrypted) <> "roByteArray" then return invalid
    if encrypted.count() < 32 then return invalid
    recovered = crypto.decrypt(encrypted, "device")
    if type(recovered) <> "roByteArray" then return invalid
    if recovered.toHexString() <> input.toHexString() then return invalid
    digest = CreateObject("roEVPDigest")
    if digest.setup("sha256") <> 0 then return invalid
    hex = digest.process(encrypted)
    encrypted = invalid
    crypto = invalid
    if type(hex) <> "String" and type(hex) <> "roString" then return invalid
    if len(hex) <> 64 then return invalid
    if m.pairingTestPreviousDigest <> invalid
        if m.pairingTestPreviousDigest = hex then return invalid
    end if
    m.pairingTestPreviousDigest = hex
    bytes = CreateObject("roByteArray")
    bytes.fromHexString(left(hex, count * 2))
    hex = ""
    return bytes
end function
