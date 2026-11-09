sub main()
    crlf = chr(13) + chr(10)
    reader = newPhoneSetupReader()
    phoneSetupFeed(reader, asciiBytes("POST /setup HTTP/1.1" + crlf + "Content-Length: 2" + crlf), false)
    check(not reader.ready and not reader.headDone, "fragmented head waits")
    phoneSetupFeed(reader, asciiBytes(crlf + "{"), false)
    check(reader.headDone and not reader.ready and reader.body.count() = 1, "partial body waits")
    phoneSetupFeed(reader, asciiBytes("}" + "extra pipeline ignored"), false)
    check(reader.ready and reader.body.count() = 2, "exact body, ignores pipelined suffix")
    reader = newPhoneSetupReader()
    phoneSetupFeed(reader, asciiBytes("POST /setup HTTP/1.1" + crlf + "Origin:" + crlf + "Content-Length: 999999" + crlf + crlf), false)
    check(reader.response.status = 403 and reader.body.count() = 0, "Origin before oversized body, no allocation")
    reader = newPhoneSetupReader()
    phoneSetupFeed(reader, asciiBytes(string(32769, "x")), false)
    check(reader.response.status = 400 and reader.headBytes = 32769, "unterminated head capped while reading")
    reader = newPhoneSetupReader()
    phoneSetupFeed(reader, asciiBytes("POST /setup HTTP/1.1" + crlf + "Content-Length: 0" + crlf + crlf), false)
    check(reader.ready, "zero-length body immediately ready for envelope rejection")
    check(phoneSetupUtf8Valid([65, 194, 169, 226, 130, 172, 240, 159, 152, 128]), "valid UTF8 ranges")
    for each bytes in [[255], [128], [192, 128], [224, 128, 128], [237, 160, 128], [244, 144, 128, 128], [245, 128, 128, 128], [226, 130], [65, 0, 66]]
        check(not phoneSetupUtf8Valid(bytes), "invalid UTF8 or raw NUL rejected before conversion")
    end for
    check(phoneSetupCodeFromDraw([123, 0, 0, 0]) = "000123", "leading-zero code")
    check(phoneSetupCodeFromDraw([127, 61, 241, 255]) = "999999", "large uint32 exact modulo")
    check(phoneSetupCodeFromDraw([128, 61, 241, 255]) = invalid, "rejection threshold")
    check(phoneSetupCodeFromDraw([255, 255, 255, 255]) = invalid, "uint32 max rejected")
    response = phoneSetupHttpResponse(403, "wrong_code")
    check(instr(1, response, "Connection: close" + crlf) > 0, "reply closes connection")
    check(instr(1, response, "Content-Length: 33" + crlf) > 0, "reply byte length exact")
    check(right(phoneSetupHttpResponse(200, ""), 11) = "{""ok"":true}", "success JSON")
    check(phoneSetupNameBytes(asciiBytes(string(61, "a"))).count() = 60, "ASCII friendly name limited to 60 code points")
    name = []
    for i = 0 to 20
        for each value in [240, 159, 152, 128]
            name.push(value)
        end for
    end for
    limited = phoneSetupNameBytes(name)
    check(limited.count() = 60 and phoneSetupUtf8Valid(limited), "UTF8 byte cap never splits a four-byte code point")
    check(phoneSetupPercentEncode([65, 32, 38, 240, 159, 152, 128]) = "A%20%26%F0%9F%98%80", "friendly name encoded byte-for-byte")
    check(phoneSetupPercentEncode(asciiBytes("a~._-9")) = "a~._-9", "ASCII unreserved bytes remain bare")
    link = phoneSetupLink("192.0.2.1", 12345, "000123", "ab+/==", [65, 32, 66])
    check(instr(1, link, "&pk=ab-_&name=A%20B") > 0, "URL-safe public key and percent-encoded name")
    print "ALL TESTS PASSED"
end sub

function asciiBytes(text as string) as object
    result = []
    for i = 1 to len(text)
        result.push(asc(mid(text, i, 1)))
    end for
    return result
end function

sub check(condition as boolean, message as string)
    if not condition
        print "FAIL: "; message
        stop
    end if
end sub
