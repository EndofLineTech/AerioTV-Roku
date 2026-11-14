' Pure address-change policy. Only callers holding a successful default /me/
' may record its verified local profile. No requests, keys, URL writes or runtime
' adoption occur here; the controller must commit the hold plan before traffic.
function userProfileDefaultAddressCheck(connection as object, previous as object, verified as dynamic) as object
    store = normalizeUserProfileStore(previous, connection.id)
    if store.readOnly = true or connection.provider <> "dispatcharr" then return {ok: false}
    unchanged = {ok: true, store: store}
    if type(verified) <> "roAssociativeArray" then return unchanged
    if verified.ok <> true or type(verified.verifiedBaseUrl) <> "String" and type(verified.verifiedBaseUrl) <> "roString" then return unchanged
    if normalizeBaseUrl(verified.verifiedBaseUrl) <> connection.url then return unchanged
    if type(verified.verifiedUser) <> "roAssociativeArray" then return unchanged
    identity = normalizeUserProfileAddressIdentity({userId: verified.verifiedUser.id, username: verified.verifiedUser.username})
    ownDefault = false
    for each profile in store.profiles
        if profile.isDefault
            ownDefault = userProfileAddressIdentityMatches(identity, {userId: profile.userId, username: profile.username})
        end if
    end for
    if not ownDefault then return unchanged
    store = setCanonicalPreference(store, "verifiedDefaultAtAddress", {url: connection.url, identity: identity})
    unchanged.store = store
    if not store.doesExist("addressChangeSnapshot") then return unchanged
    if not userProfileAddressIdentityMatches(identity, store["addressChangeSnapshot"]) then return unchanged
    checked = userProfileAddressCheckPlan(store, verified.verifiedUser)
    if not checked.ok then return checked
    for each profile in checked.store.profiles
        if profile.addressHeld then return checked
    end for
    checked.store.delete("addressChangeSnapshot")
    return checked
end function

' Current-address evidence is separate from the comparison identity frozen by
' outstanding holds. Never fall back to knownDefault when tagging own recovery.
function userProfileLiveDefaultAt(connection as object, previous as object) as dynamic
    store = normalizeUserProfileStore(previous, connection.id)
    if store.readOnly = true or not store.doesExist("verifiedDefaultAtAddress") then return invalid
    proof = store["verifiedDefaultAtAddress"]
    if proof.url <> connection.url then return invalid
    for each profile in store.profiles
        if profile.isDefault
            if not userProfileAddressIdentityMatches(proof.identity, {userId: profile.userId, username: profile.username}) then return invalid
            return {id: proof.identity["userId"], username: proof.identity["username"]}
        end if
    end for
    return invalid
end function

function userProfileAddressOrigin(url as string) as string
    url = normalizeBaseUrl(url)
    if url = "" then return ""
    parts = CreateObject("roRegex", "^(https?)://(\[[^\]]+\]|[^:/?#@\s]+)(:([0-9]{1,5}))?(/.*)?$", "i").match(url)
    if parts.count() < 3 then return ""
    scheme = lcase(parts[1])
    port = 80
    if scheme = "https" then port = 443
    if parts.count() > 4
        if parts[4] <> "" then port = parts[4].toInt()
    end if
    if port < 1 or port > 65535 then return ""
    return scheme + "://" + lcase(parts[2]) + ":" + port.toStr()
end function

' Run only after this profile's own successful verification/ID migration. A
' held profile requires sign-in, never a saved-key check. The
' optional default answer must be a live default-owned /me/ at this address,
' never the frozen record. No such answer means an explicit unknown tag.
function userProfileAddressOwnTagPlan(previous as object, targetId as string, verifiedOwn as dynamic, verifiedDefault as dynamic, signedIn as boolean) as object
    store = normalizeUserProfileStore(previous, previous.playlistId)
    if store.readOnly = true then return {ok: false}
    own = invalid
    if type(verifiedOwn) = "roAssociativeArray" then own = normalizeUserProfileAddressIdentity({userId: verifiedOwn.id, username: verifiedOwn.username})
    tag = invalid
    if type(verifiedDefault) = "roAssociativeArray"
        tag = normalizeUserProfileAddressIdentity({userId: verifiedDefault.id, username: verifiedDefault.username})
        if tag = invalid then return {ok: false}
    else if verifiedDefault <> invalid
        return {ok: false}
    end if
    for i = 0 to store.profiles.count() - 1
        profile = store.profiles[i]
        if profile.id = targetId and not profile.isDefault
            if profile.addressHeld and not signedIn then return {ok: false}
            expected = normalizeUserProfileAddressIdentity({userId: profile.userId, username: profile.username})
            if not userProfileAddressIdentityMatches(expected, own) then return {ok: false}
            profile = setCanonicalPreference(profile, "defaultIdentityTag", tag)
            store.profiles[i] = setCanonicalPreference(profile, "addressHeld", false)
            return {ok: true, store: store}
        end if
    end for
    return {ok: false}
end function

function userProfileAddressIdentityMatches(first as dynamic, second as dynamic) as boolean
    first = normalizeUserProfileAddressIdentity(first)
    second = normalizeUserProfileAddressIdentity(second)
    if first = invalid or second = invalid then return false
    return first["userId"] = second["userId"] and lcase(first["username"]) = lcase(second["username"])
end function

' The slot's own form has a stricter known-user order than a non-default form.
' A missing recorded identity means a username-only legacy expectation: do not
' invent an authoritative ID from cleared connection metadata or an active user.
function userProfileKnownDefaultExpectation(connection as object, previous as object) as object
    denied = {ok: false}
    if connection.provider <> "dispatcharr" or connection.id <> previous.playlistId then return denied
    store = normalizeUserProfileStore(previous, connection.id)
    if store.readOnly = true then return denied
    defaultProfile = invalid
    for each profile in store.profiles
        if profile.isDefault then defaultProfile = profile
    end for
    if defaultProfile = invalid then return denied
    if store.doesExist("knownDefault")
        identity = store["knownDefault"]
        return {ok: true, userId: identity["userId"], username: identity["username"], profileId: defaultProfile.id, source: "recorded"}
    end if
    username = connection.accountUsername
    if username = invalid then username = ""
    if type(username) <> "String" and type(username) <> "roString" then return denied
    source = "slot-username"
    if username.trim() = ""
        username = defaultProfile.username
        source = "default-username"
    end if
    if userProfileUtf8ByteCount(username) > 256 then return denied
    if CreateObject("roRegex", "[\x00-\x1F\x7F]", "").isMatch(username) then return denied
    return {ok: true, userId: invalid, username: username, profileId: defaultProfile.id, source: source}
end function

function userProfileDefaultOwnIdentityMatches(connection as object, previous as object, verified as dynamic) as boolean
    expected = userProfileKnownDefaultExpectation(connection, previous)
    if not expected.ok or type(verified) <> "roAssociativeArray" then return false
    actual = normalizeUserProfileAddressIdentity({userId: verified.id, username: verified.username})
    if actual = invalid then return false
    if lcase(actual["username"]) <> lcase(expected.username) then return false
    if expected.userId <> invalid then return actual["userId"] = expected.userId
    return true
end function

function userProfileRecordDefaultIdentity(previous as object, changeInProgress as boolean) as object
    denied = {ok: false}
    store = normalizeUserProfileStore(previous, previous.playlistId)
    if store.readOnly = true then return denied
    if changeInProgress then return {ok: true, store: store}
    defaultProfile = invalid
    held = false
    for each profile in store.profiles
        if profile.addressHeld then held = true
        if profile.isDefault then defaultProfile = profile
    end for
    if defaultProfile = invalid then return denied
    if held
        if not store.doesExist("knownDefault") then return {ok: true, store: store}
        identity = store["knownDefault"]
    else
        identity = normalizeUserProfileAddressIdentity({userId: defaultProfile.userId, username: defaultProfile.username})
        if identity = invalid then return denied
        store = setCanonicalPreference(store, "knownDefault", identity)
    end if
    for i = 0 to store.profiles.count() - 1
        profile = store.profiles[i]
        if not profile.isDefault and not profile.doesExist("defaultIdentityTag")
            store.profiles[i] = setCanonicalPreference(profile, "defaultIdentityTag", copyPreferenceValue(identity))
        end if
    end for
    return {ok: true, store: store}
end function

function userProfileAddressChangePlan(connection as object, previous as object, nextUrl as string) as object
    denied = {ok: false, changed: false}
    if connection.provider <> "dispatcharr" or connection.id <> previous.playlistId then return denied
    store = normalizeUserProfileStore(previous, connection.id)
    if store.readOnly = true then return denied
    for each profile in store.profiles
        if profile.id = store.active and profile.role = "child" then return denied
    end for
    origin = userProfileAddressOrigin(nextUrl)
    if origin = "" then return denied
    if normalizeBaseUrl(nextUrl) <> connection.url then store.delete("verifiedDefaultAtAddress")
    for i = 0 to store.profiles.count() - 1
        profile = store.profiles[i]
        if not profile.doesExist("preferenceAnchor")
            anchor = connectionPreferenceIdentity(connection, profile.userId.toStr())
            if anchor = "" then return denied
            store.profiles[i] = setCanonicalPreference(profile, "preferenceAnchor", anchor)
        end if
    end for
    if origin = userProfileAddressOrigin(connection.url) then return {ok: true, changed: false, store: store}
    snapshot = invalid
    if store.doesExist("knownDefault") then snapshot = store["knownDefault"]
    store.delete("addressChangeSnapshot")
    if snapshot <> invalid then store = setCanonicalPreference(store, "addressChangeSnapshot", snapshot)
    defaultProfile = invalid
    for i = 0 to store.profiles.count() - 1
        profile = store.profiles[i]
        if profile.isDefault
            defaultProfile = profile
        else
            if not profile.doesExist("defaultIdentityTag") and snapshot <> invalid
                profile = setCanonicalPreference(profile, "defaultIdentityTag", snapshot)
            end if
            store.profiles[i] = setCanonicalPreference(profile, "addressHeld", true)
        end if
    end for
    if defaultProfile = invalid then return denied
    store.active = defaultProfile.id
    return {ok: true, changed: true, store: store, snapshot: snapshot, childDefault: defaultProfile.role = "child"}
end function


' Only a successful default-owned /me/ at the changed address is eligible.
' Wrong/missing identity retains every hold. This does not auto-select anyone.
function userProfileAddressCheckPlan(previous as object, verifiedDefault as dynamic) as object
    store = normalizeUserProfileStore(previous, previous.playlistId)
    if store.readOnly = true then return {ok: false}
    identity = invalid
    if type(verifiedDefault) = "roAssociativeArray"
        identity = normalizeUserProfileAddressIdentity({userId: verifiedDefault.id, username: verifiedDefault.username})
    end if
    if not store.doesExist("addressChangeSnapshot") then return {ok: true, store: store}
    snapshot = store["addressChangeSnapshot"]
    if not userProfileAddressIdentityMatches(snapshot, identity) then return {ok: true, store: store}
    for i = 0 to store.profiles.count() - 1
        profile = store.profiles[i]
        if not profile.isDefault and profile.addressHeld
            tag = invalid
            if profile.doesExist("defaultIdentityTag") then tag = profile["defaultIdentityTag"]
            if userProfileAddressIdentityMatches(tag, snapshot) then store.profiles[i] = setCanonicalPreference(profile, "addressHeld", false)
        end if
    end for
    return {ok: true, store: store}
end function
