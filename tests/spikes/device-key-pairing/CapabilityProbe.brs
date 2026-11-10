' Disposable capability measurement, NOT a secret generator. No registry/network.
' Only synthetic plaintext and aggregate booleans/lengths leave this function.
sub Main()
    port = CreateObject("roMessagePort")
    screen = CreateObject("roSGScreen")
    screen.setMessagePort(port)
    scene = screen.createScene("PhoneSetupProbe")
    screen.show()
    device = CreateObject("roDeviceInfo")
    print "[entropy-capability] "; formatJson({kind: "device", model: device.getModel(), os: device.getOSVersion()})
    crypto = CreateObject("roDeviceCrypto")
    print "[entropy-capability] "; formatJson({kind: "component", available: crypto <> invalid})
    if crypto <> invalid
        for each scope in ["device", "channel", "model"]
            for each size in [1, 16, 32, 64]
                input = CreateObject("roByteArray")
                input.fromHexString(string(size * 2, "0"))
                seen = {}
                valid = 0
                roundTrips = 0
                outputBytes = -1
                first = invalid
                for sample = 1 to 8
                    encrypted = crypto.encrypt(input, scope)
                    if type(encrypted) = "roByteArray"
                        valid++
                        outputBytes = encrypted.count()
                        seen[encrypted.toHexString()] = true
                        decoded = crypto.decrypt(encrypted, scope)
                        if type(decoded) = "roByteArray"
                            if decoded.toHexString() = input.toHexString() then roundTrips++
                        end if
                        if first = invalid then first = encrypted
                    end if
                end for
                secondObject = CreateObject("roDeviceCrypto")
                other = secondObject.encrypt(input, scope)
                sameNewObject = invalid
                if type(other) = "roByteArray" and type(first) = "roByteArray"
                    sameNewObject = other.toHexString() = first.toHexString()
                end if
                variablePositions = 0
                tamperRejected = 0
                tamperAccepted = 0
                if type(first) = "roByteArray" and type(other) = "roByteArray"
                    for byteIndex = 0 to first.count() - 1
                        if first[byteIndex] <> other[byteIndex] then variablePositions++
                    end for
                    for each index in [0, 15, 16, first.count() - 1]
                        modified = CreateObject("roByteArray")
                        modified.fromHexString(first.toHexString())
                        modified[index] = (modified[index] + 1) mod 256
                        tampered = crypto.decrypt(modified, scope)
                        if type(tampered) = "roByteArray" then tamperAccepted++ else tamperRejected++
                    end for
                end if
                print "[entropy-capability] "; formatJson({kind: "encryption", scope: scope, inputbytes: size, samples: 8, valid: valid, distinct: seen.count(), roundtrips: roundTrips, outputbytes: outputBytes, samenewobject: sameNewObject, variablepositions: variablePositions, tamperrejected: tamperRejected, tamperaccepted: tamperAccepted})
                input = invalid
                encrypted = invalid
                decoded = invalid
                first = invalid
                other = invalid
                seen = invalid
            end for
        end for
    end if
    ' Measure availability/latency only; randomness quality is NOT inferred.
    if crypto <> invalid
        clock = CreateObject("roTimespan")
        input = CreateObject("roByteArray")
        input.fromAsciiString("AerioTV capability measurement, not a key")
        seen = {}
        successes = 0
        repeats = 0
        clock.mark()
        for sample = 1 to 256
            encrypted = crypto.encrypt(input, "device")
            if type(encrypted) = "roByteArray"
                digest = CreateObject("roEVPDigest")
                digest.setup("sha256")
                key = digest.process(encrypted)
                if seen.doesExist(key) then repeats++
                seen[key] = true
                successes++
            end if
        end for
        print "[entropy-capability] "; formatJson({kind: "latency", samples: 256, valid: successes, repeats: repeats, elapsedms: clock.totalMilliseconds()})
        encrypted = invalid
        key = invalid
        seen = invalid
    end if
    print "[entropy-capability] "; formatJson({kind: "complete"})
    while true
        event = wait(0, port)
        if type(event) = "roSGScreenEvent"
            if event.isScreenClosed() then return
        end if
    end while
end sub
