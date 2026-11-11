' Task-owned mDNS responder. No SceneGraph field reads, HTTP, registry or secrets.
function phoneSetupMdnsOpen() as dynamic
    socket = CreateObject("roDataGramSocket")
    if socket = invalid then return invalid
    socket.setMessagePort(m.setupPort)
    group = CreateObject("roSocketAddress")
    address = CreateObject("roSocketAddress")
    address.setPort(5353)
    configured = group.setAddress("224.0.0.251:5353")
    configured = socket.setReuseAddr(true) and configured
    configured = socket.setMulticastTTL(255) and configured
    configured = socket.setTTL(255) and configured
    if not configured or not socket.setAddress(address)
        print "[setup-discovery] unavailable-bind"
        socket.close()
        return invalid
    end if
    if not socket.joinGroup(group)
        print "[setup-discovery] unavailable-multicast"
        socket.close()
        return invalid
    end if
    socket.setMulticastLoop(false)
    socket.notifyReadable(true)
    print "[setup-discovery] socket-ready"
    device = CreateObject("roDeviceInfo")
    identity = CreateObject("roByteArray")
    identity.fromAsciiString("aeriotv-setup-host-v1|" + device.getChannelClientId())
    digest = CreateObject("roEVPDigest")
    digest.setup("sha256")
    hostname = "aeriotv-" + left(lcase(digest.process(identity)), 12)
    state = {socket: socket, group: group, hostname: hostname, ordinal: 1, phase: "probing", probes: 0
        nextAt: m.setupClock.totalMilliseconds() + rnd(251) - 1, pending: invalid, lastReply: -1000
        defended: false, defendedAt: 0, records: []}
    ' Rnd above only staggers PUBLIC discovery packets. It never seeds keys/codes.
    return state
end function

sub phoneSetupMdnsRefresh()
    if m.mdns = invalid then return
    public = phoneSetupHexBytes(m.material.publicHex)
    m.mdns.records = phoneSetupMdnsRecords(m.setupNameBytes, m.mdns.hostname, m.setupIp, m.listenerPort, public.toBase64String(), m.mdns.ordinal)
    m.mdns.pending = invalid
    if m.mdns.phase = "active"
        phoneSetupMdnsAnnounce(120)
        m.mdns.nextAt = m.setupClock.totalMilliseconds() + 1000
        m.mdns.repeatAnnouncement = true
    end if
end sub

function phoneSetupMdnsSend(bytes as object, destination as object) as boolean
    if m.mdns = invalid or m.mdns.socket = invalid then return false
    if bytes.count() > 1500 then return false
    encoded = CreateObject("roByteArray")
    for each value in bytes
        encoded.push(value)
    end for
    if not m.mdns.socket.setSendToAddress(destination) then return false
    sent = m.mdns.socket.send(encoded, 0, encoded.count())
    if sent <> encoded.count() then print "[setup-discovery] send-failed"
    return sent = encoded.count()
end function

sub phoneSetupMdnsAnnounce(ttl as integer)
    if m.mdns = invalid or m.mdns.records.count() <> 4 then return
    records = m.mdns.records
    packet = phoneSetupDnsMessage(0, true, [], [records[0]], [], [records[1], records[2], records[3]], ttl, false)
    sent = phoneSetupMdnsSend(packet, m.mdns.group)
end sub

sub phoneSetupMdnsStop()
    if m.mdns = invalid then return
    if m.mdns.phase = "active" then phoneSetupMdnsAnnounce(0)
    if m.mdns.socket <> invalid
        m.mdns.socket.dropGroup(m.mdns.group)
        m.mdns.socket.close()
    end if
    m.mdns = invalid
end sub

sub phoneSetupMdnsPoll()
    if m.mdns = invalid then return
    nowMs = m.setupClock.totalMilliseconds()
    if m.session <> invalid
        if m.setupClock.totalSeconds() >= m.session.expiresAt
            phoneSetupMdnsStop()
            return
        end if
    end if
    state = m.mdns
    if state.records.count() <> 4 then return
    for attempt = 0 to 7
        if not state.socket.isReadable() then exit for
        bytes = CreateObject("roByteArray")
        bytes[4095] = 0
        received = state.socket.receive(bytes, 0, 4096)
        if received <= 0 then exit for
        peer = state.socket.getReceivedFromAddress()
        packet = phoneSetupDnsParse(bytes.slice(0, received))
        if state.heard <> true
            state.heard = true
            print "[setup-discovery] packet-received"
        end if
        if packet <> invalid and peer <> invalid
            if phoneSetupMdnsConflict(packet, state.records)
                if state.phase = "active" and not packet.response
                    phoneSetupMdnsAnnounce(120) ' An established name wins over a new probe.
                else if state.phase = "active" and (not state.defended or nowMs - state.defendedAt >= 10000)
                    state.defended = true
                    state.defendedAt = nowMs
                    phoneSetupMdnsAnnounce(120)
                else
                    if state.phase = "active" then phoneSetupMdnsAnnounce(0)
                    state.ordinal++
                    if state.ordinal > 16
                        phoneSetupMdnsStop()
                        return
                    end if
                    state.phase = "probing"
                    state.probes = 0
                    state.defended = false
                    state.nextAt = nowMs + rnd(251) - 1
                    phoneSetupMdnsRefresh()
                end if
            end if
            if not packet.response and not packet.truncated and state.phase = "active" and state.pending = invalid and nowMs - state.lastReply >= 100
                selected = phoneSetupMdnsSelect(packet, state.records)
                if selected.count() > 0
                    legacy = peer.getPort() <> 5353
                    unicast = true
                    for each question in packet.questions
                        for each record in selected
                            if question.key = record.key and not question.qu then unicast = false
                        end for
                    end for
                    if legacy then unicast = true
                    state.pending = {due: nowMs + 20 + rnd(101) - 1, answers: selected, questions: packet.questions, id: packet.id, peer: peer, legacy: legacy, unicast: unicast}
                end if
            end if
        end if
    end for
    if nowMs >= state.nextAt
        if state.phase = "probing"
            if state.probes < 3
                records = state.records
                questions = [{labels: records[1].labels, kind: 255, qu: false}, {labels: records[3].labels, kind: 255, qu: false}]
                packet = phoneSetupDnsMessage(0, false, questions, [], [records[1], records[2], records[3]], [], 120, true)
                sent = phoneSetupMdnsSend(packet, state.group)
                state.probes++
                state.nextAt = nowMs + 250
            else
                state.phase = "active"
                phoneSetupMdnsAnnounce(120)
                print "[setup-discovery] announced"
                state.repeatAnnouncement = true
                state.nextAt = nowMs + 1000
            end if
        else
            phoneSetupMdnsAnnounce(120)
            state.repeatAnnouncement = false
            state.nextAt = nowMs + 60000
        end if
    end if
    if state.pending <> invalid
        reply = state.pending
        if nowMs >= reply.due
            state.pending = invalid
            additional = []
            for i = 1 to 3
                present = false
                for each answer in reply.answers
                    if answer.kind = state.records[i].kind then present = true
                end for
                if not present then additional.push(state.records[i])
            end for
            ttl = 120: id = 0: questions = []: destination = state.group
            if reply.unicast then destination = reply.peer
            if reply.legacy
                ttl = 10: id = reply.id: questions = reply.questions
            end if
            packet = phoneSetupDnsMessage(id, true, questions, reply.answers, [], additional, ttl, reply.legacy)
            ' Legacy DNS additional data is optional; keep it below 512 bytes.
            while reply.legacy and packet.count() > 512 and additional.count() > 0
                additional.pop()
                packet = phoneSetupDnsMessage(id, true, questions, reply.answers, [], additional, ttl, true)
            end while
            sent = phoneSetupMdnsSend(packet, destination)
            state.lastReply = nowMs
        end if
    end if
end sub
