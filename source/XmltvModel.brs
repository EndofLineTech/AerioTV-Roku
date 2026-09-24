' File-backed XMLTV parser primitives. A Task reads fixed-size file slices and
' passes them here; neither the feed nor all its programmes enter SceneGraph.
function xmltvEpoch(value as string) as dynamic
    value = value.trim()
    parts = CreateObject("roRegex", "^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2}) ([+-])(\d{2})(\d{2})$", "").match(value)
    if parts.count() <> 10 then return invalid
    offsetHours = val(parts[8])
    offsetMinutes = val(parts[9])
    if offsetHours > 23 or offsetMinutes > 59 then return invalid
    iso = parts[1] + "-" + parts[2] + "-" + parts[3] + "T" + parts[4] + ":" + parts[5] + ":" + parts[6]
    date = CreateObject("roDateTime")
    date.fromISO8601String(iso + "Z")
    if left(date.toISOString(), 19) <> iso then return invalid
    epoch = date.asSeconds()
    offset = offsetHours * 3600 + offsetMinutes * 60
    if parts[7] = "+" then epoch -= offset else epoch += offset
    return epoch
end function

function xmltvWindowState(windowStart as integer, windowEnd as integer, allowedKeys as object, parser = invalid as dynamic) as object
    return {windowStart: windowStart, windowEnd: windowEnd, allowedKeys: allowedKeys, index: guideDictionary(), times: guideDictionary(), tail: "", count: 0, error: "", parser: parser}
end function

function xmltvUtf8PrefixLength(bytes as object) as integer
    size = bytes.count()
    if size < 1 then return 0
    i = size - 1
    if bytes[i] < 128 then return size
    while i >= 0 and bytes[i] >= 128 and bytes[i] < 192
        i--
    end while
    if i < 0 then return -1
    lead = bytes[i]
    width = 0
    if lead >= 194 and lead <= 223 then width = 2
    if lead >= 224 and lead <= 239 then width = 3
    if lead >= 240 and lead <= 244 then width = 4
    if width = 0 then return -1
    if size - i < width then return i
    return size
end function

function xmltvFileEncoding(path as string, size as integer) as string
    bytes = CreateObject("roByteArray")
    length = size
    if length > 16 then length = 16
    if length < 2 or not bytes.readFile(path, 0, length) then return "invalid"
    if bytes[0] = 31 and bytes[1] = 139 then return "gzip"
    first = 0
    if bytes.count() >= 3
        if bytes[0] = 239 and bytes[1] = 187 and bytes[2] = 191 then first = 3
    end if
    for i = first to bytes.count() - 1
        if bytes[i] = 60 then return "xml"
        if bytes[i] <> 9 and bytes[i] <> 10 and bytes[i] <> 13 and bytes[i] <> 32 then exit for
    end for
    return "invalid"
end function

function xmltvReadWindowFile(path as string, windowStart as integer, windowEnd as integer, allowedKeys as object, parser = invalid as dynamic, maxBytes = 75497472 as integer, chunkSize = 8192 as integer) as object
    fs = CreateObject("roFileSystem")
    stat = fs.stat(path)
    if type(stat) <> "roAssociativeArray" then return {ok: false, message: "XMLTV file unavailable."}
    if GetInterface(stat.size, "ifInt") = invalid then return {ok: false, message: "XMLTV file size unavailable."}
    if stat.size < 1 or stat.size > maxBytes then return {ok: false, message: "XMLTV feed exceeds this device's file budget."}
    encoding = xmltvFileEncoding(path, stat.size)
    if encoding = "gzip" then return {ok: false, message: "Raw .xml.gz needs the server to send Content-Encoding: gzip."}
    if encoding <> "xml" then return {ok: false, message: "The guide is not an XMLTV document."}
    if chunkSize < 8 or chunkSize > 16384 then return {ok: false, message: "Invalid XMLTV read size."}
    state = xmltvWindowState(windowStart, windowEnd, allowedKeys, parser)
    clock = CreateObject("roTimespan")
    clock.mark()
    offset = 0
    monitor = CreateObject("roAppMemoryMonitor")
    while offset < stat.size
        if m.top <> invalid
            if m.top.cancelRequested = true then return {ok: false, message: "XMLTV load cancelled."}
        end if
        if clock.totalMilliseconds() > 45000 then return {ok: false, message: "XMLTV window parsing timed out."}
        if monitor <> invalid and offset mod 1048576 < chunkSize
            percent = monitor.getMemoryLimitPercent()
            if percent <> invalid
                if percent >= 75 then return {ok: false, message: "Device memory pressure stopped XMLTV parsing."}
            end if
        end if
        length = chunkSize
        if stat.size - offset < length then length = stat.size - offset
        bytes = CreateObject("roByteArray")
        if not bytes.readFile(path, offset, length) or bytes.count() <> length then return {ok: false, message: "Could not read XMLTV file."}
        valid = xmltvUtf8PrefixLength(bytes)
        if valid < 1 then return {ok: false, message: "Invalid XMLTV UTF-8 boundary."}
        while bytes.count() > valid
            bytes.pop()
        end while
        xmltvConsumeChunk(state, bytes.toAsciiString())
        if state.error <> "" then return {ok: false, message: state.error}
        offset += valid
    end while
    if instr(1, state.tail, "<programme") > 0 then return {ok: false, message: "Incomplete XMLTV programme."}
    for each key in state.index
        state.index[key].sortBy("startsAt")
    end for
    return {ok: true, index: state.index, count: state.count}
end function

sub xmltvConsumeChunk(state as object, chunk as string)
    if state.error <> "" then return
    rest = state.tail + chunk
    state.tail = ""
    closing = "</programme>"
    while true
        startAt = instr(1, rest, "<programme")
        if startAt = 0
            ' Retain only enough to recognize a start tag split across reads.
            state.tail = right(rest, 9)
            return
        end if
        endAt = instr(startAt, rest, closing)
        if endAt = 0
            state.tail = mid(rest, startAt)
            if len(state.tail) > 16384 then state.error = "XMLTV programme exceeds 16-KiB record limit."
            return
        end if
        size = endAt - startAt + len(closing)
        if size > 16384
            state.error = "XMLTV programme exceeds 16-KiB record limit."
            return
        end if
        fragment = mid(rest, startAt, size)
        program = xmltvProgramFragment(fragment, state)
        if program <> invalid
            if not state.index.doesExist(program.key) then state.index[program.key] = []
            state.index[program.key].push(program)
            state.count++
            if state.count > 24000
                state.error = "XMLTV window exceeds 24,000-program limit."
                return
            end if
        end if
        rest = mid(rest, endAt + len(closing))
    end while
end sub

function xmltvProgramFragment(fragment as string, state as object) as dynamic
    ' Skip unrelated channels before paying for the XML tree. The XML parser
    ' still validates every accepted fragment and decodes its entities.
    headerEnd = instr(1, fragment, ">")
    if headerEnd < 1 or headerEnd > 2048 then return invalid
    header = left(fragment, headerEnd)
    channel = xmltvHeaderAttribute(header, "channel", 128)
    if channel = "" then return invalid
    if not state.allowedKeys.doesExist(channel) then return invalid
    startText = xmltvHeaderAttribute(header, "start", 40)
    stopText = xmltvHeaderAttribute(header, "stop", 40)
    if startText = "" or stopText = "" then return invalid
    startsAt = xmltvCachedEpoch(startText, state.times)
    endsAt = xmltvCachedEpoch(stopText, state.times)
    if startsAt = invalid or endsAt = invalid then return invalid
    if startsAt >= state.windowEnd or endsAt <= state.windowStart or endsAt <= startsAt then return invalid
    fields = invalid
    if state.parser <> invalid
        fields = state.parser(fragment)
    else
        fields = xmltvFastFields(fragment)
        if fields = invalid then fields = xmltvNativeFields(fragment)
    end if
    if type(fields) <> "roAssociativeArray" then return invalid
    raw = {id: channel + "-" + startsAt.toStr(), tvg_id: channel, title: "", description: "", start_time: "", end_time: "", categories: []}
    raw.start_time = CreateObject("roDateTime")
    raw.start_time.fromSeconds(startsAt)
    raw.start_time = raw.start_time.toISOString()
    raw.end_time = CreateObject("roDateTime")
    raw.end_time.fromSeconds(endsAt)
    raw.end_time = raw.end_time.toISOString()
    raw.append(fields)
    return normalizeProgram(raw)
end function

function xmltvHeaderAttribute(header as string, name as string, maxLength as integer) as string
    quote = chr(34)
    pattern = name + "=" + quote
    marker = instr(1, header, pattern)
    if marker < 1 then return ""
    if marker > 1
        if mid(header, marker - 1, 1) <> " " then return ""
    end if
    first = marker + len(pattern)
    ending = instr(first, header, quote)
    if ending <= first or ending - first > maxLength then return ""
    return mid(header, first, ending - first)
end function

function xmltvCachedEpoch(value as string, cache as object) as dynamic
    if cache.doesExist(value) then return cache[value]
    parsed = xmltvEpoch(value)
    if parsed <> invalid
        if cache.count() >= 4096 then cache.clear()
        cache[value] = parsed
    end if
    return parsed
end function

function xmltvDecodedText(value as string) as dynamic
    output = ""
    rest = value
    while true
        marker = instr(1, rest, "&#")
        if marker = 0 then exit while
        output += left(rest, marker - 1)
        rest = mid(rest, marker + 2)
        finish = instr(1, rest, ";")
        if finish < 2 or finish > 9 then return invalid
        digits = left(rest, finish - 1)
        codepoint = 0
        if left(digits, 1) = "x" or left(digits, 1) = "X"
            digits = ucase(mid(digits, 2))
            if digits = "" then return invalid
            for i = 1 to len(digits)
                digit = instr(1, "0123456789ABCDEF", mid(digits, i, 1)) - 1
                if digit < 0 then return invalid
                codepoint = codepoint * 16 + digit
            end for
        else
            if not CreateObject("roRegex", "^[0-9]{1,7}$", "").isMatch(digits) then return invalid
            codepoint = val(digits)
        end if
        if codepoint < 32 or codepoint > 1114111 then return invalid
        if codepoint >= 55296 and codepoint <= 57343 then return invalid
        output += chr(codepoint)
        rest = mid(rest, finish + 1)
    end while
    output += rest
    for each replacement in [{encoded: "&amp;", value: "&"}, {encoded: "&lt;", value: "<"}, {encoded: "&gt;", value: ">"}, {encoded: "&quot;", value: chr(34)}, {encoded: "&apos;", value: "'"}]
        output = CreateObject("roRegex", replacement.encoded, "").replaceAll(output, replacement.value)
    end for
    ' Unknown entities need the native XML validator, not literal UI text.
    if CreateObject("roRegex", "&[A-Za-z][A-Za-z0-9]*;", "").isMatch(output) then return invalid
    return output
end function

function xmltvFastTag(fragment as string, name as string) as dynamic
    opening = instr(1, fragment, "<" + name)
    if opening = 0 then return ""
    delimiter = mid(fragment, opening + len(name) + 1, 1)
    if delimiter <> ">" and delimiter <> " " then return ""
    begin = instr(opening, fragment, ">")
    finish = instr(begin + 1, fragment, "</" + name + ">")
    if begin < opening or finish < begin then return invalid
    value = mid(fragment, begin + 1, finish - begin - 1)
    if instr(1, value, "<") > 0 then return invalid
    return xmltvDecodedText(value)
end function

function xmltvFastFields(fragment as string) as dynamic
    if instr(1, fragment, "<!") > 0 then return invalid
    fields = {title: xmltvFastTag(fragment, "title"), description: xmltvFastTag(fragment, "desc"), sub_title: xmltvFastTag(fragment, "sub-title"), categories: []}
    if fields.title = invalid or fields.description = invalid or fields.sub_title = invalid then return invalid
    rest = fragment
    for i = 1 to 12
        opening = instr(1, rest, "<category")
        if opening = 0 then exit for
        category = xmltvFastTag(rest, "category")
        if category = invalid then return invalid
        if category <> "" then fields.categories.push(category)
        ending = instr(opening, rest, "</category>")
        if ending = 0 then return invalid
        rest = mid(rest, ending + len("</category>"))
    end for
    for each badge in ["new", "live", "premiere", "previously-shown"]
        if CreateObject("roRegex", "<" + badge + "([\s/>])", "").isMatch(fragment)
            field = "is_" + badge
            if badge = "previously-shown" then field = "is_previously_shown"
            fields[field] = true
        end if
    end for
    quote = chr(34)
    parts = CreateObject("roRegex", "<icon[\s]+src=" + quote + "([^" + quote + "]{1,256})" + quote, "").match(fragment)
    if parts.count() > 1 then fields.icon = parts[1]
    return fields
end function

function xmltvNativeFields(fragment as string) as dynamic
    xml = CreateObject("roXMLElement")
    if not xml.parse(fragment) then return invalid
    fields = {title: "", description: "", categories: []}
    children = xml.getChildElements()
    if children <> invalid
        for each child in children
            kind = child.getName()
            if kind = "title" then fields.title = child.getText()
            if kind = "desc" then fields.description = child.getText()
            if kind = "sub-title" then fields.sub_title = child.getText()
            if kind = "category" and fields.categories.count() < 12 then fields.categories.push(child.getText())
            if kind = "new" then fields.is_new = true
            if kind = "live" then fields.is_live = true
            if kind = "premiere" then fields.is_premiere = true
            if kind = "previously-shown" then fields.is_previously_shown = true
            if kind = "icon"
                attributes = child.getAttributes()
                if type(attributes) = "roAssociativeArray" then fields.icon = textValue(attributes.src)
            end if
        end for
    end if
    return fields
end function
