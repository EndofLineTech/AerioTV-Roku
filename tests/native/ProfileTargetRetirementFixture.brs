' Private fixture only: B is genuinely active and non-default; A is a different
' default. C's own App Data tombstones C before any C lineup can be acquired.
function advanceProfileTargetRetirementProbe() as boolean
    if m.switchProbeTargetChecked = true then return true
    entry = connectionStoreEntry(m.connectionStore, "slot-a")
    targetId = "00000000-0000-4000-8000-000000000003"
    targetAccount = preferenceScope(connectionPreferenceIdentity(entry, "9"))
    foreignAccount = preferenceScope("https://foreign.test|99|slot-b")
    memoryBucket = preferenceScope(entry.url + "|slot-a|" + targetId)
    if m.switchProbeTargetStarted <> true
        m.switchProbeTargetStarted = true
        m.switchProbeBeforeTarget = currentUserSessionId()
        store = loadUserProfileStore(m.registry, "slot-a")
        third = userProfileFromVerified("slot-a", targetId, {id: 9, username: "Synthetic9", user_level: 1}, 1)
        third = setCanonicalPreference(third, "isDefault", false)
        third = setCanonicalPreference(third, "order", 2)
        store.profiles.push(third)
        m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
        m.registry.write(userProfileKeyName("slot-a", targetId), "synthetic-c")
        m.registry.write(userProfilePinBackoffKey("slot-a", targetId), FormatJson({failures: 1, round: 0, until: 0}))
        m.preferenceStore.accounts[targetAccount] = normalizeAccountPreferences({favoriteIds: ["99"]})
        m.preferenceStore.accounts[foreignAccount] = {future: "retain"}
        m.registry.write("settingsV1", FormatJson(m.preferenceStore))
        m.profileSessionKeys[memoryBucket] = "synthetic-c"
        m.registry.flush()
        seeded = loadUserProfileStore(m.registry, "slot-a")
        seededSettings = ParseJson(m.registry.read("settingsV1"), "d")
        m.switchProbeTargetSeeded = m.activeUserScope.accountId = "8" and seeded.active = m.activeUserScope.profileId and seeded.profiles.count() = 3 and m.registry.exists(userProfileKeyName("slot-a", targetId)) and m.registry.exists(userProfilePinBackoffKey("slot-a", targetId)) and seededSettings.accounts.doesExist(targetAccount)
        m.switchProbeTargetAdmitted = beginUserProfileSwitch(targetId)
        m.switchProbeTargetContext = m.profileSwitchContext
        return false
    end if
    if m.profileSwitchContext <> invalid then return false
    m.switchProbeTargetChecked = true
    store = loadUserProfileStore(m.registry, "slot-a")
    preferences = ParseJson(m.registry.read("settingsV1"), "d")
    wiped = false
    context = m.switchProbeTargetContext
    if type(context) = "roAssociativeArray"
        if type(context.authentication) = "roAssociativeArray" then wiped = context.key = "" and context.authentication.apiKey = ""
    end if
    retained = m.activeUserScope <> invalid and m.page = "guide" and not m.profileGateCover.visible and not m.global.profilegateclosed
    if retained then retained = m.activeUserScope.accountId = "8" and store.active = m.activeUserScope.profileId and currentUserSessionId() <> m.switchProbeBeforeTarget and m.apiKey = "synthetic-b" and m.guide.callFunc("profileSwitchProbeLineup") = "8" and m.banner.session.apiKey = "synthetic-b" and m.accountPreferences.favoriteIds[0] = "8" and m.devicePreferences.themePreset = "forest"
    cleaned = store.profiles.count() = 2 and store.removed.count() = 0 and not m.registry.exists(userProfileKeyName("slot-a", targetId)) and not m.registry.exists(userProfilePinBackoffKey("slot-a", targetId)) and not m.profileSessionKeys.doesExist(memoryBucket) and not preferences.accounts.doesExist(targetAccount) and not m.preferenceStore.accounts.doesExist(targetAccount) and preferences.accounts[foreignAccount].future = "retain"
    m.switchProbeTargetRetired = m.switchProbeTargetSeeded and m.switchProbeTargetAdmitted and wiped and retained and cleaned and m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(userProfileKeyName("slot-a", "00000000-0000-4000-8000-000000000002")) = "synthetic-b" and m.profilePinDialog = invalid and m.playingChannel = invalid
    m.switchProbeB = m.switchProbeB and m.switchProbeTargetRetired
    return true
end function
