' Bounded DNS wire primitives. Public discovery data only; never accepts a code.
' Numeric arrays keep the parser/encoder testable without native socket objects.
function phoneSetupDnsAscii(text as string) as object
    bytes = []
    for i = 1 to len(text)
        bytes.push(asc(mid(text, i, 1)))
    end for
    return bytes
end function

function phoneSetupDnsHex(bytes as object) as string
    alphabet = "0123456789abcdef"
    result = ""
    for each value in bytes
        result += mid(alphabet, int(value / 16) + 1, 1) + mid(alphabet, value mod 16 + 1, 1)
    end for
    return result
end function

function phoneSetupDnsNameKey(labels as object) as string
    key = ""
    for each label in labels
        normalized = []
        for each value in label
            if value >= 65 and value <= 90 then value += 32
            normalized.push(value)
        end for
        key += phoneSetupDnsHex(normalized) + "/"
    end for
    return key
end function

function phoneSetupDnsWireKey(labels as object) as string
    wire = []
    phoneSetupDnsName(wire, labels)
    normalized = []
    for each value in wire
        if value >= 65 and value <= 90 then value += 32
        normalized.push(value)
    end for
    return phoneSetupDnsHex(normalized)
end function

sub phoneSetupDnsAppend(target as object, bytes as object)
    for each value in bytes
        target.push(value)
    end for
end sub

sub phoneSetupDnsU16(bytes as object, value as integer)
    bytes.push((value \ 256) mod 256)
    bytes.push(value mod 256)
end sub

sub phoneSetupDnsName(bytes as object, labels as object)
    for each label in labels
        bytes.push(label.count())
        phoneSetupDnsAppend(bytes, label)
    end for
    bytes.push(0)
end sub

function phoneSetupMdnsLabel(name as object, ordinal as integer) as object
    suffix = []
    if ordinal > 1 then suffix = phoneSetupDnsAscii(" (" + ordinal.toStr() + ")")
    limit = 63 - suffix.count()
    take = name.count()
    if take > limit
        take = limit
        while take > 0
            if name[take] < 128 or name[take] >= 192 then exit while
            take--
        end while
    end if
    label = []
    for i = 0 to take - 1
        label.push(name[i])
    end for
    phoneSetupDnsAppend(label, suffix)
    return label
end function

function phoneSetupMdnsRecords(name as object, hostname as string, ip as string, port as integer, publicBase64 as string, ordinal = 1 as integer) as object
    service = [phoneSetupDnsAscii("_aeriotv-setup"), phoneSetupDnsAscii("_tcp"), phoneSetupDnsAscii("local")]
    instance = [phoneSetupMdnsLabel(name, ordinal), service[0], service[1], service[2]]
    hostLabel = hostname
    if ordinal > 1 then hostLabel += "-" + ordinal.toStr()
    host = [phoneSetupDnsAscii(hostLabel), service[2]]
    ptr = []: phoneSetupDnsName(ptr, instance)
    srv = [0, 0, 0, 0]: phoneSetupDnsU16(srv, port): phoneSetupDnsName(srv, host)
    txt = []
    shownName = phoneSetupDnsAscii("name=")
    phoneSetupDnsAppend(shownName, name)
    for each value in [phoneSetupDnsAscii("v=1"), shownName, phoneSetupDnsAscii("pk=" + publicBase64), phoneSetupDnsAscii("kind=tv")]
        txt.push(value.count())
        phoneSetupDnsAppend(txt, value)
    end for
    address = []
    for each part in ip.split(".")
        address.push(part.toInt())
    end for
    records = []
    for each spec in [{labels: service, kind: 12, data: ptr}, {labels: instance, kind: 33, data: srv}, {labels: instance, kind: 16, data: txt}, {labels: host, kind: 1, data: address}]
        spec.key = phoneSetupDnsNameKey(spec.labels)
        spec.canonical = phoneSetupDnsHex(spec.data)
        if spec.kind = 12 then spec.canonical = phoneSetupDnsWireKey(instance)
        if spec.kind = 33 then spec.canonical = phoneSetupDnsHex([0, 0, 0, 0, (port \ 256) mod 256, port mod 256]) + phoneSetupDnsWireKey(host)
        records.push(spec)
    end for
    return records
end function

function phoneSetupDnsMessage(id as integer, response as boolean, questions as object, answers as object, authority as object, additional as object, ttl as integer, sharedOnly as boolean) as object
    bytes = []
    phoneSetupDnsU16(bytes, id)
    flags = 0
    if response then flags = 33792 ' QR + authoritative answer.
    phoneSetupDnsU16(bytes, flags)
    for each count in [questions.count(), answers.count(), authority.count(), additional.count()]
        phoneSetupDnsU16(bytes, count)
    end for
    for each question in questions
        phoneSetupDnsName(bytes, question.labels)
        phoneSetupDnsU16(bytes, question.kind)
        class = 1
        if question.qu = true then class += 32768
        phoneSetupDnsU16(bytes, class)
    end for
    for each section in [answers, authority, additional]
        for each record in section
            phoneSetupDnsName(bytes, record.labels)
            phoneSetupDnsU16(bytes, record.kind)
            class = 1
            if record.kind <> 12 and not sharedOnly then class += 32768
            phoneSetupDnsU16(bytes, class)
            phoneSetupDnsU16(bytes, ttl \ 65536)
            phoneSetupDnsU16(bytes, ttl mod 65536)
            phoneSetupDnsU16(bytes, record.data.count())
            phoneSetupDnsAppend(bytes, record.data)
        end for
    end for
    return bytes
end function

function phoneSetupDnsRead16(bytes as object, at as integer) as integer
    return bytes[at] * 256 + bytes[at + 1]
end function

function phoneSetupDnsReadName(bytes as object, start as integer) as dynamic
    at = start
    following = -1
    labels = []
    length = 1
    visited = {}
    for stepCount = 0 to 127
        if at < 0 or at >= bytes.count() then return invalid
        if visited.doesExist(at.toStr()) then return invalid
        visited[at.toStr()] = true
        size = bytes[at]
        if size = 0
            if following < 0 then following = at + 1
            return {labels: labels, key: phoneSetupDnsNameKey(labels), nextAt: following}
        end if
        if size >= 192
            if at + 1 >= bytes.count() then return invalid
            if following < 0 then following = at + 2
            at = (size mod 64) * 256 + bytes[at + 1]
        else
            if size > 63 or at + size >= bytes.count() then return invalid
            length += size + 1
            if length > 255 then return invalid
            label = []
            for i = at + 1 to at + size
                label.push(bytes[i])
            end for
            labels.push(label)
            at += size + 1
        end if
    end for
    return invalid
end function

function phoneSetupDnsParse(bytes as object) as dynamic
    if bytes.count() < 12 or bytes.count() >= 4096 then return invalid
    if (bytes[2] mod 128) \ 8 <> 0 or bytes[3] mod 16 <> 0 then return invalid ' Unsupported opcode/rcode.
    counts = []
    total = 0
    for i = 4 to 10 step 2
        count = phoneSetupDnsRead16(bytes, i)
        if count > 32 then return invalid
        counts.push(count)
        total += count
    end for
    if counts[0] > 16 or total > 64 then return invalid
    result = {id: phoneSetupDnsRead16(bytes, 0), response: bytes[2] >= 128, truncated: (bytes[2] mod 4) >= 2, questions: [], answers: [], authority: [], additional: []}
    at = 12
    for section = 0 to 3
        for index = 1 to counts[section]
            name = phoneSetupDnsReadName(bytes, at)
            if name = invalid then return invalid
            at = name.nextAt
            if at + 4 > bytes.count() then return invalid
            kind = phoneSetupDnsRead16(bytes, at)
            class = phoneSetupDnsRead16(bytes, at + 2)
            at += 4
            if section = 0
                result.questions.push({labels: name.labels, key: name.key, kind: kind, qu: class >= 32768, class: class mod 32768})
            else
                if at + 6 > bytes.count() then return invalid
                ttl = bytes[at] * 16777216.0# + bytes[at + 1] * 65536.0# + bytes[at + 2] * 256.0# + bytes[at + 3]
                size = phoneSetupDnsRead16(bytes, at + 4)
                at += 6
                endAt = at + size
                if endAt > bytes.count() then return invalid
                data = []
                for i = at to endAt - 1
                    data.push(bytes[i])
                end for
                canonical = phoneSetupDnsHex(data)
                if kind = 12 or kind = 33
                    targetAt = at
                    if kind = 33 then targetAt += 6
                    if targetAt >= endAt then return invalid
                    target = phoneSetupDnsReadName(bytes, targetAt)
                    if target = invalid then return invalid
                    if target.nextAt <> endAt then return invalid
                    canonical = phoneSetupDnsWireKey(target.labels)
                    if kind = 33
                        prefix = []
                        for i = 0 to 5
                            prefix.push(data[i])
                        end for
                        canonical = phoneSetupDnsHex(prefix) + phoneSetupDnsWireKey(target.labels)
                    end if
                end if
                record = {key: name.key, kind: kind, class: class mod 32768, flush: class >= 32768, ttl: ttl, data: data, canonical: canonical}
                if section = 1 then result.answers.push(record)
                if section = 2 then result.authority.push(record)
                if section = 3 then result.additional.push(record)
                at = endAt
            end if
        end for
    end for
    if at <> bytes.count() then return invalid
    return result
end function

' A competing response owns its name. Simultaneous probes compare the complete
' sorted unique RRsets (class IN, type, canonical uncompressed RDATA).
function phoneSetupMdnsConflict(packet as object, records as object) as boolean
    incoming = packet.authority
    if packet.response
        incoming = []
        for each section in [packet.answers, packet.additional]
            for each record in section
                incoming.push(record)
            end for
        end for
    end if
    for each owner in [records[1].key, records[3].key]
        differs = false
        remoteSet = []
        localSet = []
        for each own in records
            if own.key = owner and own.kind <> 12 then localSet.push("0001" + phoneSetupDnsHex([own.kind \ 256, own.kind mod 256]) + own.canonical)
        end for
        for each remote in incoming
            if remote.key = owner and remote.class = 1 and remote.ttl > 0 and (remote.kind = 1 or remote.kind = 16 or remote.kind = 33)
                remoteSet.push("0001" + phoneSetupDnsHex([remote.kind \ 256, remote.kind mod 256]) + remote.canonical)
                for each own in records
                    if own.key = owner and own.kind = remote.kind and own.canonical <> remote.canonical then differs = true
                end for
            end if
        end for
        if differs
            if packet.response then return true
            localSet.sort()
            remoteSet.sort()
            for i = 0 to remoteSet.count() - 1
                if i >= localSet.count() then return true
                if remoteSet[i] > localSet[i] then return true
                if remoteSet[i] < localSet[i] then exit for
            end for
        end if
    end for
    return false
end function

function phoneSetupMdnsSelect(query as object, records as object) as object
    chosen = []
    for each record in records
        wanted = false
        for each question in query.questions
            if question.class = 1 or question.class = 255
                if question.key = record.key and (question.kind = record.kind or question.kind = 255) then wanted = true
            end if
        end for
        for each known in query.answers
            if known.class = 1 and known.ttl >= 60 and known.key = record.key and known.kind = record.kind and known.canonical = record.canonical then wanted = false
        end for
        if wanted then chosen.push(record)
    end for
    return chosen
end function
