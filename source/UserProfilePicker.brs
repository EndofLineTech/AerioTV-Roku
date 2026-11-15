' Presentation and intent only. A picker selection is never authentication,
' a PIN grant, a management grant, or permission to borrow the slot credential.
function userProfilePickerPlan(store as object, purpose as string, provider as string, deepLink as boolean) as object
    plan = {ok: false, show: false, purpose: purpose, tiles: [], focus: 0, back: ""}
    if purpose <> "launch" and purpose <> "switcher" then return plan
    if store.readOnly = true then return plan
    cleaned = normalizeUserProfileStore(store, textValue(store.playlistId))
    if cleaned.readOnly = true then return plan
    plan.ok = true
    if provider <> "dispatcharr" or cleaned.profiles.count() < 2 then return plan
    active = invalid
    for each profile in cleaned.profiles
        if profile.id = cleaned.active then active = profile
    end for
    if active = invalid
        plan.ok = false
        return plan
    end if
    ' Do not even return a hidden list of names to a Child caller.
    if not userProfileFullAccess(active.role) then return plan
    if purpose = "launch" and (deepLink or not cleaned.askAtLaunch) then return plan
    plan.show = true
    plan.back = "close"
    if purpose = "launch" then plan.back = "exit"
    for each profile in userProfileSorted(cleaned.profiles)
        current = profile.id = cleaned.active
        if current then plan.focus = plan.tiles.count()
        plan.tiles.push({kind: "profile", id: profile.id, name: profile.displayName, username: profile.username, avatar: userProfileNormalizeAvatar(profile.avatar), locked: profile.pinType <> "none", current: current})
    end for
    plan.tiles.push({kind: "add", id: "", name: "Add Profile"})
    if purpose = "switcher" then plan.tiles.push({kind: "manage", id: "", name: "Manage Profiles"})
    return plan
end function
