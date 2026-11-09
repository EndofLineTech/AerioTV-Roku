' Shipping gate: no documented CSPRNG callable by this BrightScript channel has
' been established. Never substitute Rnd, UUIDs, fixture keys, or server entropy.
' A supported local source must return exactly count bytes, or invalid on error.
' Isolated native probes replace this file, never a flag on the shipping Task.
function phoneSetupRandomBytes(count as integer) as dynamic
    return invalid
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
