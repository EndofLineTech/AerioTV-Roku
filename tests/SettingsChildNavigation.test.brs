sub main()
    m.global = {activeusersession: "current"}
    m.scopedPreferencesRequired = true
    m.selectedConnectionId = "slot-a"
    m.userProfileStore = {active: "profile-a", profiles: [{id: "profile-a", role: "child", userId: 7}]}
    m.activeUserScope = {profileId: "profile-a", playlistId: "slot-a", accountId: "7"}
    check(currentUserSettingsRole() = "child", "Settings reads the active scoped role, not the view's last role label")
    m.page = "settings"
    m.accountIdentity = "own"
    m.devicePreferences = normalizeDevicePreferences({networkTimeoutSeconds: 20})
    m.preferenceStore = defaultPreferenceStore()
    m.settingsHub = {model: {userRole: "user", device: m.devicePreferences}, isSameNode: function(node as object) as boolean
        return true
    end function}
    event = {value: {account: "own", aeriosession: "current", scope: "device", key: "networkTimeoutSeconds", value: 30}, getData: function() as object
        return m.value
    end function, getRoSGNode: function() as object
        return {}
    end function}
    m.saved = 0
    onSettingsHubSelection(event)
    check(m.saved = 0 and m.devicePreferences.networkTimeoutSeconds = 20, "a current-session forged hidden setting is denied even when the rendered model still says Standard")
    event.value = {account: "own", aeriosession: "current", value: 30}
    onSettingsHubSelection(event)
    check(m.saved = 0, "malformed current-session setting events are refused before typed scope/key calls")
    event.value = {account: "own", aeriosession: "current", action: "connection"}
    onSettingsHubSelection(event)
    check(m.page = "settings" and m.connectionOpened = invalid, "Child cannot invoke connection setup through a stale event")
    event.value = {account: "own", aeriosession: "current", action: "profiles-manage"}
    onSettingsHubSelection(event)
    check(m.managementOpened = true, "Child management shortcut goes through the existing adult-purpose gate controller")
    m.activeUserScope.profileId = "retired-profile"
    check(currentUserSettingsRole() = "restricted", "mismatched active/store identity cannot inherit Standard Settings")
    m.managementOpened = false
    onSettingsHubSelection(event)
    check(not m.managementOpened, "a mismatched session cannot use the Child shortcut to reveal a different selected profile roster")
    m.activeUserScope.profileId = "profile-a"
    m.activeUserScope.accountId = "8"
    check(currentUserSettingsRole() = "restricted", "matching local profile ID cannot borrow another authenticated account's role")
    m.scopedPreferencesRequired = false
    check(currentUserSettingsRole() = "user", "non-Dispatcharr provider Settings preserve their existing contract")
    print "ALL TESTS PASSED"
end sub

function persistPreferences() as boolean
    m.saved++
    return true
end function

sub applyDevicePreferences()
end sub

sub openUserProfileManagement()
    m.managementOpened = true
end sub

sub showConnection()
    m.connectionOpened = true
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
