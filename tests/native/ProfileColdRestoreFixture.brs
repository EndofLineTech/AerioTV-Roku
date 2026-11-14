' Fresh process, persisted selected holder, real startup authentication/roster/
' full activation. No prior in-memory credentials or profile grants exist.
sub onManagementProbeTick()
    if m.busy or m.page <> "guide" then return
    m.managementProbeClock.control = "stop"
    expected = OWN_COLD_ACCOUNT
    store = loadUserProfileStore(m.registry, "slot-a")
    own = m.activeUserScope <> invalid
    if own then own = m.activeUserScope.accountId = expected and m.activeUserScope.profileId = store.active and currentUserSessionId() <> ""
    theme = "midnight"
    if expected = "8" then theme = "forest"
    data = m.accountPreferences.favoriteIds.count() = 1 and m.devicePreferences.themePreset = theme
    if data then data = m.accountPreferences.favoriteIds[0] = "00000000-0000-4000-8000-" + right("000000000000" + expected, 12)
    credentials = m.registry.read("connKey_slot-a") = "synthetic-a"
    if expected = "8" then credentials = credentials and m.registry.read(userProfileKeyName("slot-a", store.profiles[1].id)) = "synthetic-b"
    holds = store.profiles[1].addressHeld = OWN_COLD_HELD
    preserved = m.preferenceStore.accounts[preferenceScope(m.baseUrl + "|7|slot-a")].favoriteIds.count() = 1 and m.preferenceStore.accounts[preferenceScope(m.baseUrl + "|8|slot-a")].favoriteIds.count() = 1
    print "[profile-management] "; FormatJson({kind: "result", passed: own and data and credentials and holds and preserved and m.playingChannel = invalid, own: own, data: data, credentials: credentials, holds: holds, preserved: preserved, no_autoplay: m.playingChannel = invalid})
end sub
