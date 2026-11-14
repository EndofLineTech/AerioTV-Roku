' Task-thread client. Renderers use the snapshot helper rather than blocking.
' The mandatory flag is set by normal app bootstrap; isolated primitive probes
' without application startup have no shared broker or production credentials.
function requestGateBroker() as dynamic
    if m.global = invalid then return invalid
    if type(m.global) = "roSGNode"
        if m.global.hasField("requestGate") then return m.global["requestGate"]
        if m.global.hasField("requestgate") then return m.global["requestgate"]
        return invalid
    end if
    return m.global.requestGate
end function

function requestGateMandatory() as boolean
    if m.global = invalid then return false
    if type(m.global) = "roSGNode"
        if m.global.hasField("requestGateRequired") then return m.global["requestGateRequired"] = true
        if m.global.hasField("requestgaterequired") then return m.global["requestgaterequired"] = true
        return false
    end if
    return m.global.requestGateRequired = true
end function

function requestGateTaskSessionCurrent() as boolean
    if m.top = invalid then return true
    if requestGateRecoveryProbeTagged() then return requestGateRecoveryProbeCurrent()
    if type(m.top) = "roAssociativeArray"
        if not m.top.doesExist("aeriosession") then return true
    else
        if not m.top.hasField("aeriosession") then return true
    end if
    if m.global = invalid then return false
    if requestGateProfileClosed() then return false
    if type(m.global) = "roSGNode"
        if not m.global.hasField("activeusersession") then return false
    end if
    captured = m.top.aeriosession
    current = m.global.activeusersession
    if type(captured) <> "String" and type(captured) <> "roString" then return false
    if type(current) <> "String" and type(current) <> "roString" then return false
    return captured <> "" and captured = current
end function

' A rejected holder has no authenticated session. Its sole transport exception
' is the exact /me slow-probe Task under a separate, memory-only Scene nonce.
' This does not open the global content/PIN gate or admit generic Tasks.
function requestGateRecoveryProbeTagged() as boolean
    if m.top = invalid then return false
    if type(m.top) = "roAssociativeArray"
        if not m.top.doesExist("recoveryNonce") then return false
    else
        if not m.top.hasField("recoveryNonce") then return false
    end if
    return textValue(m.top.recoveryNonce) <> ""
end function

function requestGateRecoveryProbeCurrent() as boolean
    if not requestGateRecoveryProbeTagged() or m.global = invalid then return false
    if type(m.top) = "roAssociativeArray"
        if m.top.subtype = invalid then return false
    end if
    if m.top.subtype() <> "RequestGateRecheckTask" then return false
    if type(m.global) = "roSGNode"
        if not m.global.hasField("requestgaterecovery") then return false
    end if
    nonce = textValue(m.top.recoveryNonce)
    if not CreateObject("roRegex", "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", "").isMatch(nonce) then return false
    if nonce <> textValue(m.global.requestgaterecovery) then return false
    if textValue(m.global.activeusersession) <> "" then return false
    if requestGateProfileSwitching() or m.global.profileownsigninpending = true then return false
    return true
end function

function requestGateProfileClosed() as boolean
    if m.global = invalid then return false
    if type(m.global) = "roSGNode"
        if m.global.hasField("profilegateclosed")
            return m.global.profilegateclosed = true
        end if
        return false
    end if
    return m.global.profilegateclosed = true
end function

function requestGateProfileSwitching() as boolean
    if m.global = invalid then return false
    if type(m.global) = "roSGNode"
        if not m.global.hasField("profileswitchpending") then return false
    end if
    return m.global.profileswitchpending = true
end function

function requestGateCredentialHash(key as string) as string
    if key = "" then return ""
    bytes = CreateObject("roByteArray")
    bytes.fromAsciiString(key)
    digest = CreateObject("roEVPDigest")
    if digest = invalid then return ""
    if digest.setup("sha256") <> 0 then return ""
    return lcase(digest.process(bytes))
end function

' Cached authorized data is still an account operation; a cache hit must not
' sidestep an active key hold or host park. This check never starts a request.
function requestGateAccessAllowed(url as string, key as string) as boolean
    if not requestGateTaskSessionCurrent() then return false
    broker = requestGateBroker()
    if broker = invalid then return not requestGateMandatory()
    if not broker.ready then return false
    state = broker.snapshot
    if type(state) <> "roAssociativeArray" then return false
    hash = requestGateCredentialHash(key)
    if key <> "" and hash = "" then return false
    permit = requestGatePermit(state, requestGateServer(url), hash, CreateObject("roDateTime").asSeconds(), false)
    return permit.allowed
end function

function requestGateExchange(broker as object, ticket as object) as dynamic
    ' Never mutate/re-submit a Node already visible to another thread. A queued
    ' field event carries a Node reference, not a snapshot of its old fields.
    wire = CreateObject("roSGNode", "RequestGateTicket")
    wire.setFields({id: ticket.id, action: ticket.action, url: ticket.url, hash: ticket.hash, probe: ticket.probe, status: ticket.status, headers: ticket.headers, body: ticket.body})
    port = CreateObject("roMessagePort")
    wire.observeField("result", port)
    broker.request = wire
    clock = CreateObject("roTimespan")
    clock.mark()
    while clock.totalMilliseconds() < 2000
        if type(wire.result) = "roAssociativeArray"
            result = wire.result
            wire.unobserveField("result")
            ticket.result = result
            return result
        end if
        wait(25, port)
    end while
    wire.unobserveField("result")
    return invalid
end function

function requestGateAcquire(url as string, key as string, probe = false as boolean) as object
    denied = {allowed: false, reason: "gate-unavailable", ticket: invalid}
    if not requestGateTaskSessionCurrent() then return {allowed: false, reason: "stale-session", ticket: invalid}
    if requestGateRecoveryProbeTagged()
        if not probe or url <> normalizeBaseUrl(m.top.baseUrl) + "/api/accounts/users/me/" then return {allowed: false, reason: "recovery-probe-only", ticket: invalid}
    end if
    broker = requestGateBroker()
    if broker = invalid
        if requestGateMandatory() then return denied
        return {allowed: true, reason: "", ticket: invalid}
    end if
    clock = CreateObject("roTimespan")
    clock.mark()
    port = CreateObject("roMessagePort")
    while not broker.ready and clock.totalMilliseconds() < 2000
        wait(25, port)
    end while
    if not broker.ready then return denied
    hash = requestGateCredentialHash(key)
    if key <> "" and hash = "" then return denied
    ticket = CreateObject("roSGNode", "RequestGateTicket")
    ticket.id = CreateObject("roDeviceInfo").getRandomUUID()
    ticket.action = "acquire"
    ticket.url = requestGateTicketUrl(url, probe)
    ticket.hash = hash
    ticket.probe = probe
    result = requestGateExchange(broker, ticket)
    if result = invalid then return denied
    return {allowed: result.allowed, reason: result.reason, deadline: result.deadline, probe: result.probe, ticket: ticket}
end function

sub requestGateReport(permit as object, response as object)
    if permit.ticket = invalid then return
    broker = requestGateBroker()
    if broker = invalid then return
    ticket = permit.ticket
    ticket.action = "observe"
    ticket.status = response.status
    ticket.headers = {}
    if response.status = 429
        delay = httpRetryAfter(response.headers, CreateObject("roDateTime").asSeconds())
        if delay >= 0 then ticket.headers = {"Retry-After": delay.toStr()}
    end if
    ticket.body = ""
    if httpDispatcharrKeyRejected(response.status, response.body)
        ' Never forward arbitrary server JSON (which may echo credentials),
        ' cookies or authorization headers through the shared mailbox.
        ticket.body = "{" + chr(34) + "detail" + chr(34) + ":" + chr(34) + "Invalid API key" + chr(34) + "}"
    end if
    requestGateExchange(broker, ticket)
end sub

sub requestGateRelease(permit as object)
    requestGateReport(permit, {status: 0, headers: {}, body: ""})
end sub

sub requestGateReportEvent(permit as object, event as object, body = "" as string)
    if event.getResponseCode() = 401 and body = "" then body = event.getString()
    if len(body) > 4096 then body = ""
    requestGateReport(permit, {status: event.getResponseCode(), headers: event.getResponseHeaders(), body: body})
end sub

' Nonblocking cancellation check for an already admitted Task transfer. The
' lease's own slow probe is exempt from its key hold, never from a server park.
' Submitted recording settlement is receive-only; it admits no new request.
function requestGatePermitActive(permit as object) as boolean
    if not requestGateTaskSessionCurrent() and not requestGateSubmittedScheduleWaiting(permit) then return false
    if not permit.allowed then return false
    if permit.ticket = invalid then return not requestGateMandatory()
    broker = requestGateBroker()
    if broker = invalid then return false
    state = broker.snapshot
    if type(state) <> "roAssociativeArray" then return false
    if state.overflow then return false
    server = requestGateServer(permit.ticket.url)
    if state.servers.doesExist(server)
        if state.servers[server] > CreateObject("roDateTime").asSeconds() then return false
    end if
    hash = permit.ticket.hash
    if hash <> "" and state.keys.doesExist(hash) and not permit.probe then return false
    return true
end function

' Receive-only settlement of one POST already started under a valid lease.
' Acquire remains session-bound, so this cannot send or retry any old request.
function requestGateSubmittedScheduleWaiting(permit as object) as boolean
    if permit.submittedSchedule <> true or permit.allowed <> true or permit.ticket = invalid then return false
    if m.top = invalid then return false
    if type(m.top) = "roAssociativeArray"
        if m.top.subtype = invalid then return false
    end if
    if m.top.subtype() <> "DvrRecordingTask" then return false
    if m.top.action <> "schedule" or m.top.scheduleSubmitted <> true or m.top.cancelRequested = true then return false
    if requestGateServer(permit.ticket.url) <> requestGateServer(m.top.baseUrl) then return false
    ' Broker tickets deliberately redact non-probe paths. The exact submitted
    ' URL stays only on this Task's already-started transfer, never the mailbox.
    return permit.submittedScheduleUrl = normalizeBaseUrl(m.top.baseUrl) + "/api/channels/recordings/"
end function
