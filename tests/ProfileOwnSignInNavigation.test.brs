sub main()
    heldOwnFormFixture()
    beforeTimeout = FormatJson(m.registry.values)
    oldNonce = m.profileOwnSignInNonce
    proof = {ok: true, apiKey: "synthetic-recovered-active", verifiedBaseUrl: "https://example.test", verifiedUser: {id: 88, username: "Bob", user_level: 1}}
    check(beginProfileOwnSignInHeldCredential(proof, string(64, "a")), "bounded-wait fixture queues a current verified own key")
    oldTicket = m.profileOwnSignInHold
    m.profileOwnSignInHoldClock = {elapsed: 4000, totalMilliseconds: function() as integer
        return m.elapsed
    end function}
    tickUserProfileOwnSignInHold()
    check(m.profileOwnSignInNonce = oldNonce and m.profileOwnSignInHold <> invalid and FormatJson(m.registry.values) = beforeTimeout, "ordinary acknowledgement latency below the deadline does not cancel or mutate the own credential flow")
    m.profileOwnSignInHoldClock.elapsed = 6000
    tickUserProfileOwnSignInHold()
    check(m.profileOwnSignInContext <> invalid and m.profileOwnSignInNonce <> oldNonce and m.global.profileownsigninnonce = m.profileOwnSignInNonce and m.profileOwnSignInHold = invalid and m.activeUserScope = invalid and m.apiKey = "" and m.profileGateCover.visible, "lost broker acknowledgement retires its old proof and reopens only a fresh own credential lifecycle without app restart")
    check(FormatJson(m.registry.values) = beforeTimeout and m.profileOwnSignInDialog.buttons.count() = 4, "bounded wait leaves data/credentials unchanged and returns a usable own form")
    onProfileOwnSignInHoldResolved(ownFormEvent(oldTicket, {allowed: true}))
    check(FormatJson(m.registry.values) = beforeTimeout and m.profileOwnSignInNonce <> oldNonce, "late acknowledgement after timeout cannot commit into the reopened credential lifecycle")
    proof = {ok: true, apiKey: "synthetic-recovered-active", verifiedBaseUrl: "https://example.test", verifiedUser: {id: 88, username: "Bob", user_level: 1}}
    check(beginProfileOwnSignInHeldCredential(proof, string(64, "a")), "fresh own proof can retry after the expired broker wait")
    onProfileOwnSignInHoldResolved(ownFormEvent(m.profileOwnSignInHold, {allowed: true}))
    check(m.fixtureActiveReconnect, "a later accepted proof resumes ordinary own authentication rather than staying stranded")
    heldOwnFormFixture()
    beforeHeld = FormatJson(m.registry.values)
    proof = {ok: true, apiKey: "synthetic-recovered-active", verifiedBaseUrl: "https://example.test", verifiedUser: {id: 88, username: "Bob", user_level: 1}}
    check(beginProfileOwnSignInHeldCredential(proof, string(64, "a")) and m.profileOwnSignInHold <> invalid and FormatJson(m.registry.values) = beforeHeld, "held own key waits for broker acknowledgement before committing any credential/data")
    ticket = m.profileOwnSignInHold
    check(ticket.action = "own-verified" and ticket.holdVersion = 1 and ticket.credentialNonce = m.profileOwnSignInNonce and ticket.hash = string(64, "a") and ticket.apiKey = invalid, "broker ticket carries captured hash/version/lifecycle only, never the raw key or bearer proof")
    check(proof.apiKey = "" and proof.verifiedUser = invalid and not m.profileOwnSignInContext.pendingVerified.verifiedUser.doesExist("api_key"), "pending own proof retains only one wipeable key field, never a nested API key or unused bearer response")
    cancelUserProfileOwnSignIn()
    onProfileOwnSignInHoldResolved(ownFormEvent(ticket, {allowed: true}))
    check(proof.apiKey = "" and m.profileOwnSignInHold = invalid and m.activeUserScope = invalid and m.global.profileownsigninnonce = "" and FormatJson(m.registry.values) = beforeHeld, "Cancel wipes pending own key and refuses a late broker success without storage or scope adoption")
    heldOwnFormFixture()
    m.requestGate.snapshot.keys[string(64, "a")].version = 2
    proof = {ok: true, apiKey: "synthetic-recovered-active", verifiedBaseUrl: "https://example.test", verifiedUser: {id: 88, username: "Bob", user_level: 1}}
    check(beginProfileOwnSignInHeldCredential(proof, string(64, "a")) and m.profileOwnSignInHold = invalid and proof.apiKey = "", "a newer broker hold cannot be cleared by an older own credential lifecycle")
    heldOwnFormFixture()
    beforeHeld = FormatJson(m.registry.values)
    proof = {ok: true, apiKey: "synthetic-recovered-active", verifiedBaseUrl: "https://example.test", verifiedUser: {id: 88, username: "Bob", user_level: 1}}
    check(beginProfileOwnSignInHeldCredential(proof, string(64, "a")), "malformed acknowledgement fixture queues only current own proof")
    onProfileOwnSignInHoldResolved(ownFormEvent(m.profileOwnSignInHold, invalid))
    check(proof.apiKey = "" and m.profileOwnSignInHold = invalid and FormatJson(m.registry.values) = beforeHeld, "missing broker acknowledgement fails closed without adopting or persisting the pending key")
    heldOwnFormFixture()
    proof = {ok: true, apiKey: "synthetic-recovered-active", verifiedBaseUrl: "https://example.test", verifiedUser: {id: 88, username: "Bob", user_level: 1}}
    check(beginProfileOwnSignInHeldCredential(proof, string(64, "a")), "matching held own key queues its dedicated broker transition")
    onProfileOwnSignInHoldResolved(ownFormEvent(m.profileOwnSignInHold, {allowed: true}))
    check(m.fixtureActiveReconnect and m.profileOwnSignInContext = invalid and m.profileOwnSignInHold = invalid and m.global.profileownsigninnonce = "", "accepted same-hash own credentials commit once and reconnect through the ordinary fresh-session path")
    childOwnFormFixture(false)
    beforeChild = FormatJson(m.registry.values)
    check(beginUserProfileOwnSignIn(m.fixtureTarget, true, true), "private active keyless Child opens only its admitted own form")
    check(m.fixtureUnavailableClosed, "direct Child own-form admission detaches its underlying unavailable node before replacement")
    check(m.activeUserScope = invalid and m.profileGateCover.visible and m.global.profileownsigninpending, "Child own form has only a credential lifecycle behind the cover")
    cancelUserProfileOwnSignIn()
    check(m.fixtureChildSurfaceRestored and m.global.profilegateclosed and m.global.activeusersession = "" and FormatJson(m.registry.values) = beforeChild, "Child form Cancel returns to its unavailable surface with unchanged data and no authenticated scope")
    childOwnFormFixture(false)
    m.fixtureChildSignInAllowed = false
    check(not beginUserProfileOwnSignIn(m.fixtureTarget, true, true), "rejected/held-key-present Child policy cannot be bypassed by directly opening its own form")
    childOwnFormFixture(true)
    m.childRejectedIdentity = "https://old.test|slot-a|" + m.fixtureTarget
    check(beginUserProfileOwnSignIn(m.fixtureTarget, true, true), "private default Child may recover only its own active saved account")
    m.profileOwnSignInContext.password = "synthetic-child-password"
    onProfileOwnSignInChoice(ownFormEvent(m.profileOwnSignInDialog, 2))
    task = m.profileOwnSignInTask
    check(task.expectedUsername = "Alice" and task.expectedUserId = "7" and task.apiKey = "", "default Child credential Task binds own username and existing ID without a saved key")
    onProfileOwnSignInResult(ownFormEvent(task, {ok: true, verifiedBaseUrl: "https://example.test", apiKey: "synthetic-recovered-active", verifiedUser: {id: 7, username: "ALICE", user_level: 1}}))
    check(m.fixtureActiveReconnect and m.userProfileStore.profiles[0].role = "child" and m.registry.read("connKey_slot-a") = "synthetic-recovered-active" and m.activeUserScope = invalid, "default Child recovery stores its own slot key then begins fresh own authentication without changing role or fabricating scope")
    check(m.childRejectedIdentity = "", "successful own credentials clear only this holder's old rejected-identity marker")
    activeOwnFormFixture()
    snapshot = FormatJson(m.registry.values)
    check(showActiveUserProfileRecoveryPrompt(), "unavailable full-access holder exposes its own recovery prompt, not default setup")
    check(m.profileRecoveryDialog.title = "API key no longer valid" and m.profileRecoveryDialog.buttons.count() = 2, "own rejected-key prompt offers only Sign In with Remote and Not Now")
    onActiveUserProfileRecoveryChoice(ownFormEvent(m.profileRecoveryDialog, 0))
    check(m.profileOwnSignInContext <> invalid, "unavailable active nondefault can open its own form without a fabricated authenticated scope")
    check(m.fixtureProbeRetired, "own sign-in retires any old rejected-key probe before creating a credential lifecycle")
    check(m.activeUserScope = invalid and m.profileGateCover.visible and m.global.profileownsigninpending and m.global.activeusersession = m.profileOwnSignInNonce, "active recovery keeps content covered and grants only a fresh credential-task lifecycle")
    onProfileOwnSignInClosed(ownFormEvent(m.profileOwnSignInDialog, 0))
    check(m.activeUserScope = invalid and m.global.profilegateclosed and m.profileGateCover.visible and m.global.activeusersession = "" and FormatJson(m.registry.values) = snapshot, "active form Cancel returns to the same unavailable holder without requests or writes")
    activeOwnFormFixture()
    check(beginUserProfileOwnSignIn(m.fixtureTarget, true), "active recovery reopens with independent nonce")
    m.profileOwnSignInContext.password = "synthetic-active-password"
    onProfileOwnSignInChoice(ownFormEvent(m.profileOwnSignInDialog, 2))
    task = m.profileOwnSignInTask
    onProfileOwnSignInResult(ownFormEvent(task, {ok: true, verifiedBaseUrl: "https://example.test", apiKey: "synthetic-recovered-active", verifiedUser: {id: 8, username: "BOB", user_level: 1}}))
    check(m.fixtureActiveReconnect and m.apiKey = "synthetic-recovered-active" and m.activeUserScope = invalid and m.profileOwnSignInContext = invalid, "active recovery retires form before starting a new own-user authentication/roster/reload sequence")
    check(m.registry.read("connKey_slot-a") = "synthetic-default" and m.registry.read(userProfileKeyName("slot-a", m.fixtureTarget)) = "synthetic-recovered-active", "active recovery never overwrites the default credential")
    activeOwnFormFixture()
    m.userProfileStore.profiles[1] = setCanonicalPreference(m.userProfileStore.profiles[1], "role", "child")
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(m.userProfileStore)
    check(not showActiveUserProfileRecoveryPrompt() and not beginUserProfileOwnSignIn(m.fixtureTarget, true), "a rejected active nondefault Child never receives the adult own-sign-in prompt or form")
    activeOwnFormFixture()
    beginUserProfileOwnSignIn(m.fixtureTarget, true)
    m.profileOwnSignInContext.password = "synthetic-active-password"
    onProfileOwnSignInChoice(ownFormEvent(m.profileOwnSignInDialog, 2))
    snapshot = FormatJson(m.registry.values)
    onProfileOwnSignInResult(ownFormEvent(m.profileOwnSignInTask, {ok: true, verifiedBaseUrl: "https://stale.test", apiKey: "synthetic-stale-active", verifiedUser: {id: 8, username: "Bob", user_level: 1}}))
    check(FormatJson(m.registry.values) = snapshot and m.profileOwnSignInContext <> invalid and not m.fixtureActiveReconnect, "active recovery rejects a foreign-address verification result before writes or runtime adoption")
    cancelUserProfileOwnSignIn()
    ownFormFixture()
    m.userProfileStore.profiles[1] = setCanonicalPreference(m.userProfileStore.profiles[1], "addressHeld", true)
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(m.userProfileStore)
    snapshot = FormatJson(m.registry.values)
    check(beginUserProfileOwnSignIn(m.fixtureTarget), "inactive held full-access profile can open its own sign-in form")
    check(instr(1, m.profileOwnSignInDialog.message, "The server address for Synthetic changed. Sign in again to use this profile.") > 0, "held form displays the mandatory changed-server explanation above credentials")
    showProfileOwnSignInForm("Dispatcharr did not accept that username or password.")
    check(instr(1, m.profileOwnSignInDialog.message, "server address") > 0 and instr(1, m.profileOwnSignInDialog.message, "did not accept") > 0, "failed held attempts retain both the server-change explanation and error")
    cancelUserProfileOwnSignIn()
    check(FormatJson(m.registry.values) = snapshot and m.userProfileStore.profiles[1].addressHeld, "cancelled held recovery changes no trust or key bytes")
    ' The connection model currently refuses blank stored names; render the
    ' message helper directly rather than granting an invalid connection.
    check(userProfileOwnSignInAddressMessage("") = "The server address for this playlist changed. Sign in again to use this profile.", "blank playlist names use the specified this-playlist explanation")
    ownFormFixture()
    defaultId = m.userProfileStore.active
    m.userProfileStore.active = m.fixtureTarget
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(m.userProfileStore)
    entry = m.connectionStore.entries[0]
    m.activeUserScope = userProfileSessionScope(entry, m.fixtureTarget, 8, "generation-b", "00000000-0000-4000-8000-000000000091")
    m.global.activeusersession = m.activeUserScope.sessionId
    check(beginUserProfileOwnSignIn(defaultId), "inactive full-access default opens its known-holder form without activating it")
    m.profileOwnSignInContext.password = "synthetic-default-password"
    onProfileOwnSignInChoice(ownFormEvent(m.profileOwnSignInDialog, 2))
    check(m.profileOwnSignInTask.expectedUserId = "7" and m.profileOwnSignInTask.expectedUsername = "Alice", "default credential Task binds both the known username and existing default user ID")
    task = m.profileOwnSignInTask
    onProfileOwnSignInResult(ownFormEvent(task, {ok: true, apiKey: "recovered-default-key", verifiedUser: {id: 7, username: "ALICE", user_level: 1}}))
    check(m.registry.read("connKey_slot-a") = "recovered-default-key" and m.userProfileStore.active = m.fixtureTarget and m.activeUserScope.accountId = "8", "default form saves only its slot key and returns to unchanged outgoing B")
    ownFormFixture()
    defaultId = m.userProfileStore.active
    m.userProfileStore.active = m.fixtureTarget
    m.userProfileStore = setCanonicalPreference(m.userProfileStore, "knownDefault", {userId: 70, username: "DifferentDefault"})
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(m.userProfileStore)
    check(not beginUserProfileOwnSignIn(defaultId), "default form cannot open for a row that conflicts with the frozen known-default identity")
    ownFormFixture()
    check(beginUserProfileOwnSignIn(m.fixtureTarget), "inactive own-profile recovery opens its scoped form")
    check(m.profileOwnSignInDialog.title = "Sign in to Dispatcharr" and instr(1, m.profileOwnSignInDialog.buttons[0], "Bob") > 0, "form identifies only its own prefilled username")
    onProfileOwnSignInChoice(ownFormEvent(m.profileOwnSignInDialog, 0))
    check(m.profileOwnSignInDialog.keyboardDomain = "email", "own username uses the native email-domain keyboard")
    onProfileOwnSignInEdited(ownFormEvent(m.profileOwnSignInDialog, 1))
    onProfileOwnSignInChoice(ownFormEvent(m.profileOwnSignInDialog, 1))
    check(m.profileOwnSignInDialog.keyboardDomain = "password" and m.profileOwnSignInDialog.textEditBox.secureMode, "password uses the secured standard keyboard contract")
    m.profileOwnSignInDialog.text = "synthetic-password"
    onProfileOwnSignInEdited(ownFormEvent(m.profileOwnSignInDialog, 0))
    check(instr(1, FormatJson(m.profileOwnSignInDialog.buttons), "synthetic-password") = 0, "form masks transient password rather than rendering it in buttons")
    onProfileOwnSignInChoice(ownFormEvent(m.profileOwnSignInDialog, 2))
    task = m.profileOwnSignInTask
    check(task.ownProfileSignIn and task.verifyOnly and task.expectedUsername = "Bob" and task.expectedUserId = "" and task.apiKey = "", "own form creates a username-bound credential Task, never borrows a slot key or old user ID")
    check(task.password = "synthetic-password" and m.profileOwnSignInContext.password = "", "password moves only into its owned Task and leaves the form context")
    onProfileOwnSignInResult(ownFormEvent(task, {ok: false, apiAccessRequired: true}))
    oldTask = task
    check(m.profileOwnSignInTask = invalid and m.profileOwnSignInContext.password = "" and instr(1, m.profileOwnSignInDialog.message, "turn on API access") > 0, "failed credential attempt is scrubbed and returns the same scoped form without registry writes")
    onProfileOwnSignInChoice(ownFormEvent(m.profileOwnSignInDialog, 1))
    m.profileOwnSignInDialog.text = "synthetic-password"
    onProfileOwnSignInEdited(ownFormEvent(m.profileOwnSignInDialog, 0))
    onProfileOwnSignInChoice(ownFormEvent(m.profileOwnSignInDialog, 2))
    task = m.profileOwnSignInTask
    onProfileOwnSignInResult(ownFormEvent(oldTask, {ok: true, apiKey: "stale-verified-key"}))
    check(m.profileOwnSignInTask.id = task.id and m.registry.flushes = 0, "replaced credential Task cannot submit a late result into the new attempt")
    onProfileOwnSignInClosed(ownFormEvent(m.profileOwnSignInDialog, 0))
    check(task.cancelRequested and task.password = "" and m.profileOwnSignInContext = invalid and m.profileOwnSignInDialog = invalid, "Back cancels the owned Task and erases transient credentials")
    check(m.registry.flushes = 0 and m.guide.active and m.top.exitRequested <> true, "form cancellation returns to the same profile without writes or app exit")
    ownFormFixture()
    beginUserProfileOwnSignIn(m.fixtureTarget)
    oldDialog = m.profileOwnSignInDialog
    m.activeUserScope.sessionId = "00000000-0000-4000-8000-000000000099"
    onProfileOwnSignInChoice(ownFormEvent(oldDialog, 2))
    check(m.profileOwnSignInContext = invalid and m.profileOwnSignInTask = invalid and m.registry.flushes = 0, "old A callbacks cannot submit credentials after a new A lifecycle")
    ownFormFixture()
    check(not beginUserProfileOwnSignIn(m.userProfileStore.active), "active-profile recovery stays fenced until runtime adoption is integrated")
    ownFormFixture()
    protected = m.userProfileStore
    protected.profiles[1].pinType = "numbers"
    protected.profiles[1].pinHash = string(64, "a")
    protected.profiles[1].pinSalt = string(32, "b")
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(protected)
    check(beginUserProfileOwnSignIn(m.fixtureTarget) and m.pinRequested and m.profileOwnSignInDialog = invalid and m.profileOwnSignInTask = invalid, "target PIN is required before showing credentials or starting sign-in")
    m.profileUnlockGrant = {slot: "slot-a", id: m.fixtureTarget, pinType: "numbers", pinHash: string(64, "a"), pinSalt: string(32, "b")}
    onUserProfileOwnSignInPin(m.profileOwnSignInNonce)
    check(m.profileOwnSignInDialog <> invalid and m.profileUnlockGrant = invalid and m.profileOwnSignInContext.pin.id = m.fixtureTarget, "target PIN ticket authorizes only this recovery form, not profile activation")
    cancelUserProfileOwnSignIn()
    ownFormFixture()
    beginUserProfileOwnSignIn(m.fixtureTarget)
    changedStore = ParseJson(m.registry.read(userProfileStoreKey("slot-a")))
    changedStore.profiles[0].role = "child"
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(changedStore)
    onProfileOwnSignInChoice(ownFormEvent(m.profileOwnSignInDialog, 0))
    check(m.profileGateCover.visible and m.global.profilegateclosed and m.activeUserScope = invalid and not m.guide.active, "changed outgoing authority cannot be restored as an uncovered Standard caller")
    ownFormFixture()
    beginUserProfileOwnSignIn(m.fixtureTarget)
    changedConnections = ParseJson(m.registry.read("connectionsV1"))
    changedConnections.entries[0].url = "https://changed.test"
    m.registry.values["connectionsV1"] = FormatJson(changedConnections)
    onProfileOwnSignInChoice(ownFormEvent(m.profileOwnSignInDialog, 0))
    check(m.profileGateCover.visible and m.global.profilegateclosed and m.activeUserScope = invalid and not m.guide.active, "changed persisted address cannot uncover the stale outgoing authenticated runtime")
    ownFormFixture()
    beginUserProfileOwnSignIn(m.fixtureTarget)
    m.profileOwnSignInContext.password = "synthetic-password"
    onProfileOwnSignInChoice(ownFormEvent(m.profileOwnSignInDialog, 2))
    m.registry.failures = 2
    onProfileOwnSignInResult(ownFormEvent(m.profileOwnSignInTask, {ok: true, apiKey: "synthetic-new-key", verifiedUser: {id: 88, username: "Bob", user_level: 1}}))
    check(m.userProfileRecoveryRequired and m.profileOwnSignInContext = invalid and m.activeUserScope = invalid and m.profileGateCover.visible and m.global.profilegateclosed, "failed registry rollback retires the form and stays covered with no active runtime authority")
    print "ALL TESTS PASSED"
end sub

sub heldOwnFormFixture()
    activeOwnFormFixture()
    state = requestGateDefault()
    state.keys[string(64, "a")] = {version: 1}
    m.requestGate = {snapshot: state}
    m.profileOwnSignInHoldFactory = m.profileOwnSignInTaskFactory
    check(beginUserProfileOwnSignIn(m.fixtureTarget, true), "held-key proof fixture starts an explicit own credential lifecycle")
end sub

sub activeOwnFormFixture()
    ownFormFixture()
    m.userProfileStore.active = m.fixtureTarget
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(m.userProfileStore)
    m.registry.values["connKey_slot-a"] = "synthetic-default"
    m.apiKey = ""
    m.activeUserScope = invalid
    m.global.activeusersession = ""
    m.global.profilegateclosed = true
    m.profileGateCover.visible = true
    m.page = "setup"
    m.guide.active = false
    m.fixtureActiveReconnect = false
end sub

sub childOwnFormFixture(defaultChild as boolean)
    activeOwnFormFixture()
    m.page = "profile-unavailable"
    m.profileChildAccessReady = true
    index = 1
    if defaultChild then index = 0
    m.fixtureTarget = m.userProfileStore.profiles[index].id
    m.userProfileStore.active = m.fixtureTarget
    m.userProfileStore.profiles[index] = setCanonicalPreference(m.userProfileStore.profiles[index], "role", "child")
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(m.userProfileStore)
    m.fixtureChildSignInAllowed = true
    m.fixtureChildSurfaceRestored = false
end sub

function unavailableChildAccessContext() as dynamic
    return {target: {id: m.fixtureTarget}, plan: {signIn: m.fixtureChildSignInAllowed}}
end function

function showUnavailableChildProfile() as boolean
    m.fixtureChildSurfaceRestored = true
    return true
end function

sub closeUnavailableChildDialog()
    m.fixtureUnavailableClosed = true
end sub

sub closeChildRejectedKeyDialog()
end sub

sub resetConnectionRuntime()
    retireUserProfileOwnSignIn()
    m.activeUserScope = invalid
    m.global.activeusersession = ""
    m.apiKey = ""
end sub

sub retireProfileRequestBinding()
    m.fixtureProbeRetired = true
end sub

sub applySelectedConnection()
end sub

sub connectServer(skipRfi as boolean)
    m.fixtureActiveReconnect = skipRfi and m.apiKey = "synthetic-recovered-active" and m.profileRefreshReload = true and m.global.activeusersession = ""
end sub

function ownFormEvent(node as object, index as dynamic) as object
    return {node: node, index: index, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as dynamic
        return m.index
    end function}
end function

sub ownFormFixture()
    m.fixtureUnavailableClosed = false
    m.requestGate = invalid
    m.profileOwnSignInHold = invalid
    entry = normalizeConnectionEntry({id: "slot-a", name: "Synthetic", provider: "dispatcharr", url: "https://example.test", accountId: "7", remember: true})
    a = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "Alice", user_level: 1}, 1)
    b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "Bob", user_level: 1}, 1)
    b.isDefault = false
    store = defaultUserProfileStore("slot-a")
    store.profiles = [a, b]
    store.active = a.id
    m.userProfileStore = store
    m.fixtureTarget = b.id
    m.connectionStore = {schema: 1, selected: "slot-a", entries: [entry]}
    m.selectedConnectionId = "slot-a"
    m.baseUrl = entry.url
    m.activeUserScope = userProfileSessionScope(entry, a.id, 7, "generation", "00000000-0000-4000-8000-000000000090")
    m.global = {activeusersession: m.activeUserScope.sessionId, profilegateclosed: false}
    m.scopedPreferencesRequired = true
    m.userProfileRecoveryRequired = false
    m.page = "guide"
    m.guide = {active: true, setFocus: sub(value as boolean)
    end sub}
    m.top = {exitRequested: false}
    m.profileGateCover = {visible: false}
    m.profileOwnSignInContext = invalid
    m.profileOwnSignInDialog = invalid
    m.profileOwnSignInTask = invalid
    m.profileSessionKeys = {}
    m.fixtureNotice = ""
    m.profileChildAccessReady = false
    m.fixtureProbeRetired = false
    m.pinRequested = false
    m.factorySequence = 0
    values = {}
    values["connectionsV1"] = FormatJson(m.connectionStore)
    values[userProfileStoreKey("slot-a")] = FormatJson(store)
    m.registry = {values: values, flushes: 0, failures: 0, exists: function(key as string) as boolean
        return m.values.doesExist(key)
    end function, read: function(key as string) as string
        if not m.values.doesExist(key) then return ""
        return m.values[key]
    end function, write: function(key as string, value as string) as boolean
        m.values[key] = value
        return true
    end function, delete: function(key as string) as boolean
        m.values.delete(key)
        return true
    end function, flush: function() as boolean
        m.flushes++
        if m.failures > 0 then m.failures-- : return false
        return true
    end function}
    m.profileOwnSignInDialogFactory = function(kind as string) as object
        m.factorySequence++
        return {id: m.factorySequence, kind: kind, text: "", textEditBox: {hasField: function(field as string) as boolean
            return true
        end function}, isSameNode: function(other as object) as boolean
            return other.id = m.id
        end function, observeField: sub(field as string, callback as string)
        end sub, unobserveField: sub(field as string)
        end sub, setFocus: sub(value as boolean)
        end sub}
    end function
    m.profileOwnSignInTaskFactory = function() as object
        m.factorySequence++
        return {id: "task-" + m.factorySequence.toStr(), aeriosession: "", cancelRequested: false, isSameNode: function(other as object) as boolean
            return other.id = m.id
        end function, observeField: sub(field as string, callback as string)
        end sub, unobserveField: sub(field as string)
        end sub}
    end function
end sub

function beginProfilePinGate(profile as object, continuation as string, nonce as string) as boolean
    m.pinRequested = continuation = "own-signin" and nonce = m.profileOwnSignInNonce
    return true
end function

sub showNotice(message as string)
    m.fixtureNotice = message
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
