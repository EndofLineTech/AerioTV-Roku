' Standalone synthetic probe. Does not read app registry, import credentials,
' advertise setup, receive LAN payloads, or infer authenticated GCM from Setup.
sub Main()
    port = CreateObject("roMessagePort")
    screen = CreateObject("roSGScreen")
    screen.setMessagePort(port)
    scene = screen.createScene("PhoneSetupProbe")
    screen.show()
    phoneProbeMatrix()
    device = CreateObject("roDeviceInfo")
    os = device.getOSVersion()
    lines = ["Model " + device.getModel() + " / OS " + os.major + "." + os.minor + "." + os.revision]
    lines.push("HMAC-SHA256 RFC 4231: " + phoneProbeResult(phoneProbeHmac()))
    lines.push("HKDF-SHA256 RFC 5869: " + phoneProbeResult(phoneProbeHkdf()))
    lines.push("AES-256 block NIST SP 800-38A: " + phoneProbeResult(phoneProbeAes()))
    for each format in ["aes-gcm-128", "aes-256-gcm", "aes-gcm-256"]
        cipher = CreateObject("roEVPCipher")
        status = -1
        if cipher <> invalid
            key = string(64, "0")
            if format = "aes-gcm-128" then key = string(32, "0")
            status = cipher.setup(false, format, key, string(24, "0"), 0)
        end if
        lines.push(format + " Setup status: " + status.toStr() + " (NOT tag verification)")
    end for
    lines.push("AES-256-GCM synthetic encrypt: " + phoneProbeGcm(true, "00000000000000000000000000000000"))
    lines.push("AES-256-GCM cipher only: " + phoneProbeGcm(false, "cea7403d4d606b6e074ec5d3baf39d18"))
    lines.push("AES-256-GCM cipher + valid tag: " + phoneProbeGcm(false, "cea7403d4d606b6e074ec5d3baf39d18d0d1c8a799996bf0265b98b5d48ab919"))
    lines.push("AES-256-GCM cipher + changed tag: " + phoneProbeGcm(false, "cea7403d4d606b6e074ec5d3baf39d18d0d1c8a799996bf0265b98b5d48ab918"))
    lines.push("Loopback ephemeral TCP bind/listen: " + phoneProbeResult(phoneProbeSocket(port)))
    fixture = {v: 1, phonePk: "//////////////////////////////////////////8=", nonce: "AAAAAAAAAAAAAAAA", ciphertext: "AAAAAAAAAAAAAAAAAAAAAA=="}
    lines.push("Envelope shape only: " + phoneProbeResult(validatePhoneSetupEnvelope(formatJson(fixture), false).ok))
    lines.push("GCM explicit setTag/getTag results are in [setup-matrix]; legacy calls above omit tag APIs.")
    lines.push("NOT PROVEN: X25519, secure random bytes, DNS-SD/QR, phone interop.")
    lines.push("No setup listener remains open. Home exits; reinstall the normal app afterward.")
    text = ""
    for each line in lines
        print "[setup-probe] "; line
        text += line + chr(10)
    end for
    scene.findNode("results").text = text
    print "[setup-probe] complete"
    while true
        event = wait(0, port)
        if type(event) = "roSGScreenEvent"
            if event.isScreenClosed() then exit while
        end if
    end while
end sub

function phoneProbeResult(value as boolean) as string
    if value then return "PASS"
    return "FAIL"
end function

function phoneProbeBytes(hex as string) as object
    result = CreateObject("roByteArray")
    result.fromHexString(hex)
    return result
end function

function phoneProbeMac(key as object, input as object) as dynamic
    hmac = CreateObject("roHMAC")
    if hmac = invalid then return invalid
    if hmac.setup("sha256", key) <> 0 then return invalid
    return hmac.process(input)
end function

function phoneProbeHmac() as boolean
    key = phoneProbeBytes("0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b")
    result = phoneProbeMac(key, phoneProbeBytes("4869205468657265"))
    if result = invalid then return false
    return lcase(result.toHexString()) = "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7"
end function

function phoneProbeHkdf() as boolean
    ' RFC 5869 case 1; verify extraction and both expansion blocks (42 bytes).
    salt = phoneProbeBytes("000102030405060708090a0b0c")
    ikm = phoneProbeBytes("0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b")
    prk = phoneProbeMac(salt, ikm)
    if prk = invalid then return false
    if lcase(prk.toHexString()) <> "077709362c2e32df0ddc3f0dc47bba6390b6c73bb50f9c3122ec844ad7c2b3e5" then return false
    first = phoneProbeMac(prk, phoneProbeBytes("f0f1f2f3f4f5f6f7f8f901"))
    if first = invalid then return false
    second = phoneProbeMac(prk, phoneProbeBytes(first.toHexString() + "f0f1f2f3f4f5f6f7f8f902"))
    if second = invalid then return false
    okm = lcase(first.toHexString() + left(second.toHexString(), 20))
    return okm = "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865"
end function

function phoneProbeAes() as boolean
    cipher = CreateObject("roEVPCipher")
    if cipher = invalid then return false
    key = "603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4"
    if cipher.setup(true, "aes-256-ecb", key, "", 0) <> 0 then return false
    result = cipher.process(phoneProbeBytes("6bc1bee22e409f96e93d7e117393172a"))
    if result = invalid then return false
    return lcase(result.toHexString()) = "f3eed1bdb5d2a03c064b5a7e3db181f8"
end function

function phoneProbeSocket(port as object) as boolean
    socket = CreateObject("roStreamSocket")
    if socket = invalid then return false
    socket.setMessagePort(port)
    addr = CreateObject("roSocketAddress")
    addr.setHostName("127.0.0.1")
    addr.setPort(0)
    bound = socket.setAddress(addr)
    listening = false
    if bound then listening = socket.listen(1)
    result = bound and listening and socket.isListening()
    socket.close()
    return result
end function

function phoneProbeGcm(encrypt as boolean, hex as string) as string
    cipher = CreateObject("roEVPCipher")
    if cipher = invalid then return "unavailable"
    if cipher.setup(encrypt, "aes-256-gcm", string(64, "0"), string(24, "0"), 0) <> 0 then return "setup failed"
    result = cipher.process(phoneProbeBytes(hex))
    if result = invalid then return "invalid (no authenticated result)"
    if type(result) <> "roByteArray" then return "unexpected result type"
    actual = lcase(result.toHexString())
    matched = actual = "00000000000000000000000000000000"
    if encrypt then matched = actual = "cea7403d4d606b6e074ec5d3baf39d18d0d1c8a799996bf0265b98b5d48ab919"
    return "bytes=" + result.count().toStr() + " expected authenticated output=" + phoneProbeResult(matched)
end function
