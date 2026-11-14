sub main()
    switchRecordFixture()
    record = m.recordTask
    startUserProfileSwitchTask(m.profileSwitchContext.nonce)
    check(m.recordTask = invalid and m.recordSettlementTask <> invalid and not record.cancelRequested and m.profileSwitchTask.control = "RUN", "admitted switch parks the submitted operation before retiring its old session")
    check(record.callback = "onSubmittedRecordingSettled" and m.global.activeusersession <> m.fixtureOutgoing.sessionId, "record observation becomes operation-only while incoming authentication owns a fresh nonce")
    rollbackUserProfileSwitch("Switch cancelled")
    check(m.activeUserScope.profileId = m.fixtureOutgoing.profileId and m.activeUserScope.sessionId <> m.fixtureOutgoing.sessionId and m.recordSettlementTask <> invalid, "fresh outgoing rollback retains pending operation observation without reviving old callbacks")
    onSubmittedRecordingSettled(switchRecordEvent(record, {ok: true, accountId: "8"}))
    check(m.recordSettlementTask = invalid and m.notice = "Server recording scheduled. Open DVR to confirm its status.", "original holder receives its own terminal outcome after rollback")

    switchRecordFixture()
    record = m.recordTask
    record.state = "done"
    record.result = {ok: true, accountId: "8"}
    m.global.profilegateclosed = true
    onRecordScheduled(switchRecordEvent(record, record.result))
    check(m.recordTask <> invalid, "normal result observer refuses a covered PIN-stage result without adopting it")
    rollbackUserProfileSwitch("PIN cancelled")
    tickSubmittedRecordingSettlement()
    check(m.recordTask = invalid and m.recordSettlementTask = invalid and m.notice = "Server recording scheduled. Open DVR to confirm its status.", "pre-start rollback recovers an already-terminal submitted result hidden during the PIN gate")

    switchRecordFixture()
    record = m.recordTask
    m.fixturePrefsSaved = false
    startUserProfileSwitchTask(m.profileSwitchContext.nonce)
    check(m.fixtureTasks = 0 and m.recordSettlementTask <> invalid and not record.cancelRequested, "outgoing save failure cannot retire a recording result merely by rolling back")

    switchRecordFixture()
    record = m.recordTask
    startUserProfileSwitchTask(m.profileSwitchContext.nonce)
    store = loadUserProfileStore(m.registry, "slot-a")
    store.profiles[1].role = "child"
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(store)
    rollbackUserProfileSwitch("Profile protection changed")
    check(m.global.profilegateclosed and m.activeUserScope = invalid and m.recordSettlementTask <> invalid and not record.cancelRequested, "failed outgoing protection revalidation stays covered without cancelling submitted receipt")
    onSubmittedRecordingSettled(switchRecordEvent(record, {ok: true, accountId: "8"}))
    check(m.notice = "" and m.recordSettlementTask = invalid, "a terminal operation never reopens changed protection or displays through its closed gate")

    switchRecordFixture()
    record = m.recordTask
    startUserProfileSwitchTask(m.profileSwitchContext.nonce)
    retireUserProfileSwitch()
    m.userProfileStore.active = m.fixtureDefault.id
    m.activeUserScope = userProfileSessionScope(m.fixtureConnection, m.fixtureDefault.id, "7", "incoming", "00000000-0000-4000-8000-000000000094")
    m.global.activeusersession = m.activeUserScope.sessionId
    m.profileGateCover.visible = false
    onSubmittedRecordingSettled(switchRecordEvent(record, {ok: true, accountId: "8"}))
    check(m.notice = "" and m.recordSettlementTask = invalid, "incoming holder never receives outgoing operation metadata or notice")
    m.userProfileStore.active = m.fixtureOutgoing.profileId
    m.activeUserScope = userProfileSessionScope(m.fixtureConnection, m.fixtureOutgoing.profileId, "8", "returned", "00000000-0000-4000-8000-000000000095")
    m.global.activeusersession = m.activeUserScope.sessionId
    tickSubmittedRecordingSettlement()
    check(m.notice = "Server recording scheduled. Open DVR to confirm its status.", "only returning original holder can review its retained operation outcome")
    print "ALL TESTS PASSED"
end sub

sub switchRecordFixture()
    connection = normalizeConnectionEntry({id: "slot-a", name: "Fixture", provider: "dispatcharr", url: "https://example.test", accountId: "7", remember: true})
    store = defaultUserProfileStore("slot-a")
    a = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "Alice", user_level: 1}, 1)
    b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "Bob", user_level: 1}, 2)
    b.isDefault = false
    store.profiles = [a, b]
    store.active = b.id
    m.registry = {values: {}, exists: function(key as string) as boolean
        return m.values.doesExist(key)
    end function, read: function(key as string) as string
        if not m.values.doesExist(key) then return ""
        return m.values[key]
    end function}
    m.registry.values["connectionsV1"] = FormatJson({schema: 1, selected: connection.id, entries: [connection]})
    m.registry.values[userProfileStoreKey(connection.id)] = FormatJson(store)
    m.registry.values[userProfileKeyName(connection.id, b.id)] = "synthetic-b"
    m.connectionStore = loadConnectionStore(m.registry)
    m.userProfileStore = loadUserProfileStore(m.registry, connection.id)
    outgoing = userProfileSessionScope(connection, b.id, "8", "old-authority", "00000000-0000-4000-8000-000000000090")
    m.fixtureOutgoing = outgoing
    m.fixtureDefault = a
    m.fixtureConnection = connection
    m.selectedConnectionId = connection.id
    m.activeUserScope = outgoing
    m.accountIdentity = outgoing.preferenceIdentity
    m.serverAccountId = "8"
    m.apiKey = "synthetic-b"
    m.page = "guide"
    m.global = {activeusersession: outgoing.sessionId, profilegateclosed: false, profileswitchpending: false}
    m.profileSwitchContext = {nonce: "00000000-0000-4000-8000-000000000091", connection: connection, connectionRoot: m.registry.read("connectionsV1"), connectionRootPresent: true, store: m.userProfileStore, target: a, key: "synthetic-a", outgoing: outgoing, outgoingProtection: FormatJson(m.userProfileStore.profiles[1]), management: invalid, managementNonce: ""}
    m.profileSwitchTask = invalid
    m.userProfileRecoveryRequired = false
    m.profileGateCover = {visible: false}
    m.guide = {active: true, config: {aeriosession: outgoing.sessionId}, callFunc: sub(name as string)
    end sub}
    m.capabilityClock = {control: "start"}
    m.reminderClock = {control: "start"}
    m.top = {label: {}, findNode: function(id as string) as object
        return m.label
    end function, hasField: function(name as string) as boolean
        return false
    end function, getChildren: function(count as integer, first as integer) as object
        return []
    end function}
    m.playingChannel = invalid
    m.recordDialog = invalid
    m.recordTask = switchRecordNode("outgoing-record")
    m.recordTask.aeriosession = outgoing.sessionId
    m.recordTask.callback = "onRecordScheduled"
    m.recordAccount = outgoing.preferenceIdentity
    m.recordSettlementTask = invalid
    m.recordSettlementContext = invalid
    m.recordSettlementOutcomes = {}
    m.notice = ""
    m.fixturePrefsSaved = true
    m.fixtureTasks = 0
    m.profileSwitchTaskFactory = function() as object
        m.fixtureTasks++
        return switchRecordNode("incoming-authentication")
    end function
end sub

function switchRecordNode(id as string) as object
    return {id: id, state: "run", cancelRequested: false, isSameNode: function(other as object) as boolean
        return m.id = other.id
    end function, observeField: sub(field as string, callback as string)
        if field = "result" then m.callback = callback
    end sub, unobserveField: sub(field as string)
    end sub}
end function

function switchRecordEvent(node as object, value as object) as object
    return {node: node, value: value, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as object
        return m.value
    end function}
end function

function persistCurrentUserProfilePreferences() as boolean
    return m.fixturePrefsSaved
end function

sub resetMediaNavigation()
end sub

sub cancelCapabilityRefresh()
end sub

sub cancelProfileTask()
end sub

sub retireProfileRequestBinding()
end sub

sub showNotice(message as string)
    m.notice = message
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
