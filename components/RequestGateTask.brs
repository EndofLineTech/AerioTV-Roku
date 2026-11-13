' One owner serializes state transitions. Task clients cannot overwrite a shared
' AA with stale snapshots; they submit individual Node tickets to this mailbox.
sub init()
    m.top.functionName = "runRequestGate"
end sub

sub runRequestGate()
    port = CreateObject("roMessagePort")
    m.top.observeField("request", port)
    m.gateState = requestGateDefault()
    m.gateLeases = {}
    m.top.snapshot = requestGateCopy(m.gateState)
    m.top.ready = true
    while true
        event = wait(1000, port)
        if type(event) = "roSGNodeEvent"
            if lcase(event.getField()) = "request"
                ticket = event.getData()
                if type(ticket) = "roSGNode" then processRequestGateTicket(ticket)
            end if
        end if
    end while
end sub

sub processRequestGateTicket(ticket as object)
    now = CreateObject("roDateTime").asSeconds()
    for each id in m.gateLeases.keys()
        if m.gateLeases[id].issued + 300 < now then m.gateLeases.delete(id)
    end for
    before = FormatJson(m.gateState)
    result = {allowed: false, reason: "invalid-ticket", probe: false, deadline: 0}
    id = textValue(ticket.id)
    if id = "" then return
    action = ticket.action
    if action = "acquire"
        server = requestGateServer(ticket.url)
        hash = lcase(ticket.hash)
        probe = ticket.probe
        if probe
            ' A held-key exception is only for the designated slow /me probe,
            ' never arbitrary browsing/media or a user pressing Switch again.
            probe = CreateObject("roRegex", "/api/accounts/users/me/([?#].*)?$", "").isMatch(ticket.url)
        end if
        permit = requestGatePermit(m.gateState, server, hash, now, probe)
        result = {allowed: permit.allowed, reason: permit.reason, probe: permit.probe, deadline: permit.until}
        if permit.allowed
            if m.gateLeases.count() >= 256
                result.allowed = false
                result.reason = "gate-busy"
            else
                m.gateState = permit.state
                m.gateLeases[id] = {server: server, hash: hash, probe: permit.probe, issued: now}
            end if
        end if
    else if action = "observe" or action = "release"
        if m.gateLeases.doesExist(id)
            lease = m.gateLeases[id]
            m.gateLeases.delete(id)
            if action = "observe"
                body = ticket.body
                if len(body) > 4096 then body = ""
                previouslyHeld = m.gateState.keys.doesExist(lease.hash)
                m.gateState = requestGateObserve(m.gateState, lease.server, lease.hash, ticket.status, ticket.headers, body, now, lease.probe)
                if not previouslyHeld and m.gateState.keys.doesExist(lease.hash)
                    m.top.notice = {kind: "key-rejected", hash: lease.hash, server: lease.server}
                end if
            end if
            result = {allowed: true, reason: "", probe: false, deadline: 0}
        end if
        ' Keep no error body or signed URL on the broker's last mailbox node.
        ticket.body = ""
        ticket.headers = {}
        ticket.url = ""
    else if action = "prompt"
        prompt = requestGatePrompt(m.gateState, ticket.hash)
        m.gateState = prompt.state
        result = {allowed: true, show: prompt.show, reason: "", probe: false, deadline: 0}
    end if
    if FormatJson(m.gateState) <> before then m.top.snapshot = requestGateCopy(m.gateState)
    ticket.result = result
end sub
