sub main()
    for each version in [{major: "14", minor: "6"}, {major: "14", minor: "10"}, {major: "15", minor: "0"}, {major: 16, minor: 0}]
        check(userProfileRuntimeSupported(version), "OS14.6 or later supports precise sync JSON")
    end for
    for each version in [invalid, {}, {major: "14", minor: "5"}, {major: "13", minor: "99"}, {major: "future", minor: "0"}, {major: "15", minor: "bad"}]
        check(not userProfileRuntimeSupported(version), "unknown/older runtime refuses before profile work")
    end for
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
