' Private staged-switch pipeline. Readiness stays off until native integration,
' outgoing sync settlement and the remaining roster/default paths qualify.
function handleUserProfileSwitchRosterResult(result as object) as boolean
    if m.profileSwitchRosterReady <> true then return false
    context = m.profileSwitchContext
    if context = invalid then return false
    if context.phase = "authenticate"
        beginUserProfileSwitchRosterRead(result)
        return true
    end if
    if context.phase = "roster"
        finishUserProfileSwitchRosterRead(result)
        return true
    end if
    if context.phase = "lineup"
        expectedUser = invalid
        if type(context.authentication) = "roAssociativeArray" then expectedUser = context.authentication.verifiedUser
        matches = dispatcharrAuthorityComparable(expectedUser) and dispatcharrAuthorityComparable(result.verifiedUser)
        if matches then matches = dispatcharrAuthorizationSignature(result.verifiedUser) = dispatcharrAuthorizationSignature(expectedUser)
        if not matches
            rollbackUserProfileSwitch("Profile permissions changed while verifying protection. Please retry.")
            return true
        end if
        proof = {ok: true, phase: "verified", apiKey: result.apiKey, accountId: result.accountId, accountUsername: result.accountUsername, verifiedBaseUrl: result.verifiedBaseUrl, verifiedUser: result.verifiedUser}
        if not userProfileSwitchRosterAccessCurrent(context, proof)
            rollbackUserProfileSwitch("Profile access changed before activation. Saved data was retained.")
            return true
        end if
    end if
    return false
end function

function userProfileSwitchRosterAccessCurrent(context as object, verified as object) as boolean
    now = CreateObject("roDateTime").asSeconds()
    memory = userProfileSwitchRosterMemory(context)
    if context.unavailableChild = true
        if m.page <> "profile-unavailable" then return false
        return dispatcharrSyncUnavailableChildRosterAccessCurrent(m.registry, context, verified, now, m.global.activeusersession, m.activeUserScope, textValue(m.apiKey), memory)
    end if
    return dispatcharrSyncSwitchRosterAccessCurrent(m.registry, context, verified, now, m.global.activeusersession, m.activeUserScope, memory)
end function

function userProfileSwitchRosterMemory(context as object) as object
    memory = {}
    if context.connection.remember or type(m.profileSessionKeys) <> "roAssociativeArray" then return memory
    bucket = preferenceScope(context.connection.url + "|" + context.connection.id + "|" + context.target.id)
    if not m.profileSessionKeys.doesExist(bucket) then return memory
    keyName = userProfileKeyName(context.connection.id, context.target.id)
    if context.target.isDefault then keyName = connectionRegistryKey(context.connection.id)
    memory[keyName] = m.profileSessionKeys[bucket]
    return memory
end function

sub beginUserProfileSwitchRosterRead(verified as object)
    context = m.profileSwitchContext
    if context = invalid then return
    if not userProfileSwitchRosterAccessCurrent(context, verified)
        rollbackUserProfileSwitch("Profile access changed. Please verify access again.")
        return
    end if
    context.authentication = {ok: true, phase: "verified", apiKey: context.key, accountId: verified.accountId, accountUsername: verified.accountUsername, verifiedBaseUrl: verified.verifiedBaseUrl, verifiedUser: dispatcharrVerifiedAuthority(verified.verifiedUser)}
    context.targetAuthMode = dispatcharrHeaderMode(textValue(verified.authModeUsed))
    closeUserProfileSwitchTask()
    task = invalid
    if m.profileSwitchReadTaskFactory <> invalid then task = m.profileSwitchReadTaskFactory()
    if task = invalid then task = CreateObject("roSGNode", "DispatcharrSyncReadTask")
    tagTaskForCurrentUser(task)
    task.baseUrl = context.connection.url
    task.apiKey = context.key
    task.accountId = verified.accountId
    task.username = verified.accountUsername
    task.authMode = context.targetAuthMode
    task.observeField("result", "onUserProfileSwitchResult")
    task.observeField("state", "onUserProfileSwitchState")
    context.phase = "roster"
    m.profileSwitchTask = task
    m.top.findNode("profileGateMessage").text = "Reading profile protection..."
    task.control = "RUN"
end sub

sub finishUserProfileSwitchRosterRead(read as object)
    context = m.profileSwitchContext
    if context = invalid or type(context.authentication) <> "roAssociativeArray" then return
    valid = read.allowWrite = false and read.verifiedBaseUrl = context.connection.url and textValue(read.accountId) = context.target.userId.toStr() and lcase(textValue(read.accountUsername)) = lcase(context.target.username)
    if not dispatcharrAuthorityComparable(read.verifiedUser) then valid = false
    if not valid
        rollbackUserProfileSwitch("Could not verify this profile's protection. Saved data was retained.")
        return
    end if
    proof = {ok: true, phase: "verified", apiKey: context.key, accountId: read.accountId, accountUsername: read.accountUsername, verifiedBaseUrl: read.verifiedBaseUrl, verifiedUser: dispatcharrVerifiedAuthority(read.verifiedUser)}
    decoded = {ok: true, rows: [], removed: []}
    apply = false
    if read.state = "ready"
        if read.profilesState = "ready"
            wire = invalid
            if type(read.data) = "roAssociativeArray"
                categories = read.data["categories"]
                if type(categories) = "roAssociativeArray"
                    category = categories["profiles"]
                    if type(category) = "roAssociativeArray" then wire = category["data"]
                end if
            end if
            decoded = dispatcharrSyncRosterDecode(wire)
            apply = m.profileRosterEnabled <> false
        else if read.profilesState <> "absent"
            rollbackUserProfileSwitch("Saved profile protection could not be read. Please retry.")
            return
        end if
    else if read.state <> "missing" and read.state <> "legacy"
        rollbackUserProfileSwitch("Could not read profile protection. Please retry.")
        return
    end if
    if context.unavailableChild = true
        if m.page <> "profile-unavailable" then return
        saved = commitDispatcharrUnavailableChildRosterPull(m.registry, context, proof, decoded, apply, CreateObject("roDateTime").asSeconds(), m.global.activeusersession, m.activeUserScope, textValue(m.apiKey), userProfileSwitchRosterMemory(context))
    else
        saved = commitDispatcharrSwitchRosterPull(m.registry, context, proof, decoded, apply, CreateObject("roDateTime").asSeconds(), m.global.activeusersession, m.activeUserScope, userProfileSwitchRosterMemory(context))
    end if
    if not saved.ok and saved.reason = "cleanup-required"
        saved = commitDispatcharrSwitchRosterCleanup(m.registry, context, proof, decoded, apply, CreateObject("roDateTime").asSeconds(), m.global.activeusersession, m.activeUserScope, textValue(m.apiKey), userProfileSwitchRosterMemory(context))
    end if
    if not saved.ok and saved.reason = "outgoing-removal" and m.profileDefaultRetirementReady = true
        beginUserProfileDefaultRetirement(context, proof, decoded, apply)
        return
    end if
    if not saved.ok and saved.reason = "target-removed"
        retireTombstonedUserProfileSwitchTarget(context, proof, decoded, apply)
        return
    end if
    if not saved.ok
        m.userProfileRecoveryRequired = saved.recoveryRequired
        if saved.reason = "outgoing-removal" and saved.needsDefaultSwitch = true then m.userProfileRecoveryRequired = true
        rollbackUserProfileSwitch("Could not safely stage profile protection. Saved data was retained.")
        return
    end if
    closeUserProfileSwitchTask()
    context.authentication = proof
    context.target = saved.target
    context.rosterSuggestions = saved.suggestions
    publishUserProfileSwitchRosterStore(context, saved)
    if saved.outgoingProtectionChanged
        if context.unavailableChild = true then m.userProfileRecoveryRequired = true
        rollbackUserProfileSwitch("Outgoing profile access changed. Please verify access again.")
        return
    end if
    ' Either authenticated or unavailable Child may lose its adult purpose to
    ' imported holder changes/removals. Do not expose another PIN/name first.
    if not userProfileSwitchRosterAccessCurrent(context, proof)
        if textValue(context.managementNonce) <> "" and textValue(m.profileManagementNonce) = textValue(context.managementNonce)
            m.profileManagementGrant = invalid
            m.profileManagementNonce = ""
        end if
        rollbackUserProfileSwitch("Profile management access changed. Please unlock management again.")
        return
    end if
    if context.target.role = "child" and m.profileChildAccessReady <> true
        rollbackUserProfileSwitch("Child profile access is not available yet. The previous profile was retained.")
        return
    end if
    if context.target.pinType <> "none" and not userProfilePinGrantMatches(context.pin, context.connection.id, context.target)
        context.phase = "pin"
        if beginProfilePinGate(context.target, "switch-roster", context.nonce) then return
        rollbackUserProfileSwitch("Could not open this profile's PIN. The previous profile was retained.")
        return
    end if
    startUserProfileSwitchRosterLineup()
end sub

sub publishUserProfileSwitchRosterStore(context as object, saved as object)
    context.store = saved.store
    m.userProfileStore = saved.store
    if type(saved.preferenceStore) = "roAssociativeArray" then m.preferenceStore = saved.preferenceStore
    if type(saved.removed) = "roArray" and type(m.profileSessionKeys) = "roAssociativeArray"
        for each removed in saved.removed
            bucket = preferenceScope(context.connection.url + "|" + context.connection.id + "|" + removed.id)
            m.profileSessionKeys.delete(bucket)
        end for
    end if
end sub

sub retireTombstonedUserProfileSwitchTarget(context as object, proof as object, decoded as object, apply as boolean)
    ' The read has published and wiped its thread key. Close/wipe the Scene's
    ' node before deleting its inactive holder; keep only the incoming nonce
    ' as a storage-admission lifecycle, never an authenticated target scope.
    if m.profileSwitchTask <> invalid then m.profileSwitchTask.apiKey = ""
    closeUserProfileSwitchTask()
    saved = commitDispatcharrSwitchTargetRetirement(m.registry, context, proof, decoded, apply, CreateObject("roDateTime").asSeconds(), m.global.activeusersession, m.activeUserScope, textValue(m.apiKey), userProfileSwitchRosterMemory(context))
    context.key = ""
    context.pin = invalid
    if type(context.authentication) = "roAssociativeArray" then context.authentication.apiKey = ""
    proof.apiKey = ""
    if not saved.ok
        m.userProfileRecoveryRequired = saved.recoveryRequired
        if saved.reason = "outgoing-removal" and saved.needsDefaultSwitch = true then m.userProfileRecoveryRequired = true
        rollbackUserProfileSwitch("Could not safely retire the removed profile. Saved data was retained.")
        return
    end if
    publishUserProfileSwitchRosterStore(context, saved)
    if saved.outgoingProtectionChanged and context.unavailableChild = true then m.userProfileRecoveryRequired = true
    if type(context.management) = "roAssociativeArray" and textValue(context.managementNonce) <> "" and textValue(m.profileManagementNonce) = textValue(context.managementNonce)
        for each removed in saved.removed
            if removed.id = textValue(context.management.id)
                m.profileManagementGrant = invalid
                m.profileManagementNonce = ""
            end if
        end for
    end if
    rollbackUserProfileSwitch("This profile was removed on another device. The previous profile was retained.")
end sub

sub onUserProfileSwitchRosterPin(nonce as string)
    context = m.profileSwitchContext
    if context = invalid or context.nonce <> nonce or context.phase <> "pin" then return
    if not userProfilePinGrantMatches(m.profileUnlockGrant, context.connection.id, context.target) then return
    current = loadUserProfileStore(m.registry, context.connection.id)
    if not userProfileSwitchAcceptPinStore(context.store, current, context.target.id, m.profileUnlockGrant)
        rollbackUserProfileSwitch("Profile protection changed while entering the PIN. Please retry.")
        return
    end if
    context.store = current
    for each profile in current.profiles
        if profile.id = context.target.id then context.target = profile
    end for
    context.pin = m.profileUnlockGrant
    m.profileUnlockGrant = invalid
    startUserProfileSwitchRosterLineup()
end sub

sub startUserProfileSwitchRosterLineup()
    context = m.profileSwitchContext
    if context = invalid then return
    if m.global.profileswitchpending <> true then return
    if m.global.profilegateclosed and context.phase <> "pin" then return
    if not userProfileSwitchRosterAccessCurrent(context, context.authentication)
        rollbackUserProfileSwitch("Profile access changed. Please verify access again.")
        return
    end if
    if not dispatcharrAuthorityComparable(context.authentication.verifiedUser)
        rollbackUserProfileSwitch("Could not verify current profile permissions. Please retry.")
        return
    end if
    if context.target.pinType <> "none" and not userProfilePinGrantMatches(context.pin, context.connection.id, context.target)
        rollbackUserProfileSwitch("This profile needs its current PIN. Please retry.")
        return
    end if
    closeUserProfileSwitchTask()
    task = invalid
    if m.profileSwitchTaskFactory <> invalid then task = m.profileSwitchTaskFactory()
    if task = invalid then task = CreateObject("roSGNode", "DispatcharrTask")
    tagTaskForCurrentUser(task)
    task.baseUrl = context.connection.url
    task.apiKey = context.key
    task.authMode = context.targetAuthMode
    task.verifyOnly = false
    task.expectedUserId = context.target.userId.toStr()
    task.expectedUsername = context.target.username
    task.expectedAuthorizationSignature = dispatcharrAuthorizationSignature(context.authentication.verifiedUser)
    if context.target.isDefault
        task.profileId = context.connection.profileId
        task.channelProfileIds = context.connection.channelProfileIds
    end if
    task.observeField("result", "onUserProfileSwitchResult")
    task.observeField("state", "onUserProfileSwitchState")
    context.phase = "lineup"
    m.profileSwitchTask = task
    m.profileGateCover.visible = true
    m.global.profilegateclosed = false
    m.top.findNode("profileGateMessage").text = "Loading authorized profile content..."
    task.control = "RUN"
end sub
