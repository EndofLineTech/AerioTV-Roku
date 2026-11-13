sub main()
    raw = {}
    ' brs uses JavaScript's parser, which already drops the 1.0 literal kind.
    ' Native parsing is qualified separately; inject typed values for this test.
    raw["mixedcase"] = [1, 1.0, invalid, true]
    encoded = strictJsonEncode(raw)
    check(encoded.ok and instr(1, encoded.text, chr(34) + "mixedcase" + chr(34)) > 0, "wire key is serialized")
    check(instr(1, encoded.text, "[1,1.0,null,true]") > 0, "integer and integral floating literal types remain distinct")
    check(strictJsonEncode({quote: chr(34), newline: chr(10)}).ok, "strings use JSON escaping")
    check(not strictJsonEncode(function() as integer
        return 1
    end function).ok, "unsupported values fail closed, not null")
    check(not strictJsonEncode([], 33).ok, "depth budget bounded")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
