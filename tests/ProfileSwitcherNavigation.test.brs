sub main()
    entry = normalizeConnectionEntry({id: "slot-a", name: "Fixture", provider: "dispatcharr", url: "https://example.test", remember: true})
    a = userProfileFromVerified(entry.id, "00000000-0000-4000-8000-000000000001", {id: 1, username: "Alice", user_level: 1}, 1)
    b = userProfileFromVerified(entry.id, "00000000-0000-4000-8000-000000000002", {id: 2, username: "Bob", user_level: 1}, 2)
    b.isDefault = false
    store = defaultUserProfileStore(entry.id)
    store.profiles = [a, b]
    store.active = a.id
    m.connectionStore = {schema: 1, selected: entry.id, entries: [entry]}
    m.registry = {values: {}, exists: function(key as string) as boolean
        return m.values.doesExist(key)
    end function, read: function(key as string) as string
        if m.values.doesExist(key) then return m.values[key]
        return ""
    end function}
    m.registry.values["connectionsV1"] = FormatJson(m.connectionStore)
    m.registry.values[userProfileStoreKey(entry.id)] = FormatJson(store)
    m.activeUserScope = userProfileSessionScope(entry, a.id, "1", "verified", "00000000-0000-4000-8000-000000000090")
    m.global = {activeusersession: m.activeUserScope.sessionId, profilegateclosed: false}
    m.top = {}
    m.page = "guide"
    m.baseUrl = entry.url
    m.selectedConnectionId = entry.id
    m.apiKey = "source-own-key"
    m.profileBaselineReady = true
    m.scopedPreferencesRequired = true
    m.userProfileStore = loadUserProfileStore(m.registry, entry.id)
    m.profileSwitcher = {id: "owned-picker", model: userProfilePickerPlan(m.userProfileStore, "switcher", "dispatcharr", false), isSameNode: function(other as object) as boolean
        return other.id = m.id
    end function}
    nonce = "00000000-0000-4000-8000-000000000091"
    m.profileSwitcherContext = {nonce: nonce, page: m.page, scope: m.activeUserScope, connectionRoot: m.registry.read("connectionsV1"), storeRoot: m.registry.read(userProfileStoreKey(entry.id))}
    check(userProfileSwitcherCurrent(), "live switcher belongs to an actually adopted holder and current roots")
    before = FormatJson(m.registry.values)
    event = {node: m.profileSwitcher, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as object
        return {action: "switch", index: 1, uiNonce: "00000000-0000-4000-8000-000000000099"}
    end function}
    onUserProfileSwitcherIntent(event)
    check(FormatJson(m.registry.values) = before and m.profileSwitchContext = invalid, "retired UI nonce cannot switch or write through the same picker node")
    original = m.activeUserScope
    m.activeUserScope = userProfileSessionScope(entry, a.id, "1", "verified", "00000000-0000-4000-8000-000000000092")
    m.global.activeusersession = m.activeUserScope.sessionId
    check(not userProfileSwitcherCurrent(), "A/B/A re-adoption cannot reuse an old switcher context")
    m.activeUserScope = original
    m.global.activeusersession = original.sessionId
    m.registry.values[userProfileStoreKey(entry.id)] = "{invalid"
    check(not userProfileSwitcherCurrent(), "unreadable current roster prevents a new switch intent")
    m.profileBaselineMenu = {id: "closed-menu", close: false, isSameNode: function(other as object) as boolean
        return m.id = other.id
    end function, unobserveField: sub(field as string)
    end sub}
    event.node = m.profileBaselineMenu
    event.getData = function() as dynamic
        return invalid
    end function
    onProfileBaselineClosed(event)
    check(m.profileBaselineMenu = invalid, "native void wasClosed retires the compatibility menu without a boolean payload")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
