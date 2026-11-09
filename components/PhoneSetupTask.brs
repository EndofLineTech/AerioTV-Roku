sub init()
    m.top.functionName = "phoneSetupListen"
end sub

function phoneSetupCancelled() as boolean
    return m.top.cancelRequested = true
end function

sub phoneSetupListen()
    m.setupClock = CreateObject("roTimespan")
    m.setupClock.mark()
    m.setupPort = CreateObject("roMessagePort")
    m.setupListener = invalid
    m.setupClient = invalid
    m.material = invalid
    m.generation = 0
    m.exitInfo = {kind: "closed"}
    device = CreateObject("roDeviceInfo")
    os = device.getOSVersion()
    if os.major.toInt() < 15 or (os.major = "15" and os.minor.toInt() < 2)
        m.top.info = {kind: "unavailable", message: "Setup requires Roku OS 15.2 or later."}
        return
    end if
    ip = ""
    addresses = device.getIPAddrs()
    for each name in addresses
        candidate = addresses[name]
        if instr(1, candidate, ".") > 0 and left(candidate, 4) <> "127." and candidate <> "0.0.0.0"
            ip = candidate
            exit for
        end if
    end for
    if ip = ""
        m.top.info = {kind: "offline"}
        return
    end if
    nameBytes = CreateObject("roByteArray")
    nameBytes.fromAsciiString(device.getFriendlyName())
    if not phoneSetupUtf8Valid(nameBytes) then nameBytes.fromAsciiString("AerioTV")
    limited = phoneSetupNameBytes(nameBytes)
    nameBytes = CreateObject("roByteArray")
    for each value in limited
        nameBytes.push(value)
    end for
    if nameBytes.count() = 0 then nameBytes.fromAsciiString("AerioTV")
    m.setupName = nameBytes.toAsciiString()
    m.setupNameBytes = nameBytes
    m.setupIp = ip
    ' Never open a port until an approved local entropy provider succeeds.
    m.top.info = {kind: "preparing"}
    m.material = phoneSetupNewMaterial(phoneSetupCancelled)
    if phoneSetupCancelled()
        m.material = invalid
        return
    end if
    if m.material = invalid
        m.top.info = {kind: "unavailable", message: "Secure setup randomness is not available on this build. Use manual setup."}
        return
    end if
    listener = CreateObject("roStreamSocket")
    listener.setMessagePort(m.setupPort)
    address = CreateObject("roSocketAddress")
    address.setPort(0)
    if not listener.setAddress(address) or not listener.listen(4)
        listener.close()
        m.material = invalid
        m.top.info = {kind: "error", message: "Could not open the setup listener. Try again."}
        return
    end if
    listener.notifyReadable(true)
    m.setupListener = listener
    m.listenerPort = listener.getAddress().getPort()
    phoneSetupPublishReady()
    m.session = newPhoneSetupSession("0", m.setupClock.totalSeconds())
    while not phoneSetupCancelled()
        if m.setupClock.totalSeconds() >= m.session.expiresAt
            m.exitInfo = {kind: "expired"}
            exit while
        end if
        if listener.isReadable()
            client = listener.accept()
            if client <> invalid
                m.setupClient = client
                client.setMessagePort(m.setupPort)
                client.notifyReadable(true)
                client.notifyWritable(true)
                reply = phoneSetupHandle(client)
                client.close()
                m.setupClient = invalid
                if reply <> invalid
                    if reply.terminal = true then exit while
                    if reply.ok
                        ' Handle wrote the entire 200 before this field is set.
                        listener.close()
                        m.setupListener = invalid
                        m.material = invalid
                        m.top.info = {kind: "accepted"}
                        m.top.result = reply.payload
                        return
                    end if
                    if reply.rotateRequired = true and not phoneSetupCancelled()
                        m.top.info = {kind: "rotating"}
                        material = phoneSetupNewMaterial(phoneSetupCancelled)
                        m.material = invalid
                        if material = invalid
                            m.exitInfo = {kind: "unavailable", message: "A new secure setup code could not be generated. Use manual setup."}
                            exit while
                        end if
                        m.generation++
                        transition = rotatePhoneSetupSession(m.session, m.generation.toStr(), m.setupClock.totalSeconds())
                        if not transition.ok
                            m.exitInfo = {kind: "expired"}
                            exit while
                        end if
                        m.session = transition.session
                        m.material = material
                        phoneSetupPublishReady()
                    end if
                end if
            end if
        end if
        event = wait(20, m.setupPort)
    end while
    if m.setupClient <> invalid then m.setupClient.close()
    listener.close()
    m.setupListener = invalid
    m.setupClient = invalid
    m.material = invalid
    m.session = invalid
    m.top.info = m.exitInfo
end sub

sub phoneSetupPublishReady()
    public = phoneSetupHexBytes(m.material.publicHex)
    link = phoneSetupLink(m.setupIp, m.listenerPort, m.material.code, public.toBase64String(), m.setupNameBytes)
    rows = phoneSetupQr(link)
    m.top.info = {kind: "ready", name: m.setupName, code: m.material.code, fingerprint: phoneSetupFingerprint(m.material.publicHex), link: link, rows: rows}
end sub

function phoneSetupHandle(client as object) as dynamic
    m.replyClock = invalid
    reader = newPhoneSetupReader()
    reader.body = CreateObject("roByteArray")
    idle = CreateObject("roTimespan")
    idle.mark()
    while not reader.ready and reader.response = invalid
        if phoneSetupCancelled() or m.setupClock.totalSeconds() >= m.session.expiresAt then return invalid
        if idle.totalMilliseconds() >= 15000 then return invalid
        if client.isReadable()
            bytes = CreateObject("roByteArray")
            bytes[8191] = 0
            received = client.receive(bytes, 0, 8192)
            if received = 0 then return invalid
            if received > 0
                idle.mark()
                bytes = bytes.slice(0, received)
                phoneSetupFeed(reader, bytes, m.session.used or m.session.closed)
            else if not client.eOK()
                return invalid
            end if
        end if
        if not reader.ready and reader.response = invalid then event = wait(20, m.setupPort)
    end while
    if reader.response <> invalid
        phoneSetupWrite(client, reader.response.status, reader.response.error)
        return invalid
    end if
    ' All cryptography, validation, and full response must fit this 10s budget.
    m.replyClock = CreateObject("roTimespan")
    m.replyClock.mark()
    result = phoneSetupFailure(400, "bad_request")
    if phoneSetupUtf8Valid(reader.body)
        result = phoneSetupOpen(reader.body.toAsciiString(), m.material, phoneSetupCancelled)
    end if
    reader = invalid
    if phoneSetupCancelled() then return invalid
    outcome = "bad_request"
    if result.ok then outcome = "accepted"
    if result.error = "wrong_code" then outcome = "wrong_code"
    transition = finishPhoneSetupAttempt(m.session, m.session.generation, m.setupClock.totalSeconds(), outcome)
    m.session = transition.session
    if transition.error = "expired"
        transition.error = "forbidden"
        transition.status = 403
    end if
    if m.replyClock.totalMilliseconds() >= 10000
        m.exitInfo = {kind: "error", message: "Secure setup exceeded this device's response time budget. Use manual setup."}
        return {ok: false, terminal: true}
    end if
    written = phoneSetupWrite(client, transition.status, transition.error)
    if not written
        if transition.ok
            m.exitInfo = {kind: "error", message: "The connection ended before setup was accepted. Get a new code to try again."}
            return {ok: false, terminal: true}
        end if
        ' Without the complete third 403, end this session rather than rotate
        ' behind a sender that never received the specified attempt response.
        if transition.rotateRequired = true
            m.exitInfo = {kind: "error", message: "The connection ended before setup could reply. Get a new code to try again."}
            return {ok: false, terminal: true}
        end if
        return transition
    end if
    if transition.ok then return {ok: true, payload: result.payload}
    return transition
end function

function phoneSetupWrite(client as object, status as integer, reason as dynamic) as boolean
    if reason = invalid then reason = ""
    bytes = CreateObject("roByteArray")
    bytes.fromAsciiString(phoneSetupHttpResponse(status, reason))
    sent = 0
    clock = CreateObject("roTimespan")
    clock.mark()
    while sent < bytes.count() and not phoneSetupCancelled() and clock.totalMilliseconds() < 2000
        if m.replyClock <> invalid
            if m.replyClock.totalMilliseconds() >= 10000 then return false
        end if
        if client.isWritable()
            count = client.send(bytes, sent, bytes.count() - sent)
            if count > 0 then sent += count
            if count <= 0 and not client.eOK() then return false
        end if
        if sent < bytes.count() then event = wait(10, m.setupPort)
    end while
    m.replyClock = invalid
    return sent = bytes.count()
end function
