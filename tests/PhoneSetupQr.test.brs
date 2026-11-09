sub main()
    for each fixture in phoneSetupQrFixtures()
        actual = phoneSetupQr(fixture.text)
        if actual = invalid then stop
        for i = 0 to 96
            if actual[i] <> fixture.rows[i]
                print "FAIL QR row "; i
                stop
            end if
        end for
    end for
    if phoneSetupQr(string(383, "x")) <> invalid then stop
    print "ALL TESTS PASSED"
end sub
