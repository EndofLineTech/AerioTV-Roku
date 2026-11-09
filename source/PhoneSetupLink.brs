' Byte-based truncation respects both the code-point and UTF8 DNS-label limits.
function phoneSetupNameBytes(bytes as object) as object
    result = []
    position = 0
    points = 0
    while position < bytes.count() and points < 60
        value = bytes[position]
        count = 1
        if value >= 194 and value <= 223 then count = 2
        if value >= 224 and value <= 239 then count = 3
        if value >= 240 and value <= 244 then count = 4
        if result.count() + count > 63 or position + count > bytes.count() then exit while
        for i = 0 to count - 1
            result.push(bytes[position + i])
        end for
        position += count
        points++
    end while
    return result
end function

function phoneSetupPercentEncode(bytes as object) as string
    result = ""
    alphabet = "0123456789ABCDEF"
    for each value in bytes
        bare = (value >= 65 and value <= 90) or (value >= 97 and value <= 122) or (value >= 48 and value <= 57)
        if value = 45 or value = 46 or value = 95 or value = 126 then bare = true
        if bare
            result += chr(value)
        else
            result += "%" + mid(alphabet, int(value / 16) + 1, 1) + mid(alphabet, value mod 16 + 1, 1)
        end if
    end for
    return result
end function

function phoneSetupLink(ip as string, port as integer, code as string, publicBase64 as string, nameBytes as object) as string
    pk = publicBase64.replace("+", "-").replace("/", "_").replace("=", "")
    return "aeriotv://setup?v=1&ip=" + ip + "&port=" + port.toStr() + "&code=" + code + "&pk=" + pk + "&name=" + phoneSetupPercentEncode(nameBytes)
end function
