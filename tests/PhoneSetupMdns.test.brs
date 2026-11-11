sub main()
    name = asciiBytes("Living Room")
    records = phoneSetupMdnsRecords(name, "aeriotv-test", "192.0.2.10", 32123, "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
    check(records.count() = 4, "PTR SRV TXT A")
    check(records[0].kind = 12 and records[1].kind = 33 and records[2].kind = 16 and records[3].kind = 1, "record types")
    packet = phoneSetupDnsMessage(0, true, [], [records[0]], [], [records[1], records[2], records[3]], 120, false)
    parsed = phoneSetupDnsParse(packet)
    check(parsed <> invalid and parsed.response and parsed.answers.count() = 1 and parsed.additional.count() = 3, "announcement parses")
    check(parsed.answers[0].ttl = 120 and not parsed.answers[0].flush, "PTR is shared")
    check(parsed.additional[0].flush and parsed.additional[1].flush and parsed.additional[2].flush, "unique records cache flush")
    check(parsed.additional[0].data[4] = 125 and parsed.additional[0].data[5] = 123, "SRV big endian port")
    check(phoneSetupDnsHex(parsed.additional[2].data) = "c000020a", "A exact IPv4 octets")
    check(parsed.additional[0].canonical = records[1].canonical, "SRV target canonical wire encoding")
    txt = parsed.additional[1].data
    expected = ["v=1", "name=Living Room", "pk=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", "kind=tv"]
    position = 0
    for each value in expected
        check(txt[position] = len(value), "TXT length")
        position++
        for i = 1 to len(value)
            check(txt[position] = asc(mid(value, i, 1)), "TXT exact value and no code material")
            position++
        end for
    end for
    check(position = txt.count(), "TXT has only four public fields")
    q = {labels: records[0].labels, kind: 12, qu: false}
    query = phoneSetupDnsMessage(0, false, [q], [], [], [], 120, false)
    parsedQuery = phoneSetupDnsParse(query)
    selected = phoneSetupMdnsSelect(parsedQuery, records)
    check(selected.count() = 1 and selected[0].kind = 12, "browse query selects PTR")
    known = phoneSetupDnsMessage(0, false, [q], [records[0]], [], [], 120, false)
    check(phoneSetupMdnsSelect(phoneSetupDnsParse(known), records).count() = 0, "fresh known answer suppresses duplicate")
    stale = phoneSetupDnsMessage(0, false, [q], [records[0]], [], [], 20, false)
    check(phoneSetupMdnsSelect(phoneSetupDnsParse(stale), records).count() = 1, "stale known answer gets refreshed")
    goodbye = phoneSetupDnsParse(phoneSetupDnsMessage(0, true, [], records, [], [], 0, false))
    for each record in goodbye.answers
        check(record.ttl = 0, "goodbye TTL zero for every record")
    end for
    legacy = phoneSetupDnsParse(phoneSetupDnsMessage(1234, true, [q], records, [], [], 10, true))
    check(legacy.id = 1234 and legacy.questions.count() = 1, "legacy response echoes ID and question")
    for each record in legacy.answers
        check(not record.flush and record.ttl = 10, "legacy no cache flush and short TTL")
    end for
    probe = phoneSetupDnsParse(phoneSetupDnsMessage(0, false, [{labels: records[1].labels, kind: 255, qu: false}], [], [records[1], records[2]], [], 120, true))
    check(not probe.response and probe.authority.count() = 2, "probe proposes unique service records")
    check(not phoneSetupMdnsConflict(parsed, records), "own announcement is not a conflict")
    check(not phoneSetupMdnsConflict(probe, records), "identical simultaneous probe is not a conflict")
    later = phoneSetupMdnsRecords(name, "aeriotv-test", "192.0.2.11", 32123, "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
    laterProbe = phoneSetupDnsParse(phoneSetupDnsMessage(0, false, [], [], [later[1], later[2], later[3]], [], 120, true))
    earlierProbe = phoneSetupDnsParse(phoneSetupDnsMessage(0, false, [], [], [records[1], records[2], records[3]], [], 120, true))
    check(phoneSetupMdnsConflict(laterProbe, records), "lexicographically later probe wins host name")
    check(not phoneSetupMdnsConflict(earlierProbe, later), "lexicographically earlier probe loses host name")
    laterResponse = phoneSetupDnsParse(phoneSetupDnsMessage(0, true, [], later, [], [], 120, false))
    check(phoneSetupMdnsConflict(laterResponse, records), "different established A record conflicts")
    laterGoodbye = phoneSetupDnsParse(phoneSetupDnsMessage(0, true, [], later, [], [], 0, false))
    check(not phoneSetupMdnsConflict(laterGoodbye, records), "goodbye does not claim a name")
    changedKey = phoneSetupMdnsRecords(name, "aeriotv-test", "192.0.2.10", 32123, "AQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
    changedResponse = phoneSetupDnsParse(phoneSetupDnsMessage(0, true, [], changedKey, [], [], 120, false))
    check(phoneSetupMdnsConflict(changedResponse, records), "different established TXT conflicts")
    check(phoneSetupDnsParse([]) = invalid, "short header")
    for cut = 0 to packet.count() - 1
        prefix = []
        for index = 0 to cut - 1
            prefix.push(packet[index])
        end for
        check(phoneSetupDnsParse(prefix) = invalid, "every truncated announcement prefix rejected")
    end for
    check(phoneSetupDnsParse([0,0,8,0,0,0,0,0,0,0,0,0]) = invalid, "unsupported opcode")
    check(phoneSetupDnsParse([0,0,0,1,0,0,0,0,0,0,0,0]) = invalid, "error rcode")
    check(phoneSetupDnsParse([0,0,0,0,0,17,0,0,0,0,0,0]) = invalid, "question count bound")
    check(phoneSetupDnsParse([0,0,0,0,0,0,0,33,0,0,0,0]) = invalid, "record count bound")
    oversized = []
    for i = 0 to 4095
        oversized.push(0)
    end for
    check(phoneSetupDnsParse(oversized) = invalid, "datagram bound including truncated receive")
    trailing = phoneSetupDnsMessage(0, false, [], [], [], [], 120, false)
    trailing.push(0)
    check(phoneSetupDnsParse(trailing) = invalid, "trailing bytes rejected")
    check(phoneSetupDnsParse([0,0,0,0,0,1,0,0,0,0,0,0,64,0,0,0,0]) = invalid, "reserved label form rejected")
    brokenSrv = {labels: records[1].labels, kind: 33, data: [0,0,0,0,0,80]}
    check(phoneSetupDnsParse(phoneSetupDnsMessage(0, true, [], [brokenSrv], [], [], 120, false)) = invalid, "SRV missing target rejected")
    check(phoneSetupDnsParse([0,0,0,0,0,1,0,0,0,0,0,0,192,12,0,12,0,1]) = invalid, "compression cycle rejected")
    check(phoneSetupDnsParse([0,0,0,0,0,1,0,0,0,0,0,0,192,255,0,12,0,1]) = invalid, "pointer out of bounds rejected")
    compressed = [0,0,0,0,0,2,0,0,0,0,0,0,1,97,0,0,1,0,1,192,12,0,255,128,1]
    decoded = phoneSetupDnsParse(compressed)
    check(decoded <> invalid and decoded.questions.count() = 2 and decoded.questions[1].qu, "compressed question and QU bit")
    check(decoded.questions[0].key = decoded.questions[1].key, "compression preserves name")
    check(phoneSetupMdnsLabel(name, 2).count() = name.count() + 4, "conflict suffix")
    longName = []
    for i = 1 to 31
        longName.push(195): longName.push(169)
    end for
    suffixed = phoneSetupMdnsLabel(longName, 2)
    check(suffixed.count() <= 63 and suffixed[suffixed.count() - 5] = 169, "suffix never splits UTF8")
    check(phoneSetupDnsNameKey([asciiBytes("ABC"), asciiBytes("local")]) = phoneSetupDnsNameKey([asciiBytes("abc"), asciiBytes("LOCAL")]), "DNS ASCII case folding")
    print "ALL TESTS PASSED"
end sub

function asciiBytes(text as string) as object
    result = []
    for i = 1 to len(text)
        result.push(asc(mid(text, i, 1)))
    end for
    return result
end function

sub check(ok as boolean, message as string)
    if not ok
        print "FAIL: "; message
        stop
    end if
end sub
