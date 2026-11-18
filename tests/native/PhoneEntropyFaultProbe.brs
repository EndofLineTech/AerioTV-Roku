' Private native fault adapter; the real receiver Task never uses these factories.
sub init()
    m.top.functionName = "runEntropyFaultChecks"
end sub

sub runEntropyFaultChecks()
    checks = []
    resetEntropyFaultDevice()
    checks.push(phoneSetupRandomBytes(0) = invalid and phoneSetupRandomBytes(33) = invalid and m.entropyFaultDevice.calls = 0)
    draw = phoneSetupRandomBytes(32)
    checks.push(type(draw) = "roByteArray" and draw.count() = 32)
    checks.push(phoneSetupRandomBytes(4) = invalid)
    resetEntropyFaultDevice()
    for i = 1 to 8
        m.entropyFaultDevice.ciphertext.fromHexString("0" + i.toStr() + string(62, "a"))
        draw = phoneSetupRandomBytes(4)
        checks.push(type(draw) = "roByteArray" and draw.count() = 4)
    end for
    m.entropyFaultDevice.ciphertext.fromHexString("01" + string(62, "a"))
    checks.push(phoneSetupRandomBytes(32) = invalid)
    resetEntropyFaultDevice()
    m.entropyFaultDevice.ciphertext = invalid
    checks.push(phoneSetupRandomBytes(32) = invalid)
    resetEntropyFaultDevice()
    m.entropyFaultDevice.ciphertext = CreateObject("roByteArray")
    checks.push(phoneSetupRandomBytes(32) = invalid)
    resetEntropyFaultDevice()
    m.entropyFaultDevice.badRoundtrip = true
    checks.push(phoneSetupRandomBytes(32) = invalid)
    m.phoneSetupDeviceCryptoFactory = function() as dynamic
        return invalid
    end function
    checks.push(phoneSetupRandomBytes(32) = invalid)
    m.phoneSetupDeviceCryptoFactory = invalid
    m.phoneSetupRecentDraws = invalid
    m.entropyFaultDevice = invalid
    draw = phoneSetupRandomBytes(32)
    checks.push(type(draw) = "roByteArray" and draw.count() = 32)
    draw = phoneSetupRandomBytes(4)
    checks.push(type(draw) = "roByteArray" and draw.count() = 4)
    passed = true
    for each result in checks
        if result <> true then passed = false
    end for
    m.top.result = {passed: passed, checks: checks.count()}
end sub

sub resetEntropyFaultDevice()
    m.phoneSetupRecentDraws = invalid
    m.entropyFaultDevice = {calls: 0, ciphertext: CreateObject("roByteArray"), badRoundtrip: false, encrypt: function(input as object, key as string) as dynamic
        if key <> "device" then return invalid
        m.calls++
        m.input = input
        return m.ciphertext
    end function, decrypt: function(encrypted as object, key as string) as dynamic
        if m.badRoundtrip then return invalid
        return m.input
    end function}
    m.entropyFaultDevice.ciphertext.fromHexString(string(64, "a"))
    m.phoneSetupDeviceCryptoFactory = function() as dynamic
        return m.entropyFaultDevice
    end function
end sub
