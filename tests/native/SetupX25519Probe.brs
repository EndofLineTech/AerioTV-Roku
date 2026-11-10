' Standalone synthetic-only benchmark. Never reads registry or listens on LAN.
sub Main()
    port = CreateObject("roMessagePort")
    screen = CreateObject("roSGScreen")
    screen.setMessagePort(port)
    scene = screen.createScene("PhoneSetupProbe")
    screen.show()
    print "[setup-x25519] "; formatJson({numeric: true, intCarry: int(34359738367.0# / 32768.0#), integerDivide: 34359738367.0# \ 32768.0#})
    rows = parseJson(ReadAsciiFile("pkg:/x25519-fixtures.json"))
    allPassed = true
    maximumMs = 0
    for each row in rows
        timer = CreateObject("roTimespan")
        timer.mark()
        ' Exercise the exact native private-key encoding used by NewMaterial,
        ' not only lowercase fixture strings. Native ToHexString is uppercase.
        nativeSecret = CreateObject("roByteArray")
        nativeSecret.fromHexString(row.secret)
        actual = setupX25519(setupX25519HexBytes(nativeSecret.toHexString()), setupX25519HexBytes(row.peer))
        elapsed = timer.totalMilliseconds()
        passed = setupX25519Hex(actual) = row.expected
        allPassed = allPassed and passed
        if elapsed > maximumMs then maximumMs = elapsed
        print "[setup-x25519] "; formatJson({id: row.id, passed: passed, elapsedMs: elapsed, syntheticActual: setupX25519Hex(actual)})
        scene.findNode("results").text = "Synthetic X25519 benchmark" + chr(10) + row.id + chr(10) + elapsed.toStr() + " ms"
    end for
    device = CreateObject("roDeviceInfo")
    os = device.getOSVersion()
    print "[setup-x25519] "; formatJson({complete: true, passed: allPassed, maximumMs: maximumMs, model: device.getModel(), os: os.major + "." + os.minor + "." + os.revision})
    print "[setup-x25519] complete-v1"
    while true
        event = wait(0, port)
        if type(event) = "roSGScreenEvent"
            if event.isScreenClosed() then exit while
        end if
    end while
end sub
