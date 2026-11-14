sub main()
    unavailableChildFixture()
    check(showUnavailableChildProfile(), "private keyless Child has an own unavailable surface, not generic setup")
    check(m.childUnavailableDialog.buttons.count() = 2 and m.childUnavailableDialog.buttons[0] = "Sign in to Dispatcharr", "keyless Child gets only own Sign In and adult-gated Manage, never the default key's Retry")
    check(instr(1, m.childUnavailableDialog.title + m.childUnavailableDialog.message, "Alice") = 0, "unavailable screen reveals no other profile name")
    onUnavailableChildChoice(childUnavailableEvent(m.childUnavailableDialog, 0))
    check(m.fixtureOwnId = m.fixtureChild and m.fixtureOwnActive and m.fixtureOwnChild and m.activeUserScope = invalid, "keyless own action uses active-Child credential routing without inventing an authenticated scope")
    unavailableChildFixture()
    m.registry.values[userProfileKeyName("slot-a", m.fixtureChild)] = "synthetic-child-key"
    check(showUnavailableChildProfile() and m.childUnavailableDialog.buttons[0] = "Retry", "available own key offers Retry instead of a password form")
    onUnavailableChildChoice(childUnavailableEvent(m.childUnavailableDialog, 0))
    check(m.fixtureRetried and m.apiKey = "synthetic-child-key" and m.registry.read("connKey_slot-a") = "synthetic-default" and m.activeUserScope = invalid, "Retry uses only the Child's own key and starts a fresh own auth path")
    unavailableChildFixture()
    m.childRejectedIdentity = m.baseUrl + "|slot-a|" + m.fixtureChild
    check(showUnavailableChildProfile() and m.childUnavailableDialog.buttons.count() = 1 and m.childUnavailableDialog.buttons[0] = "Manage Profiles", "refused nondefault Child stays Child with neither Retry nor Sign In after key deletion")
    onUnavailableChildChoice(childUnavailableEvent(m.childUnavailableDialog, 0))
    check(m.fixtureManaged and m.fixtureOwnId = "", "unavailable Child leaves only through adult-gated management admission")
    unavailableChildFixture()
    store = loadUserProfileStore(m.registry, "slot-a")
    store.profiles[1] = setCanonicalPreference(store.profiles[1], "addressHeld", true)
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(store)
    m.registry.values[userProfileKeyName("slot-a", m.fixtureChild)] = "synthetic-held-child"
    check(showUnavailableChildProfile() and m.childUnavailableDialog.buttons.count() = 1, "held retained key cannot be sent or disguised as keyless own recovery")
    m.registry.values.delete(userProfileKeyName("slot-a", m.fixtureChild))
    check(showUnavailableChildProfile() and m.childUnavailableDialog.buttons[0] = "Sign in to Dispatcharr", "held-keyless Child retains its own identity-only login route")
    unavailableChildFixture()
    check(showUnavailableChildProfile(), "key-state transition fixture opens keyless own surface")
    old = m.childUnavailableDialog
    m.registry.values[userProfileKeyName("slot-a", m.fixtureChild)] = "synthetic-new-child-key"
    onUnavailableChildChoice(childUnavailableEvent(old, 0))
    check(m.fixtureOwnId = "" and m.childUnavailableDialog.buttons[0] = "Retry", "a newly available own key revalidates the old Sign In action rather than opening a stale form")
    old = m.childUnavailableDialog
    showUnavailableChildProfile()
    onUnavailableChildChoice(childUnavailableEvent(old, 1))
    check(not m.fixtureManaged, "retired native unavailable nodes cannot disclose management identities")
    unavailableChildFixture()
    m.profileChildAccessReady = false
    check(not showUnavailableChildProfile() and m.childUnavailableDialog = invalid, "shipping keyless Child path stays fenced until the private access controller is fully qualified")
    unavailableChildFixture()
    store = loadUserProfileStore(m.registry, "slot-a")
    store.profiles[0] = setCanonicalPreference(store.profiles[0], "role", "child")
    store.profiles[1] = setCanonicalPreference(store.profiles[1], "role", "user")
    store.active = store.profiles[0].id
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(store)
    m.registry.values.delete("connKey_slot-a")
    m.childRejectedIdentity = m.baseUrl + "|slot-a|" + store.active
    check(showUnavailableChildProfile() and m.childUnavailableDialog.buttons[0] = "Sign in to Dispatcharr", "default Child may recover its own refused slot login without exposing general setup")
    onUnavailableChildChoice(childUnavailableEvent(m.childUnavailableDialog, 0))
    check(m.fixtureOwnId = store.active and m.fixtureOwnChild, "default Child Sign In targets only its own saved identity")
    store = setCanonicalPreference(store, "knownDefault", {userId: 77, username: "Alice"})
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(store)
    check(showUnavailableChildProfile() and m.childUnavailableDialog.buttons.count() = 1 and m.childUnavailableDialog.buttons[0] = "Manage Profiles", "conflicting known default identity never advertises an unavailable Child own form")
    print "ALL TESTS PASSED"
end sub

sub unavailableChildFixture()
    a = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "Alice", user_level: 1}, 1)
    b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "Bob", user_level: 1}, 2)
    b = setCanonicalPreference(b, "isDefault", false)
    b = setCanonicalPreference(b, "role", "child")
    store = defaultUserProfileStore("slot-a")
    store.profiles = [a, b]
    store.active = b.id
    entry = normalizeConnectionEntry({id: "slot-a", name: "Synthetic", provider: "dispatcharr", url: "https://example.test", accountId: "7", remember: true})
    m.connectionStore = {schema: 1, selected: "slot-a", entries: [entry]}
    m.selectedConnectionId = "slot-a"
    m.baseUrl = entry.url
    m.fixtureChild = b.id
    values = {connectionsV1: FormatJson(m.connectionStore)}
    values[userProfileStoreKey("slot-a")] = FormatJson(store)
    values["connKey_slot-a"] = "synthetic-default"
    m.registry = {values: values, exists: function(key as string) as boolean
        return m.values.doesExist(key)
    end function, read: function(key as string) as string
        if not m.values.doesExist(key) then return ""
        return m.values[key]
    end function}
    m.profileChildAccessReady = true
    m.userProfileRecoveryRequired = false
    m.activeUserScope = invalid
    m.apiKey = ""
    m.profileSessionKeys = {}
    m.childRejectedIdentity = ""
    m.childUnavailableDialog = invalid
    m.childUnavailableContext = invalid
    m.profileUnlockGrant = invalid
    m.requestGate = invalid
    m.global = {profilegateclosed: true, activeusersession: "", profileswitchpending: false}
    m.profileGateCover = {visible: true}
    m.page = "profile-unavailable"
    m.guide = {active: false, visible: false}
    m.screen = {visible: false}
    m.top = {label: {}, findNode: function(id as string) as object
        return m.label
    end function}
    m.factorySequence = 0
    m.childUnavailableDialogFactory = function() as object
        m.factorySequence++
        return {id: m.factorySequence, isSameNode: function(other as object) as boolean
            return m.id = other.id
        end function, observeField: sub(field as string, callback as string)
        end sub, unobserveField: sub(field as string)
        end sub, setFocus: sub(focus as boolean)
        end sub}
    end function
    m.fixtureOwnId = ""
    m.fixtureManaged = false
    m.fixtureRetried = false
end sub

function childUnavailableEvent(node as object, choice as integer) as object
    return {node: node, choice: choice, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as integer
        return m.choice
    end function}
end function

function beginUserProfileOwnSignIn(id as string, activeRecovery as boolean, childRecovery as boolean) as boolean
    m.fixtureOwnId = id
    m.fixtureOwnActive = activeRecovery
    m.fixtureOwnChild = childRecovery
    return true
end function

sub openUserProfileManagement()
    m.fixtureManaged = true
end sub

sub closeChildRejectedKeyDialog()
end sub

function showChildRejectedKeyPrompt() as boolean
    return false
end function

sub connectServer(skipRfi as boolean)
    m.fixtureRetried = skipRfi and m.apiKey = "synthetic-child-key" and not m.global.profilegateclosed and m.profileGateCover.visible
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
