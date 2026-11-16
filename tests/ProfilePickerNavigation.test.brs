sub main()
    pickerNavigationFixture()
    m.profilePickerReady = false
    check(not beginUserProfileLaunchPicker(false) and m.pickerCreates = 0 and m.apiKey = "default-key", "shipping-off picker does not alter bootstrap credentials")
    pickerNavigationFixture()
    check(not beginUserProfileLaunchPicker(true) and m.pickerCreates = 0, "deep link never opens launch selection")
    pickerNavigationFixture()
    m.activeUserScope = {profileId: "already-adopted"}
    check(not beginUserProfileLaunchPicker(false) and m.pickerCreates = 0, "launch controller is not an authenticated switcher shortcut")
    pickerNavigationFixture()
    store = loadUserProfileStore(m.registry, "slot-a")
    store.profiles[0] = setCanonicalPreference(store.profiles[0], "role", "child")
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(store)
    check(not beginUserProfileLaunchPicker(false) and m.pickerCreates = 0, "Child cannot disclose names through direct launch handler")
    pickerNavigationFixture()
    check(beginUserProfileLaunchPicker(false), "explicit private launch picker opens for restored adult Ask")
    check(m.apiKey = "" and m.activeUserScope = invalid and m.global.profilegateclosed and m.page = "profile-picker", "picker opens behind no-actor/empty-key cover")
    check(m.pickerCreates = 1 and m.profilePicker.model.focus = 0 and m.profilePicker.model.tiles.count() = 3 and m.taskCreates = 0, "ordered UI focuses restored holder before any authentication or heavy work")
    node = m.profilePicker
    onUserProfilePickerIntent(pickerNavigationEvent({tag: "stale"}, {action: "back", index: 0}))
    check(m.top.exitRequested <> true and m.profilePicker <> invalid, "stale node cannot cancel the current picker lifecycle")
    m.profilePicker.busy = true
    onUserProfilePickerIntent(pickerNavigationEvent(node, {action: "back", index: 0}))
    check(m.top.exitRequested and m.global.profilegateclosed and m.profilePicker = invalid and m.activeUserScope = invalid and m.apiKey = "", "launch Back exits even while busy without revealing setup or authenticating")
    check(m.registry.flushes = 0 and m.registry.read("connKey_slot-a") = "default-key", "picker cancellation never changes saved active, credentials or settings")
    pickerNavigationFixture()
    check(beginUserProfileLaunchPicker(false), "fresh picker can start a distinct attempt")
    onUserProfilePickerIntent(pickerNavigationEvent(m.profilePicker, {action: "select", index: 0}))
    check(m.taskCreates = 1 and m.profileStartupTask.verifyOnly and m.profileStartupTask.apiKey = "default-key" and m.profileStartupTask.expectedUserId = "7", "selected current holder starts only own verify-only authentication")
    check(m.activeUserScope = invalid and m.apiKey = "" and m.global.profileswitchpending and m.profilePicker.busy, "incoming request nonce is not an authenticated outgoing scope or active runtime key")
    check(m.registry.flushes = 0 and loadUserProfileStore(m.registry, "slot-a").active = m.a.id, "selection is not durably adopted before target auth/protection/lineup")
    task = m.profileStartupTask
    m.global.requestGateRequired = true
    m.global.requestGate = {ready: false}
    context = m.profileStartupSelectionContext
    check(userProfileStartupSelectionStorageCurrent(m.registry, context, currentUserSessionId(), invalid, "", context.memoryKeys, true) and not userProfileStartupSelectionCurrent(m.registry, context, currentUserSessionId(), invalid, "", context.memoryKeys, true), "failure ownership does not reopen broker-blocked transport")
    check(not userProfileStartupSelectionStorageCurrent(m.registry, context, "00000000-0000-4000-8000-000000000099", invalid, "", context.memoryKeys, true), "failure-only boundary still rejects a stale actual callback nonce")
    onStartupProfileResult(pickerNavigationEvent(task, {ok: false, relogin: true}))
    check(m.profilePicker.message = "The API key for alice was rejected." and m.profileStartupTask = invalid and m.profileStartupSelectionContext = invalid, "an owned rejection result must be consumed even after shared admission closes")
    check(m.activeUserScope = invalid and m.apiKey = "" and m.registry.flushes = 0 and m.registry.read("connKey_slot-a") = "default-key" and m.taskCreates = 1, "failure receipt consumption grants no transport/adoption and never deletes the default key or starts another Task")
    pickerNavigationFixture()
    check(beginUserProfileLaunchPicker(false), "failed target focus uses a fresh independent picker")
    onUserProfilePickerIntent(pickerNavigationEvent(m.profilePicker, {action: "select", index: 1}))
    task = m.profileStartupTask
    m.global.requestGateRequired = true
    m.global.requestGate = {ready: false}
    onStartupProfileResult(pickerNavigationEvent(task, {ok: false, relogin: true}))
    check(m.profilePicker.model.focus = 1 and m.profilePicker.model.tiles[1].username = "bob", "failed different-target selection preserves that holder's focus, not the restored current holder")
    onUserProfilePickerIntent(pickerNavigationEvent(m.profilePicker, {action: "select", index: 1}))
    check(m.taskCreates = 1 and m.profileStartupTask = invalid and m.activeUserScope = invalid and m.apiKey = "", "held target retry opens no Task and borrows no source key")
    pickerNavigationFixture()
    check(deferUserProfileLaunch() and m.profileStartupDeferred and m.apiKey = "" and m.taskCreates = 0 and m.pickerCreates = 0, "private startup waits without reading or authenticating before screen readiness")
    onDeferredUserProfileLaunch()
    check(m.profileStartupDeferred and m.pickerCreates = 0, "timer callback cannot route before actual Main screen-ready signal")
    m.top.startupReady = true
    onSceneStartupReady()
    check(m.routeTimerCreates = 1 and m.profileStartupRoutingTimer.control = "start", "actual screen-ready signal schedules one deferred decision")
    onDeferredUserProfileLaunch()
    check(m.profilePicker <> invalid and m.routeConnectCalls = 0 and m.taskCreates = 0, "ordinary deferred Ask opens picker before all connection work")
    pickerNavigationFixture()
    store = loadUserProfileStore(m.registry, "slot-a")
    store.profiles[0] = setCanonicalPreference(store.profiles[0], "pinType", "numbers")
    store.profiles[0] = setCanonicalPreference(store.profiles[0], "pinHash", string(64, "a"))
    store.profiles[0] = setCanonicalPreference(store.profiles[0], "pinSalt", string(32, "b"))
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(store)
    check(deferUserProfileLaunch(), "deep-link startup is also deferred")
    m.top.launchRequest = {contentId: "missing-channel", mediaType: "live"}
    m.top.startupReady = true
    onSceneStartupReady()
    onDeferredUserProfileLaunch()
    check(m.pickerCreates = 0 and m.routePinTarget = m.a.id and m.routeConnectCalls = 0 and m.activeUserScope = invalid, "cold media intent skips picker but still requires the actual restored holder PIN before requests")
    check(m.pendingLaunch.id = "missing-channel" and m.apiKey = "default-key" and m.global.profilegateclosed, "validated link waits behind restored own-key PIN, never incoming target credentials")
    pickerNavigationFixture()
    store = loadUserProfileStore(m.registry, "slot-a")
    store.profiles[0] = setCanonicalPreference(store.profiles[0], "pinType", "numbers")
    store.profiles[0] = setCanonicalPreference(store.profiles[0], "pinHash", string(64, "a"))
    store.profiles[0] = setCanonicalPreference(store.profiles[0], "pinSalt", string(32, "b"))
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(store)
    check(beginUserProfileLaunchPicker(false), "warm media intent starts from a real owned picker")
    m.pendingLaunch = normalizeLaunchRequest({contentId: "missing-channel", mediaType: "live"})
    dismissStartupPickerForDeepLink()
    check(m.profilePicker = invalid and m.profilePickerContext = invalid and m.routePinTarget = m.a.id and m.routeConnectCalls = 0 and m.taskCreates = 0 and m.global.profilegateclosed, "warm media intent closes selection and routes only the actual restored holder's own PIN")
    pickerNavigationFixture()
    store = loadUserProfileStore(m.registry, "slot-a")
    for i = 0 to store.profiles.count() - 1
        store.profiles[i] = setCanonicalPreference(store.profiles[i], "pinType", "numbers")
        store.profiles[i] = setCanonicalPreference(store.profiles[i], "pinHash", string(64, "a"))
        store.profiles[i] = setCanonicalPreference(store.profiles[i], "pinSalt", string(32, "b"))
    end for
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(store)
    check(beginUserProfileLaunchPicker(false), "warm PIN replacement starts with an owned picker")
    onUserProfilePickerIntent(pickerNavigationEvent(m.profilePicker, {action: "pin", index: 1}))
    context = m.profileStartupSelectionContext
    oldDialog = {tag: "incoming-pin", textEditBox: {text: "1234"}, unobserveField: sub(field as string)
    end sub, isSameNode: function(other as object) as boolean
        return other.tag = m.tag
    end function}
    m.profilePinDialog = oldDialog
    m.profilePinContext = {continuation: "startup-selection", resume: context.nonce, slot: "slot-a", profile: context.target}
    m.top.dialog = oldDialog
    m.profileGateClock = {control: "start"}
    m.pendingLaunch = normalizeLaunchRequest({contentId: "missing-channel", mediaType: "live"})
    dismissStartupPickerForDeepLink()
    check(oldDialog.close and oldDialog.textEditBox.text = "" and m.top.dialog = invalid and m.profileGateClock.control = "stop", "owned incoming native PIN is detached and scrubbed before the restored PIN replaces it")
    check(m.routePinTarget = m.a.id and m.profileStartupSelectionContext = invalid and m.taskCreates = 0 and m.global.profilegateclosed, "PIN replacement never authenticates chosen target or borrows its proof")
    pickerNavigationFixture()
    check(deferUserProfileLaunch(), "connection lease is captured before screen-ready")
    m.registry.values["connectionsV1"] = m.registry.read("connectionsV1") + " "
    m.top.startupReady = true
    onSceneStartupReady()
    onDeferredUserProfileLaunch()
    check(m.pickerCreates = 0 and m.taskCreates = 0 and m.routeConnectCalls = 0 and m.apiKey = "" and m.global.profilegateclosed and m.registry.flushes = 0, "changed captured connection root cannot resume startup or overwrite storage")
    pickerNavigationFixture()
    check(beginUserProfileLaunchPicker(false), "identity mismatch has its own fresh selection")
    onUserProfilePickerIntent(pickerNavigationEvent(m.profilePicker, {action: "select", index: 1}))
    task = m.profileStartupTask
    onStartupProfileResult(pickerNavigationEvent(task, {ok: false, identityChanged: true}))
    check(m.profilePicker.message = "Sign in as bob to verify this profile's account.", "identity mismatch is not mislabeled as typed key rejection or transient failure")
    onUserProfilePickerIntent(pickerNavigationEvent(m.profilePicker, {action: "select", index: 1}))
    check(m.taskCreates = 1 and m.profileStartupTask = invalid and m.profileStartupSelectionContext = invalid, "known mismatched cached credential cannot be retried")
    check(m.registry.flushes = 0 and m.registry.read("connKey_slot-a") = "default-key" and m.registry.read(userProfileKeyName("slot-a", m.profilePickerContext.store.profiles[1].id)) = "bob-own-key", "mismatch preserves source and target keys without adopting either identity")
    connection = m.profilePickerContext.connection
    target = m.profilePickerContext.store.profiles[1]
    check(startupProfileIdentityRefused(connection, target, "bob-own-key"), "owned mismatch retains exact failed credential identity")
    changed = copyPreferenceValue(connection)
    changed.url = "https://other.example.test"
    check(not startupProfileIdentityRefused(changed, target, "bob-own-key"), "refusal does not cross server address")
    changed = copyPreferenceValue(connection)
    changed.id = "slot-b"
    check(not startupProfileIdentityRefused(changed, target, "bob-own-key"), "refusal does not cross connection slots")
    changedTarget = setCanonicalPreference(target, "username", "new-bob")
    check(not startupProfileIdentityRefused(connection, changedTarget, "bob-own-key"), "refusal cannot poison a different recorded account identity")
    onUserProfilePickerIntent(pickerNavigationEvent(m.profilePicker, {action: "select", index: 0}))
    check(m.taskCreates = 2 and m.profileStartupTask.apiKey = "default-key", "target mismatch cannot deny independent source credential")
    failStartupProfileSelection("Independent source attempt cancelled.")
    onStartupProfileResult(pickerNavigationEvent(task, {ok: false, identityChanged: true}))
    keyName = userProfileKeyName("slot-a", m.profilePickerContext.store.profiles[1].id)
    m.registry.values[keyName] = "bob-new-own-key"
    onUserProfilePickerIntent(pickerNavigationEvent(m.profilePicker, {action: "select", index: 1}))
    check(m.taskCreates = 3 and m.profileStartupTask.apiKey = "bob-new-own-key", "retired stale mismatch cannot poison a different credential")
    pickerNavigationFixture()
    check(beginUserProfileLaunchPicker(false), "restored identity mismatch starts privately")
    onUserProfilePickerIntent(pickerNavigationEvent(m.profilePicker, {action: "select", index: 0}))
    onStartupProfileResult(pickerNavigationEvent(m.profileStartupTask, {ok: false, identityChanged: true}))
    m.pendingLaunch = normalizeLaunchRequest({contentId: "missing-channel", mediaType: "live"})
    dismissStartupPickerForDeepLink()
    check(m.routeConnectCalls = 0 and m.taskCreates = 1 and m.activeUserScope = invalid and m.apiKey = "" and m.global.profilegateclosed, "media intent cannot retry a restored holder's known-mismatched key")
    pickerNavigationFixture()
    check(beginUserProfileLaunchPicker(false), "startup own-form admission begins without an authenticated actor")
    targetId = m.profilePickerContext.store.profiles[1].id
    m.registry.values[userProfileKeyName("slot-a", targetId)] = ""
    admission = startupProfileOwnSignInAdmission(targetId)
    check(admission.ok and admission.target.id = targetId and admission.target.username = "bob" and not admission.requiresPin, "inactive keyless full-access holder has a distinct own-form admission")
    check(m.activeUserScope = invalid and m.apiKey = "" and m.taskCreates = 0 and m.registry.flushes = 0, "own-form admission grants no key, request, storage change or outgoing scope")
    m.apiKey = "default-key"
    check(not startupProfileOwnSignInAdmission(targetId).ok, "startup own form cannot borrow a restored runtime key")
    m.apiKey = ""
    m.activeUserScope = {profileId: "source"}
    check(not startupProfileOwnSignInAdmission(targetId).ok, "authenticated callers must use the separate ordinary own-form boundary")
    m.activeUserScope = invalid
    m.profilePickerReady = false
    check(not startupProfileOwnSignInAdmission(targetId).ok, "shipping-off controller cannot admit a startup form")
    m.profilePickerReady = true
    m.registry.values["connectionsV1"] = m.registry.read("connectionsV1") + " "
    check(not startupProfileOwnSignInAdmission(targetId).ok, "changed raw connection root refuses before credentials")
    pickerNavigationFixture()
    store = loadUserProfileStore(m.registry, "slot-a")
    store.profiles[1] = setCanonicalPreference(store.profiles[1], "pinType", "numbers")
    store.profiles[1] = setCanonicalPreference(store.profiles[1], "pinHash", string(64, "a"))
    store.profiles[1] = setCanonicalPreference(store.profiles[1], "pinSalt", string(32, "b"))
    store.profiles[1] = setCanonicalPreference(store.profiles[1], "addressHeld", true)
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(store)
    check(beginUserProfileLaunchPicker(false), "held protected target remains visible only behind the source's launch selection")
    targetId = store.profiles[1].id
    admission = startupProfileOwnSignInAdmission(targetId)
    check(admission.ok and admission.requiresPin and admission.target.addressHeld, "held target admits only own credential recovery and still requires its real PIN")
    m.registry.values[userProfileStoreKey("slot-a")] = m.registry.read(userProfileStoreKey("slot-a")) + " "
    check(not startupProfileOwnSignInAdmission(targetId).ok, "changed raw roster cannot reuse old own-form admission")
    pickerNavigationFixture()
    store = loadUserProfileStore(m.registry, "slot-a")
    store.profiles[1] = setCanonicalPreference(store.profiles[1], "role", "child")
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(store)
    check(beginUserProfileLaunchPicker(false), "restored adult can see a Child tile without Child admission")
    check(not startupProfileOwnSignInAdmission(store.profiles[1].id).ok, "Child selection is not full-access own-form authority")
    check(startupProfileOwnSignInAdmission(store.active).ok, "restored active default can enter only its known-identity startup own form")
    pickerNavigationFixture()
    check(beginUserProfileLaunchPicker(false), "startup form cancellation has its own covered picker")
    nonce = "00000000-0000-4000-8000-000000000090"
    m.global.activeusersession = nonce
    context = {nonce: nonce, target: m.profilePickerContext.store.profiles[1], unlock: invalid}
    finishStartupProfileOwnSignIn(context, false)
    check(m.profilePicker.model.focus = 1 and not m.profilePicker.busy and m.global.profilegateclosed and m.global.activeusersession = "" and m.taskCreates = 0, "own-form cancellation keeps chosen target focused without authentication")
    print "ALL TESTS PASSED"
end sub

function beginUserProfileOwnSignIn(targetId as string, activeRecovery = false as boolean, childRecovery = false as boolean, startupRecovery = false as boolean) as boolean
    ' Full form lifecycle is qualified by its own controller suite.
    return false
end function

sub pickerNavigationFixture()
    m.a = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "alice", user_level: 1}, 1)
    b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "bob", user_level: 1}, 1)
    b = setCanonicalPreference(b, "isDefault", false)
    store = defaultUserProfileStore("slot-a")
    store.profiles = [m.a, b]
    store.active = m.a.id
    store = setCanonicalPreference(store, "askAtLaunch", true)
    connection = normalizeConnectionEntry({id: "slot-a", name: "Synthetic", provider: "dispatcharr", url: "https://example.test", accountId: "7", remember: true})
    values = {}
    values["connectionsV1"] = FormatJson({schema: 1, selected: "slot-a", entries: [connection]})
    values[userProfileStoreKey("slot-a")] = FormatJson(store)
    values["connKey_slot-a"] = "default-key"
    values[userProfileKeyName("slot-a", b.id)] = "bob-own-key"
    m.registry = {values: values, flushes: 0, exists: function(key as string) as boolean
        return m.values.doesExist(key)
    end function, read: function(key as string) as string
        if m.values.doesExist(key) then return m.values[key]
        return ""
    end function}
    m.connectionStore = loadConnectionStore(m.registry)
    m.selectedConnectionId = "slot-a"
    m.profilePickerReady = true
    m.profilePicker = invalid
    m.profilePickerContext = invalid
    m.profileStartupSelectionContext = invalid
    m.profileStartupTask = invalid
    m.profilePinDialog = invalid
    m.profilePinContext = invalid
    m.profileGateClock = {control: "stop"}
    m.adultPinDialog = invalid
    m.activeUserScope = invalid
    m.apiKey = "default-key"
    m.global = {profilegateclosed: false, profileswitchpending: false, activeusersession: ""}
    m.top = {appended: 0, gateMessage: {}, findNode: function(id as string) as object
        return m.gateMessage
    end function, setFocus: function(value as boolean) as boolean
        return true
    end function, appendChild: function(node as object) as boolean
        m.appended++
        return true
    end function, removeChild: function(node as object) as boolean
        return true
    end function}
    m.profileGateCover = {visible: true}
    m.guide = {active: false}
    m.profileSessionKeys = {}
    m.profileStartupIdentityRefusals = {}
    ' Native launch qualification uses the real SHA256; host lacks byte crypto.
    m.profileStartupCredentialDigest = function(key as string) as string
        return "host-digest-" + key
    end function
    m.pickerCreates = 0
    m.taskCreates = 0
    m.routeConnectCalls = 0
    m.routeTimerCreates = 0
    m.routePinTarget = ""
    m.profileStartupDeferred = false
    m.profileStartupScreenReady = false
    m.profileStartupRoutingStarted = false
    m.profileStartupRoutingTimer = invalid
    m.profileStartupLaunchConnection = invalid
    m.profileLaunchPickerResolved = false
    m.profileLaunchPickerDeepLink = false
    m.pendingLaunch = invalid
    m.startupDialogOpen = true
    m.startupBeaconSent = false
    m.top.launchRequest = {}
    m.top.startupReady = false
    m.top.signalBeacon = sub(name as string)
    end sub
    m.profileStartupRoutingTimerFactory = function() as object
        m.routeTimerCreates++
        return {control: "stop", observeField: function(field as string, callback as string) as boolean
            return true
        end function, unobserveField: sub(field as string)
        end sub}
    end function
    m.profilePickerFactory = function() as object
        m.pickerCreates++
        return {tag: "picker", observeField: function(field as string, callback as string) as boolean
            return true
        end function, unobserveField: function(field as string) as boolean
            return true
        end function, isSameNode: function(other as object) as boolean
            return other.tag = m.tag
        end function, setFocus: function(focus as boolean) as boolean
            return true
        end function}
    end function
    m.profileStartupTaskFactory = function(kind as string) as object
        m.taskCreates++
        return {tag: "startup-task", isSameNode: function(other as object) as boolean
            return other.tag = m.tag
        end function, observeField: function(field as string, callback as string) as boolean
            return true
        end function, unobserveField: function(field as string) as boolean
            return true
        end function}
    end function
end sub

function pickerNavigationEvent(node as object, data as object) as object
    return {node: node, data: data, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as object
        return m.data
    end function}
end function

function beginProfilePinGate(profile as object, continuation as string, resume = invalid as dynamic) as boolean
    m.routePinTarget = profile.id
    return true
end function

sub connectServer(skipRfi = false as boolean)
    m.routeConnectCalls++
end sub

sub drawSetup()
    m.routeDrewSetup = true
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
