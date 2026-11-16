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
    print "ALL TESTS PASSED"
end sub

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
    m.adultPinDialog = invalid
    m.activeUserScope = invalid
    m.apiKey = "default-key"
    m.global = {profilegateclosed: false, profileswitchpending: false, activeusersession: ""}
    m.top = {appended: 0, appendChild: function(node as object) as boolean
        m.appended++
        return true
    end function, removeChild: function(node as object) as boolean
        return true
    end function}
    m.profileGateCover = {visible: true}
    m.guide = {active: false}
    m.profileSessionKeys = {}
    m.pickerCreates = 0
    m.taskCreates = 0
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
        return {observeField: function(field as string, callback as string) as boolean
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

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
