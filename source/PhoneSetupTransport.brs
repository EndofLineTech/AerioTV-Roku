' One bounded HTTP request. Feed bytes, not decoded strings, so caps are exact.
function newPhoneSetupReader() as object
    return {head: "", headBytes: 0, headDone: false, contentLength: 0, body: [], ready: false, response: invalid}
end function

sub phoneSetupFeed(reader as object, bytes as object, unavailable as boolean)
    if reader.ready or reader.response <> invalid then return
    position = 0
    while not reader.headDone and position < bytes.count()
        reader.headBytes++
        if reader.headBytes > 32768
            reader.response = phoneSetupFailure(400, "bad_request")
            return
        end if
        value = bytes[position]
        position++
        if value = 0
            reader.response = phoneSetupFailure(400, "bad_request")
            return
        end if
        reader.head += chr(value)
        if right(reader.head, 4) = chr(13) + chr(10) + chr(13) + chr(10)
            check = validatePhoneSetupRequestHead(reader.head, unavailable)
            reader.head = ""
            if not check.ok
                reader.response = check
                return
            end if
            reader.headDone = true
            reader.contentLength = check.contentLength
        end if
    end while
    if not reader.headDone then return
    remaining = reader.contentLength - reader.body.count()
    available = bytes.count() - position
    if available > remaining then available = remaining
    if available > 0
        for i = position to position + available - 1
            reader.body.push(bytes[i])
        end for
    end if
    reader.ready = reader.body.count() = reader.contentLength
end sub

' ToAsciiString has undefined behavior on malformed UTF8 and truncates at NUL.
' NUL is valid Unicode but cannot occur raw in valid JSON, so refuse it too.
function phoneSetupUtf8Valid(bytes as object) as boolean
    i = 0
    while i < bytes.count()
        value = bytes[i]
        i++
        if value = 0 then return false
        if value >= 128
            count = 0
            if value >= 194 and value <= 223 then count = 1
            if value >= 224 and value <= 239 then count = 2
            if value >= 240 and value <= 244 then count = 3
            if count = 0 or i + count > bytes.count() then return false
            second = bytes[i]
            if value = 224 and second < 160 then return false
            if value = 237 and second >= 160 then return false
            if value = 240 and second < 144 then return false
            if value = 244 and second >= 144 then return false
            for j = 0 to count - 1
                if bytes[i + j] < 128 or bytes[i + j] > 191 then return false
            end for
            i += count
        end if
    end while
    return true
end function

function phoneSetupCodeFromDraw(bytes as object) as dynamic
    if bytes.count() <> 4 then return invalid
    value = bytes[0] + 256.0# * bytes[1] + 65536.0# * bytes[2] + 16777216.0# * bytes[3]
    if value >= 4294.0# * 1000000.0# then return invalid
    ' Rolling modulo stays below 256 million: native MOD narrows to Int32.
    remainder = 0
    for i = 3 to 0 step -1
        remainder = (remainder * 256 + bytes[i]) mod 1000000
    end for
    return right("000000" + remainder.toStr(), 6)
end function

function phoneSetupHttpResponse(status as integer, reason as string) as string
    phrases = {"200": "OK", "400": "Bad Request", "403": "Forbidden", "404": "Not Found", "413": "Payload Too Large"}
    body = "{""ok"":true}"
    if status <> 200 then body = "{""ok"":false,""error"":""" + reason + """}"
    crlf = chr(13) + chr(10)
    return "HTTP/1.1 " + status.toStr() + " " + phrases[status.toStr()] + crlf + "Content-Type: application/json" + crlf + "Content-Length: " + len(body).toStr() + crlf + "Connection: close" + crlf + crlf + body
end function
