' General full-access default setup is not an own-profile form: it may replace
' the account through the existing identity boundary. Only same-holder proof
' may resolve a captured rejected hash before that boundary reads the roster.
function beginProfileSetupCredential(task as object, entry as object) as boolean
    retireProfileSetupCredential()
    if entry.provider <> "dispatcharr" or m.authMode <> "password" or m.username = "" then return false
    if m.activeUserScope <> invalid or textValue(m.global.activeusersession) <> "" then return false
    if m.global.profileownsigninpending = true then return false
    store = loadUserProfileStore(m.registry, entry.id)
    if store.readOnly = true then return false
    target = invalid
    for each profile in store.profiles
        if profile.id = store.active then target = profile
    end for
    if target = invalid then return false
    if not target.isDefault or (target.role <> "user" and target.role <> "admin") then return false
    holds = {}
    if m.requestGate <> invalid then holds = copyJson(m.requestGate.snapshot.keys)
    nonce = CreateObject("roDeviceInfo").getRandomUUID()
    m.profileSetupCredentialContext = {nonce: nonce, connection: FormatJson(entry), slot: entry.id, base: m.baseUrl, username: m.username, roster: m.registry.read(userProfileStoreKey(entry.id)), account: target.userId.toStr(), ownUsername: target.username, holds: holds}
    m.profileSetupCredentialContext.task = task
    m.global.profileownsigninpending = true
    m.global.profileownsigninnonce = nonce
    return true
end function

function profileSetupCredentialCurrent() as boolean
    context = m.profileSetupCredentialContext
    if context = invalid or m.page <> "setup" then return false
    if context.nonce <> textValue(m.global.profileownsigninnonce) or m.global.profileownsigninpending <> true then return false
    if m.activeUserScope <> invalid or textValue(m.global.activeusersession) <> "" then return false
    if context.slot <> m.selectedConnectionId or context.base <> m.baseUrl or context.username <> m.username or m.authMode <> "password" then return false
    if m.profileSetupCredentialHold = invalid
        if m.task = invalid then return false
        if not context.task.isSameNode(m.task) then return false
    end if
    entry = connectionStoreEntry(m.connectionStore, context.slot)
    if entry = invalid then return false
    return FormatJson(entry) = context.connection and m.registry.read(userProfileStoreKey(context.slot)) = context.roster
end function

' True means consumed (waiting or refused); false permits ordinary connection.
function resolveProfileSetupCredential(result as dynamic) as boolean
    if m.profileSetupCredentialContext = invalid then return false
    if not profileSetupCredentialCurrent()
        if type(result) = "roAssociativeArray" then result.apiKey = ""
        failConnection("Profile access changed. Please sign in again.")
        return true
    end if
    if type(result) <> "roAssociativeArray" then retireProfileSetupCredential() : return false
    if result.ok <> true then retireProfileSetupCredential() : return false
    context = m.profileSetupCredentialContext
    hash = requestGateCredentialHash(textValue(result.apiKey))
    held = false
    if m.requestGate <> invalid then held = m.requestGate.snapshot.keys.doesExist(hash)
    if not held
        retireProfileSetupCredential()
        return false
    end if
    valid = result.phase = "verified" and result.verifiedBaseUrl = context.base and result.accountId = context.account and lcase(textValue(result.accountUsername)) = lcase(context.ownUsername) and lcase(context.username) = lcase(context.ownUsername)
    if type(result.verifiedUser) <> "roAssociativeArray"
        valid = false
    else
        valid = valid and textValue(result.verifiedUser.id) = context.account and lcase(textValue(result.verifiedUser.username)) = lcase(context.ownUsername)
    end if
    if not context.holds.doesExist(hash) then valid = false
    if valid then valid = context.holds[hash].version = m.requestGate.snapshot.keys[hash].version
    if not valid
        result.apiKey = ""
        failConnection("Profile access changed. Please sign in again.")
        return true
    end if
    ticket = invalid
    if m.profileSetupCredentialTicketFactory <> invalid then ticket = m.profileSetupCredentialTicketFactory()
    if ticket = invalid then ticket = CreateObject("roSGNode", "RequestGateTicket")
    ticket.id = CreateObject("roDeviceInfo").getRandomUUID()
    ticket.action = "own-verified"
    ticket.hash = hash
    ticket.holdVersion = context.holds[hash].version
    ticket.credentialNonce = context.nonce
    ticket.observeField("result", "onProfileSetupCredentialResolved")
    context.pending = {ok: true, phase: "verified", apiKey: result.apiKey, accountId: result.accountId, accountUsername: result.accountUsername, verifiedBaseUrl: result.verifiedBaseUrl, verifiedUser: dispatcharrVerifiedAuthority(result.verifiedUser), authModeUsed: result.authModeUsed}
    result.apiKey = ""
    result.verifiedUser = invalid
    m.profileSetupCredentialHold = ticket
    context.task = invalid
    m.profileSetupCredentialClock = CreateObject("roTimespan")
    m.profileSetupCredentialClock.mark()
    m.requestGate.request = ticket
    return true
end function

sub onProfileSetupCredentialResolved(event as object)
    if m.profileSetupCredentialHold = invalid then return
    if not m.profileSetupCredentialHold.isSameNode(event.getRoSGNode()) then return
    decision = event.getData()
    allowed = false
    if type(decision) = "roAssociativeArray" then allowed = decision.allowed = true
    if not profileSetupCredentialCurrent() or not allowed
        failConnection("Could not verify profile access. Please sign in again.")
        return
    end if
    result = copyJson(m.profileSetupCredentialContext.pending)
    retireProfileSetupCredential()
    completeConnection(result)
end sub

sub tickProfileSetupCredential()
    if m.profileSetupCredentialHold = invalid or m.profileSetupCredentialClock = invalid then return
    if m.profileSetupCredentialClock.totalMilliseconds() >= 5000 then failConnection("Could not verify profile access. Please sign in again.")
end sub

sub retireProfileSetupCredential()
    if m.profileSetupCredentialHold <> invalid then m.profileSetupCredentialHold.unobserveField("result")
    context = m.profileSetupCredentialContext
    if context <> invalid
        if type(context.pending) = "roAssociativeArray" then context.pending.apiKey = ""
        if m.global.profileownsigninnonce = context.nonce
            m.global.profileownsigninnonce = ""
            m.global.profileownsigninpending = false
        end if
    end if
    m.profileSetupCredentialContext = invalid
    m.profileSetupCredentialHold = invalid
    m.profileSetupCredentialClock = invalid
end sub
