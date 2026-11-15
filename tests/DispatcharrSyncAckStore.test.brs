sub main()
    for each fault in ["", "write", "flush", "rollback"]
        syncAckFixture()
        m.registry.fault = fault
        before = FormatJson(m.registry.values)
        result = ensureDispatcharrSyncDeviceIdentity(m.registry, "00000000-0000-4000-8000-000000000080")
        if fault = ""
            again = ensureDispatcharrSyncDeviceIdentity(m.registry, "00000000-0000-4000-8000-000000000081")
            check(result.ok and again.id = result.id and m.registry.flushes = 1, "sync install identity persists once and is reused across sessions without regeneration")
        else
            check(not result.ok and result.recoveryRequired = (fault = "rollback") and FormatJson(m.registry.values) = before, "failed identity creation restores exact missing record and leaves dirty metadata intact")
        end if
    end for
    syncAckFixture()
    check(not ensureDispatcharrSyncDeviceIdentity(m.registry, "not-a-uuid").ok and m.registry.flushes = 0, "invalid install identity cannot become a wire device ID")
    m.registry.values["dispatcharrSyncDeviceV1"] = "opaque-existing-value"
    before = FormatJson(m.registry.values)
    check(not ensureDispatcharrSyncDeviceIdentity(m.registry, "00000000-0000-4000-8000-000000000080").ok and FormatJson(m.registry.values) = before, "opaque present identity fails closed rather than being overwritten as absent")
    for each fault in ["", "write", "flush", "rollback"]
        syncAckFixture()
        m.registry.fault = fault
        before = FormatJson(m.registry.values)
        result = commitDispatcharrSyncRosterAck(m.registry, m.connection, m.store, m.receipt, m.scope, m.key, {})
        if fault = ""
            check(result.ok and not result.store.pendingRoster and m.registry.flushes = 1, "successful own 200 clears pending and stores highwater in one atomic transaction")
            ack = loadDispatcharrSyncRosterAck(m.registry, m.connection)
            check(ack.ok and ack.stamp = 100 and instr(1, m.registry.read(userProfileSyncAckKey("slot-a")), "synthetic-own") = 0 and m.registry.read("connKey_slot-a") = "synthetic-own", "ack records metadata only, never credentials, and retains the own key")
        else
            check(not result.ok and result.recoveryRequired = (fault = "rollback") and FormatJson(m.registry.values) = before, "ack transaction faults restore exact dirty root and previous ack")
        end if
    end for
    for each change in ["scope", "generation", "root", "connection", "key", "held", "status", "not-submitted", "digest", "future-ack", "malformed-ack"]
        syncAckFixture()
        if change = "scope" then m.scope = setCanonicalPreference(m.scope, "sessionId", "00000000-0000-4000-8000-000000000091")
        if change = "generation" then m.scope = setCanonicalPreference(m.scope, "authorizationGeneration", "successor-generation")
        if change = "root" then m.registry.values[userProfileStoreKey("slot-a")] += " "
        if change = "connection" then m.registry.values["connectionsV1"] += " "
        if change = "key"
            m.registry.values["connKey_slot-a"] = "successor-key"
            m.key = "successor-key"
        end if
        if change = "held" then m.held = true
        if change = "status" then m.receipt.ok = false
        if change = "not-submitted" then m.receipt.submitted = false
        if change = "digest" then m.receipt.credentialHash = string(64, "b")
        if change = "future-ack" then m.registry.values[userProfileSyncAckKey("slot-a")] = "{""schema"":2}"
        if change = "malformed-ack" then m.registry.values[userProfileSyncAckKey("slot-a")] = ""
        before = FormatJson(m.registry.values)
        result = commitDispatcharrSyncRosterAck(m.registry, m.connection, m.store, m.receipt, m.scope, m.key, {})
        check(not result.ok and m.registry.flushes = 0 and FormatJson(m.registry.values) = before, "late acknowledgement cannot clear pending after changed " + change)
    end for
    syncAckFixture()
    m.registry.values[userProfileSyncAckKey("slot-a")] = "{""schema"":1,""playlistId"":""slot-a"",""baseUrl"":""https://example.test"",""maximumSentStamp"":200}"
    result = commitDispatcharrSyncRosterAck(m.registry, m.connection, m.store, m.receipt, m.scope, m.key, {})
    check(result.ok and loadDispatcharrSyncRosterAck(m.registry, m.connection).stamp = 200, "late lower highwater cannot regress an existing successful acknowledgement")
    syncFlushFixture()
    check(beginOutgoingUserProfileSync(m.profileSwitchContext), "private flush starts under the actual outgoing adopted session")
    check(m.profileSyncWriteTask.apiKey = "synthetic-own" and m.profileSyncWriteTask.aeriosession = m.scope.sessionId and m.global.activeusersession = m.scope.sessionId and m.profileSwitchContext.key = "target-own-key", "outgoing flush never uses target credentials or retires its actual source nonce early")
    sourceTask = m.profileSyncWriteTask
    onOutgoingUserProfileSyncResult(syncFlushEvent(sourceTask, m.receipt))
    check(m.flushResumes = 1 and m.profileSyncWriteTask = invalid and sourceTask.apiKey = "" and not m.profileSwitchContext.store.pendingRoster and not loadUserProfileStore(m.registry, "slot-a").pendingRoster, "only own matching acknowledgement publishes the clean switch snapshot and resumes incoming staging")
    syncFlushFixture()
    check(beginOutgoingUserProfileSync(m.profileSwitchContext), "failed flush fixture starts")
    onOutgoingUserProfileSyncResult(syncFlushEvent(m.profileSyncWriteTask, {ok: false, state: "pending", submitted: true}))
    check(m.flushResumes = 0 and m.flushRollbacks = 1 and loadUserProfileStore(m.registry, "slot-a").pendingRoster, "failed outgoing write retains dirty data and cannot start incoming authentication")
    syncFlushFixture()
    m.playingChannel = {uuid: "owned-source"}
    check(beginOutgoingUserProfileSync(m.profileSwitchContext), "authority refusal fixture starts")
    onOutgoingUserProfileSyncResult(syncFlushEvent(m.profileSyncWriteTask, {ok: false, state: "authority", submitted: false}))
    check(m.flushResumes = 0 and m.flushRollbacks = 1 and m.userProfileRecoveryRequired and m.apiKey = "" and loadUserProfileStore(m.registry, "slot-a").pendingRoster, "fresh outgoing authority mismatch cannot restore content under the previous authorization")
    check(m.syncSourceStopped and m.syncSourceFenced, "changed outgoing authority stops source playback and fences native renderers rather than only covering old permissions")
    syncFlushFixture()
    check(beginOutgoingUserProfileSync(m.profileSwitchContext), "stale flush fixture starts")
    sourceTask = m.profileSyncWriteTask
    m.global.activeusersession = "00000000-0000-4000-8000-000000000092"
    m.apiKey = "successor-key"
    onOutgoingUserProfileSyncResult(syncFlushEvent(sourceTask, m.receipt))
    check(m.flushResumes = 0 and m.flushRollbacks = 0 and m.apiKey = "successor-key" and loadUserProfileStore(m.registry, "slot-a").pendingRoster, "stale flush callback cannot clear dirty state, wipe successor key or resume an incoming request")
    closeOutgoingUserProfileSync()
    print "ALL TESTS PASSED"
end sub

sub syncFlushFixture()
    syncAckFixture()
    b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "Bob", user_level: 1}, 1)
    b = setCanonicalPreference(b, "isDefault", false)
    m.store.profiles.push(b)
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(m.store)
    m.registry.values["dispatcharrSyncDeviceV1"] = "00000000-0000-4000-8000-000000000080"
    m.receipt.storeRoot = m.registry.values[userProfileStoreKey("slot-a")]
    m.profileSyncWriterReady = true
    m.userProfileRecoveryRequired = false
    m.playingChannel = invalid
    m.syncSourceStopped = false
    m.syncSourceFenced = false
    m.profileSyncAppVersion = "1"
    m.profileSyncNonceFactory = function() as string
        return "00000000-0000-4000-8000-000000000093"
    end function
    m.profileSyncWriteTask = invalid
    m.profileSyncContext = invalid
    m.activeUserScope = m.scope
    m.apiKey = m.key
    m.selectedConnectionId = "slot-a"
    m.profileAuthorizationSignature = dispatcharrAuthorizationSignature({id: 7, username: "Alice", user_level: 1})
    m.global = {activeusersession: m.scope.sessionId, profilegateclosed: false}
    m.profileSwitchContext = {nonce: "00000000-0000-4000-8000-000000000091", outgoing: m.scope, connection: m.connection, store: m.store, target: b, key: "target-own-key"}
    m.profileGateCover = {visible: false}
    m.guide = {active: true}
    m.top = {message: {}
        findNode: function(id as string) as object
            return m.message
        end function
    }
    m.flushResumes = 0
    m.flushRollbacks = 0
    m.profileSyncWriteTaskFactory = function() as object
        return {apiKey: "", token: "outgoing-task", result: invalid
            observeField: sub(field as string, callback as string)
            end sub
            unobserveField: sub(field as string)
            end sub
            isSameNode: function(other as object) as boolean
                return m.token = other.token
            end function
        }
    end function
end sub

function syncFlushEvent(node as object, data as object) as object
    return {node: node, data: data
        getRoSGNode: function() as object
            return m.node
        end function
        getData: function() as object
            return m.data
        end function
    }
end function

function userProfileSwitchActorCurrent(context as object) as boolean
    return userProfileSameSession(context.outgoing, m.activeUserScope)
end function

sub startUserProfileSwitchTask(nonce as string)
    m.flushResumes++
end sub

sub rollbackUserProfileSwitch(message as string)
    m.flushRollbacks++
end sub

sub stopPlayback()
    m.syncSourceStopped = true
    m.playingChannel = invalid
end sub

sub requestGateFenceRenderers(root as object)
    m.syncSourceFenced = true
end sub

sub syncAckFixture()
    connections = connectionStoreAdd(defaultConnectionStore(), "slot-a", "Synthetic")
    connections = connectionStoreUpdate(connections, "slot-a", {url: "https://example.test", accountId: "7", remember: true})
    m.connection = connectionStoreEntry(connections, "slot-a")
    profile = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "Alice", user_level: 1}, 1)
    m.store = defaultUserProfileStore("slot-a")
    m.store.profiles = [profile]
    m.store.active = profile.id
    m.store.pendingRoster = true
    m.scope = userProfileSessionScope(m.connection, profile.id, 7, "own-generation", "00000000-0000-4000-8000-000000000090")
    m.key = "synthetic-own"
    m.held = false
    values = {connectionsV1: FormatJson(connections)}
    values["connKey_slot-a"] = m.key
    values[userProfileStoreKey("slot-a")] = FormatJson(m.store)
    m.receipt = {ok: true, state: "written", submitted: true, scope: m.scope, storeRoot: values[userProfileStoreKey("slot-a")], connectionRoot: values.connectionsV1, credentialHash: string(64, "a"), maximumSentStamp: 100}
    m.registry = {values: values, fault: "", failed: false, flushes: 0
        exists: function(key as string) as boolean
            return m.values.doesExist(key)
        end function
        read: function(key as string) as string
            if not m.values.doesExist(key) then return ""
            return m.values[key]
        end function
        write: function(key as string, value as string) as boolean
            if m.fault = "write" and not m.failed then m.failed = true : return false
            m.values[key] = value
            return true
        end function
        delete: function(key as string) as boolean
            m.values.delete(key)
            return true
        end function
        flush: function() as boolean
            m.flushes++
            if m.fault = "rollback" then return false
            if m.fault = "flush" and not m.failed then m.failed = true : return false
            return true
        end function
    }
end sub

function requestGateCredentialHash(key as string) as string
    if key = "synthetic-own" then return string(64, "a")
    return string(64, "b")
end function

function requestGateAccessAllowed(url as string, key as string) as boolean
    return not m.held
end function

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
