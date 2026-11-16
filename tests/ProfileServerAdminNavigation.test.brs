sub main()
    entry = normalizeConnectionEntry({id: "slot-a", name: "Fixture", provider: "dispatcharr", url: "https://example.test", remember: true})
    base = userProfileFromVerified(entry.id, "00000000-0000-4000-8000-000000000001", {id: 1, username: "Base", user_level: 10}, 1)
    actor = userProfileFromVerified(entry.id, "00000000-0000-4000-8000-000000000002", {id: 2, username: "Actor", user_level: 10}, 2)
    actor.isDefault = false
    store = defaultUserProfileStore(entry.id)
    store.profiles = [base, actor]
    store.active = actor.id
    m.registry = {values: {}, exists: function(key as string) as boolean
        return m.values.doesExist(key)
    end function, read: function(key as string) as string
        if m.values.doesExist(key) then return m.values[key]
        return ""
    end function}
    m.registry.values["connectionsV1"] = FormatJson({schema: 1, selected: entry.id, entries: [entry]})
    m.registry.values[userProfileStoreKey(entry.id)] = FormatJson(store)
    m.activeUserScope = userProfileSessionScope(entry, actor.id, "2", "verified", "00000000-0000-4000-8000-000000000090")
    m.global = {activeusersession: m.activeUserScope.sessionId, profilegateclosed: false}
    m.selectedConnectionId = entry.id
    m.profileBaselineReady = true
    m.role = "admin"
    m.page = "settings"
    context = {scope: m.activeUserScope, page: m.page, connectionRoot: m.registry.read("connectionsV1"), storeRoot: m.registry.read(userProfileStoreKey(entry.id)), adding: false}
    m.profileServerAdminContext = context
    check(profileServerAdminHint() and profileServerAdminCurrent(), "dual persisted admin hints admit only fresh scope and exact roots before live checks")
    m.global.activeusersession = "00000000-0000-4000-8000-000000000091"
    check(not profileServerAdminCurrent(), "successor session retires old admin UI before transport")
    m.global.activeusersession = m.activeUserScope.sessionId
    m.role = "child"
    check(not profileServerAdminCurrent(), "Child cannot invoke admin handlers directly")
    m.role = "admin"
    m.registry.values[userProfileStoreKey(entry.id)] = m.registry.values[userProfileStoreKey(entry.id)] + " "
    check(not profileServerAdminCurrent(), "changed persisted root refuses stale admin action")
    target = {id: 3, username: "Target", api_key: "temporary-own-key"}
    minted = {key: "minted-here"}
    context.users = [target]
    context.target = target
    context.minted = {"3": minted}
    retireProfileServerAdmin()
    check(target.api_key = "" and minted.key = "" and m.profileServerAdminContext = invalid, "retired admin UI wipes listed and minted raw keys, not merely its top-level pointer")
    print "ALL TESTS PASSED"
end sub

function currentUserSettingsRole() as string
    return m.role
end function

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
