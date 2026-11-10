sub main()
    ' Native roByteArray.ToHexString emits uppercase even though the host
    ' interpreter uses lowercase. Stored in-memory key encodings must round-trip.
    for each encoded in ["ABCDEF0190", "aBcDeF0190", "abcdef0190"]
        if setupX25519Hex(setupX25519HexBytes(encoded)) <> "abcdef0190"
            print "FAIL: hex decoder must accept native uppercase and mixed case"
            stop
        end if
    end for
    for each row in setupX25519TestVectors()
        actual = setupX25519(setupX25519HexBytes(row.secret), setupX25519HexBytes(row.peer))
        if setupX25519Hex(actual) <> row.expected
            print "FAIL: "; row.id
            stop
        end if
        print "PASS: "; row.id
    end for
    print "ALL TESTS PASSED"
end sub
