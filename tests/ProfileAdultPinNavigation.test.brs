sub main()
    setupAdultControllerFixture()
    check(beginAdultProfilePinGate(), "adult gate opens native numeric pad")
    check(m.adultPinDialog.title = "Enter a PIN from an Admin or Standard profile" and m.global.profilegateclosed and m.profileGateCover.visible, "adult pad masks all holder names behind a cover")
    event = {node: m.adultPinDialog, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as integer
        return 0
    end function}
    m.adultPinDialog.textEditBox.text = "9999"
    onAdultProfilePinSubmit(event)
    check(m.authorized = 0 and m.adultPinDialog.textEditBox.text = "" and m.adultPinDialog.title = "Wrong PIN", "wrong adult input clears transient text and keeps authority closed")
    m.adultPinDialog.textEditBox.text = "1234"
    onAdultProfilePinSubmit(event)
    check(m.authorized = 1 and m.adultPinDialog = invalid and m.profileManagementGrant.id = m.fixtureHolder, "only persisted matching adult holder creates a management-purpose grant")
    check(not m.global.profilegateclosed and not m.profileGateCover.visible and m.profileUnlockGrant = invalid, "adult verification restores caller cover but never grants profile unlock")
    setupAdultControllerFixture()
    m.global.profilegateclosed = true
    m.profileGateCover.visible = true
    beginAdultProfilePinGate()
    event.node = m.adultPinDialog
    onAdultProfilePinClosed(event)
    check(m.authorized = 0 and m.adultPinDialog = invalid and m.global.profilegateclosed and m.profileGateCover.visible and m.top.exitRequested <> true, "Child unavailable cancellation returns to original protected screen, not app exit or setup")
    setupAdultControllerFixture()
    beginAdultProfilePinGate()
    event.node = m.adultPinDialog
    m.profileManagementNonce = "00000000-0000-4000-8000-000000000091"
    m.adultPinDialog.textEditBox.text = "1234"
    onAdultProfilePinSubmit(event)
    check(m.authorized = 0 and m.profileManagementGrant = invalid and m.profileGateCover.visible, "retired A/B/A UI context cannot restore an old uncovered screen or grant")
    setupAdultControllerFixture()
    store = loadUserProfileStore(m.registry, "slot-a")
    store.profiles[0] = setCanonicalPreference(store.profiles[0], "pinType", "none")
    store.profiles[0] = setCanonicalPreference(store.profiles[0], "pinHash", "")
    store.profiles[0] = setCanonicalPreference(store.profiles[0], "pinSalt", "")
    m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
    check(beginAdultProfilePinGate() and m.authorized = 1 and m.profileManagementGrant.kind = "stranded", "only actual absence of both PIN types allows explicit stranded grant")
    setupAdultControllerFixture()
    m.profileManagementPending = {action: "baseline-add", returnToPhoneOnboarding: true}
    beginAdultProfilePinGate()
    event.node = m.adultPinDialog
    onAdultProfilePinClosed(event)
    check(m.phoneReturned and m.profileManagementPending = invalid and m.profileManagementGrant = invalid, "cancelled current adult Add gate returns to phone onboarding without granting access")
    setupAdultControllerFixture()
    m.profileManagementPending = {action: "baseline-add", returnToPhoneOnboarding: true}
    beginAdultProfilePinGate()
    event.node = m.adultPinDialog
    m.profileManagementNonce = "00000000-0000-4000-8000-000000000091"
    onAdultProfilePinClosed(event)
    check(not m.phoneReturned, "retired adult gate cannot resurrect phone onboarding")
    setupAdultControllerFixture()
    store = loadUserProfileStore(m.registry, "slot-a")
    store.profiles[0] = setCanonicalPreference(store.profiles[0], "pinType", "directions")
    m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
    m.profileNativePinKeyboardReady = true
    check(beginAdultProfilePinGate(), "all-Directions adults route from numeric default to native keyboard, never stranded bypass")
    check(m.adultPinContext.keyboard and m.adultPinContext.inputType = "directions" and m.top.dialog <> invalid, "adult Directions uses owned native dialog without revealing holder names")
    check(m.adultPinDialog.keyboardDomain = "password" and m.adultPinDialog.textEditBox.secureMode and m.adultPinDialog.textEditBox.voiceEnabled, "adult keyboard masks letters and requests native voice")
    event.node = m.adultPinDialog
    m.adultPinDialog.text = "up down left right"
    m.pinPolicyDigest = function(salt as string, normalized as string) as string
        if normalized = "UDLR" then return string(64, "a")
        return string(64, "c")
    end function
    onAdultProfilePinSubmit(event)
    check(m.authorized = 1 and m.profileManagementGrant.pinType = "directions" and m.profileUnlockGrant = invalid, "native Directions adult gate grants only management purpose")
    check(m.top.dialog = invalid and event.node.text = "" and event.node.textEditBox.text = "", "adult success detaches owned native keyboard and scrubs both text aliases")
    beginAdultProfilePinGate("directions")
    event.node = m.adultPinDialog
    m.adultPinDialog.text = "up down left right"
    m.profileManagementNonce = "00000000-0000-4000-8000-000000000091"
    onAdultProfilePinSubmit(event)
    check(m.adultPinDialog = invalid and event.node.text = "" and m.profileManagementGrant = invalid, "retired native adult keyboard scrubs text without granting successor management authority")
    setupAdultControllerFixture()
    m.profileNativePinKeyboardReady = true
    beginAdultProfilePinGate()
    event.node = m.adultPinDialog
    m.adultPinDialog.textEditBox.text = "1234"
    onAdultProfilePinSubmit(event)
    check(m.authorized = 1 and m.profileManagementGrant.pinType = "numbers", "numeric adult pad remains compatible when native Directions is enabled")
    print "ALL TESTS PASSED"
end sub

sub setupAdultControllerFixture()
    m.fixtureHolder = "00000000-0000-4000-8000-000000000001"
    profile = userProfileFromVerified("slot-a", m.fixtureHolder, {id: 7, username: "SecretHolderName", user_level: 1}, 1)
    profile.pinType = "numbers"
    profile.pinHash = string(64, "a")
    profile.pinSalt = string(32, "b")
    store = defaultUserProfileStore("slot-a")
    store.profiles = [profile]
    store.active = profile.id
    m.registry = {values: {}, exists: function(key as string) as boolean
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
        return true
    end function}
    m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
    m.selectedConnectionId = "slot-a"
    m.profileManagementNonce = "00000000-0000-4000-8000-000000000090"
    m.profileManagementGrant = invalid
    m.adultPinDialog = invalid
    m.adultPinContext = invalid
    m.profileUnlockGrant = invalid
    m.profileGateCover = {visible: false}
    m.global = {profilegateclosed: false}
    m.authorized = 0
    m.phoneReturned = false
    m.top = {createChild: function(kind as string) as object
        return {observeField: sub(field as string, callback as string)
        end sub, unobserveField: sub(field as string)
        end sub}
    end function, removeChild: sub(node as object)
    end sub}
    m.adultPinDialogFactory = function() as object
        return {title: "", text: "", textEditBox: {text: "", hasField: function(field as string) as boolean
            return false
        end function}, observeField: sub(field as string, callback as string)
        end sub, unobserveField: sub(field as string)
        end sub, setFocus: sub(focus as boolean)
        end sub, isSameNode: function(other as object) as boolean
            return other.title = m.title
        end function}
    end function
    m.pinPolicyDigest = function(salt as string, normalized as string) as string
        if normalized = "1234" then return string(64, "a")
        return string(64, "c")
    end function
end sub

sub continuePhoneProfileOnboarding()
    m.phoneReturned = true
end sub

sub onAdultProfileAuthorized()
    m.authorized++
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
