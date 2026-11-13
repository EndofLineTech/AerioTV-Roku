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
function requestGatePermitActive(permit as object) as boolean
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
