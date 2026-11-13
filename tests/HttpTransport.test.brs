sub main()
    checked = "{" + chr(34) + "MixedCase" + chr(34) + ":1.0}"
    request = httpWriteBody(invalid, checked)
    check(request.ok and request.text = checked, "validated raw JSON is posted unchanged, not quoted or reserialized")
    check(not httpWriteBody({unexpected: true}, checked).ok, "ambiguous object and checked raw body is rejected")
    check(not httpWriteBody(invalid, 123).ok, "checked raw body must be string")
    check(httpWriteBody(invalid, 123).hasBody = false, "invalid request retains a total body-plan shape")
    check(httpWriteBody({username: "fixture"}).ok, "existing object-based login body still serializes")
    check(httpWriteBody(invalid).hasBody = false, "GET has no request body")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
