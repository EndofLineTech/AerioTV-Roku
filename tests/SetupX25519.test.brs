sub main()
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
