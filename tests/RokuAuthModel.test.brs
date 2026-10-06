sub main()
    assertEqual(rokuSharedEmail({email: "  viewer@example.com  "}), "viewer@example.com", "consented Roku email can prefill sign-in")
    assertEqual(rokuSharedEmail(invalid), "", "RFI denial does not create an email")
    assertEqual(rokuSharedEmail({email: "not-an-email"}), "", "bad Roku response is ignored")
    assertEqual(rokuSharedEmail({email: "bad@example.com" + chr(10)}), "", "control characters cannot enter a provider login")
    large = ""
    for i = 1 to 250
        large += "a"
    end for
    assertEqual(rokuSharedEmail({email: large + "@example.com"}), "", "oversize email is ignored")
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label
        stop
    end if
end sub
