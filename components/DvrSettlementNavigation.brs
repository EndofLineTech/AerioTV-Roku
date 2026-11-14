' A submitted recording outcome is an operation, not an authenticated session.
' Retain its exact Task across authority retirement without adopting old data.
sub preserveSubmittedRecording()
    if m.recordTask = invalid or m.recordSettlementTask <> invalid then return
    if type(m.activeUserScope) <> "roAssociativeArray" then return
    m.recordSettlementContext = {identity: recordingSettlementIdentity(m.activeUserScope), account: m.serverAccountId}
    m.recordSettlementTask = m.recordTask
    m.recordTask.unobserveField("result")
    m.recordTask = invalid
    m.recordSettlementTask.observeField("result", "onSubmittedRecordingSettled")
    m.recordSettlementClock = CreateObject("roTimespan")
    m.recordSettlementClock.mark()
end sub

function recordingSettlementIdentity(scope as dynamic) as string
    if type(scope) <> "roAssociativeArray" then return ""
    if textValue(scope.playlistId) = "" or textValue(scope.profileId) = "" or textValue(scope.accountId) = "" or textValue(scope.preferenceIdentity) = "" then return ""
    if type(m.userProfileStore) <> "roAssociativeArray" then return ""
    if m.userProfileStore.playlistId <> scope.playlistId or m.userProfileStore.active <> scope.profileId or m.userProfileStore.readOnly = true then return ""
    if type(m.userProfileStore.profiles) <> "roArray" then return ""
    username = ""
    for each profile in m.userProfileStore.profiles
        if profile.id = scope.profileId and textValue(profile.userId) = scope.accountId then username = lcase(textValue(profile.username))
    end for
    if username = "" then return ""
    return preferenceScope(FormatJson([scope.playlistId, scope.profileId, scope.accountId, username, scope.preferenceIdentity]))
end function

sub onSubmittedRecordingSettled(event as object)
    if m.recordSettlementTask = invalid then return
    if not m.recordSettlementTask.isSameNode(event.getRoSGNode()) then return
    finishSubmittedRecordingSettlement(event.getData())
end sub

sub finishSubmittedRecordingSettlement(result as dynamic)
    if m.recordSettlementTask = invalid or m.recordSettlementContext = invalid then return
    context = m.recordSettlementContext
    m.recordSettlementTask.unobserveField("result")
    m.recordSettlementTask = invalid
    m.recordSettlementContext = invalid
    m.recordSettlementClock = invalid
    message = "Recording was not confirmed. Check DVR before retrying."
    if type(result) = "roAssociativeArray"
        if textValue(result.accountId) = context.account
            if result.ok = true then message = "Server recording scheduled. Open DVR to confirm its status."
            if result.category = "duplicate" then message = "This program is already scheduled. Open DVR to review."
        end if
    end if
    if type(m.recordSettlementOutcomes) <> "roAssociativeArray" then m.recordSettlementOutcomes = {}
    if context.identity <> "" then m.recordSettlementOutcomes[context.identity] = message
    showOwnRecordingSettlement()
end sub

sub showOwnRecordingSettlement()
    if userProfileUiClosed() or (m.page <> "guide" and m.page <> "player") then return
    identity = recordingSettlementIdentity(m.activeUserScope)
    if identity = "" or type(m.recordSettlementOutcomes) <> "roAssociativeArray" then return
    if not m.recordSettlementOutcomes.doesExist(identity) then return
    message = m.recordSettlementOutcomes[identity]
    m.recordSettlementOutcomes.delete(identity)
    showNotice(message)
end sub

sub tickSubmittedRecordingSettlement()
    if m.recordSettlementTask <> invalid
        if m.recordSettlementTask.state = "done" or m.recordSettlementTask.state = "stop"
            finishSubmittedRecordingSettlement(m.recordSettlementTask.result)
        else if m.recordSettlementClock <> invalid
            if m.recordSettlementClock.totalMilliseconds() >= 35000
                cancelNetworkTask(m.recordSettlementTask)
                finishSubmittedRecordingSettlement(invalid)
            end if
        end if
    end if
    showOwnRecordingSettlement()
end sub
