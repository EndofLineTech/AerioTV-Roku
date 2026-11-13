' Raw credential binding lives only on the active Scene, not in the broker,
' snapshots, tickets or diagnostics. A slot switch retires it on the next tick.
sub rememberHeldRequestGateBinding()
    if m.requestGate = invalid or m.apiKey = "" then return
    state = m.requestGate.snapshot
    if type(state) <> "roAssociativeArray" then return
    hash = requestGateCredentialHash(m.apiKey)
    if not state.keys.doesExist(hash) then return
    entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    if entry = invalid or entry.provider <> "dispatcharr" then return
    m.requestGateBinding = {slot: entry.id, base: m.baseUrl, key: m.apiKey, hash: hash, account: entry.accountId}
    if not state.keys[hash].prompted and m.requestGatePrompt = invalid
        ticket = CreateObject("roSGNode", "RequestGateTicket")
        ticket.id = CreateObject("roDeviceInfo").getRandomUUID()
        ticket.action = "prompt"
        ticket.hash = hash
        ticket.observeField("result", "onRequestGatePrompt")
        m.requestGatePrompt = ticket
        m.requestGate.request = ticket
    end if
end sub

sub onRequestGatePrompt(event as object)
    if not isCurrentTaskEvent(event, m.requestGatePrompt) then return
    m.requestGatePrompt.unobserveField("result")
    m.requestGatePrompt = invalid
    result = event.getData()
    if result.show <> true or m.requestGateBinding = invalid then return
    binding = m.requestGateBinding
    if binding.slot <> m.selectedConnectionId or binding.base <> m.baseUrl then return
    entry = connectionStoreEntry(m.connectionStore, binding.slot)
    if entry = invalid then return
    message = "Dispatcharr no longer accepts the API key for " + entry.name + ". It may have been changed on the server. Sign in with your Dispatcharr username and password to reconnect."
    openConnectionDialog("API key no longer valid", message, [{title: "Not Now", action: "cancel"}])
end sub

sub onRequestGateTick()
    if m.requestGateBinding = invalid or m.requestGate = invalid then return
    binding = m.requestGateBinding
    if binding.slot <> m.selectedConnectionId or binding.base <> m.baseUrl or (m.apiKey <> "" and m.apiKey <> binding.key)
        m.requestGateBinding = invalid
        if m.requestGateRecheck <> invalid then m.requestGateRecheck.cancelRequested = true
        return
    end if
    if m.requestGateRecheck <> invalid then return
    if binding.account = "" then return
    state = m.requestGate.snapshot
    if type(state) <> "roAssociativeArray" then return
    if not state.keys.doesExist(binding.hash)
        m.requestGateBinding = invalid
        return
    end if
    due = requestGatePermit(state, requestGateServer(binding.base), binding.hash, uiNow(), true)
    if not due.allowed then return
    task = CreateObject("roSGNode", "RequestGateRecheckTask")
    tagTaskForCurrentUser(task)
    task.baseUrl = binding.base
    task.apiKey = binding.key
    task.accountId = binding.account
    task.observeField("result", "onRequestGateRecheck")
    m.requestGateRecheck = task
    task.control = "RUN"
end sub

sub onRequestGateRecheck(event as object)
    if not isCurrentTaskEvent(event, m.requestGateRecheck) then return
    m.requestGateRecheck.unobserveField("result")
    m.requestGateRecheck = invalid
    result = event.getData()
    if result.ok = true
        if m.requestGateBinding <> invalid
            binding = m.requestGateBinding
            if binding.slot = m.selectedConnectionId and binding.base = m.baseUrl and m.apiKey = "" then m.apiKey = binding.key
        end if
        m.requestGateBinding = invalid
        showNotice("Dispatcharr accepts the API key again. Reconnect when ready.")
    end if
end sub
