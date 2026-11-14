sub main()
    settlementFixture()
    task = m.recordTask
    preserveSubmittedRecording()
    check(m.recordTask = invalid and m.recordSettlementTask <> invalid and not task.cancelRequested, "authority retirement detaches normal observer without cancelling submitted recording")
    m.global.activeusersession = "new-session"
    onSubmittedRecordingSettled(settlementEvent(task, {ok: true, accountId: "8"}))
    check(m.recordSettlementTask = invalid and m.fixtureMessage = "Server recording scheduled. Open DVR to confirm its status.", "exact submitted operation settles after session rotation without borrowing authentication")
    settlementFixture()
    task = m.recordTask
    preserveSubmittedRecording()
    m.activeUserScope.profileId = "another-holder"
    onSubmittedRecordingSettled(settlementEvent(task, {ok: true, accountId: "8"}))
    check(m.fixtureMessage = "" and m.recordSettlementTask = invalid, "another holder never sees an outgoing recording outcome")
    m.activeUserScope.profileId = "holder-b"
    tickSubmittedRecordingSettlement()
    check(m.fixtureMessage <> "", "returning original holder can review its settled operation notice")
    settlementFixture()
    task = m.recordTask
    preserveSubmittedRecording()
    m.activeUserScope.preferenceIdentity = "different-current-address|8"
    onSubmittedRecordingSettled(settlementEvent(task, {ok: true, accountId: "8"}))
    check(m.fixtureMessage = "", "same numeric account at a different address never inherits an old operation notice")
    settlementFixture()
    task = m.recordTask
    preserveSubmittedRecording()
    m.userProfileStore.profiles[0].username = "ReplacedIdentity"
    onSubmittedRecordingSettled(settlementEvent(task, {ok: true, accountId: "8"}))
    check(m.fixtureMessage = "", "same local UUID and numeric ID with a different username cannot inherit an old operation notice")
    settlementFixture()
    task = m.recordTask
    preserveSubmittedRecording()
    m.global.profilegateclosed = true
    onSubmittedRecordingSettled(settlementEvent(task, {ok: true, accountId: "8"}))
    check(m.fixtureMessage = "", "settled results never disclose behind a closed content/PIN gate")
    m.global.profilegateclosed = false
    tickSubmittedRecordingSettlement()
    check(m.fixtureMessage <> "", "only fresh own admission allows its retained generic operation notice")
    settlementFixture()
    task = m.recordTask
    preserveSubmittedRecording()
    onSubmittedRecordingSettled(settlementEvent({id: "other-task"}, {ok: true, accountId: "8"}))
    check(m.recordSettlementTask <> invalid and m.fixtureMessage = "", "stale or foreign operation node cannot settle current recording")
    onSubmittedRecordingSettled(settlementEvent(task, {ok: true, accountId: "7"}))
    check(m.fixtureMessage = "Recording was not confirmed. Check DVR before retrying.", "mismatched operation account never claims server success")
    settlementFixture()
    preserveSubmittedRecording()
    m.recordSettlementClock = {totalMilliseconds: function() as integer
        return 36000
    end function}
    tickSubmittedRecordingSettlement()
    check(m.recordSettlementTask = invalid and m.fixtureMessage = "Recording was not confirmed. Check DVR before retrying.", "lost result is bounded and described as uncertain, never server cancellation")
    print "ALL TESTS PASSED"
end sub

sub settlementFixture()
    m.recordTask = {id: "record-once", cancelRequested: false, state: "run", isSameNode: function(other as object) as boolean
        return m.id = other.id
    end function, observeField: sub(field as string, callback as string)
    end sub, unobserveField: sub(field as string)
    end sub}
    m.recordAccount = "own-settings"
    m.serverAccountId = "8"
    m.activeUserScope = {playlistId: "slot-a", profileId: "holder-b", accountId: "8", preferenceIdentity: "own-settings"}
    m.userProfileStore = {playlistId: "slot-a", active: "holder-b", profiles: [{id: "holder-b", userId: 8, username: "Bob"}]}
    m.global = {activeusersession: "old-session", profilegateclosed: false}
    m.page = "guide"
    m.recordSettlementTask = invalid
    m.recordSettlementContext = invalid
    m.recordSettlementOutcomes = {}
    m.fixtureMessage = ""
end sub

sub showNotice(message as string)
    m.fixtureMessage = message
end sub

function settlementEvent(node as object, value as object) as object
    return {node: node, value: value, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as object
        return m.value
    end function}
end function

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
