' Validate in-place without normalizing/copying wire JSON. All future fields,
' doubles, millisecond integers and category members stay exactly as parsed.
function dispatcharrSyncEnvelopeRead(value as dynamic) as object
    denied = {ok: false, state: "invalid", allowWrite: false}
    if type(value) <> "roAssociativeArray" then return denied
    if not dispatcharrSyncInteger(value["schemaVersion"]) then return denied
    if value["schemaVersion"] > 3 then return {ok: false, state: "newer", allowWrite: false}
    if value["schemaVersion"] <> 3 then return denied
    for each field in ["deviceId", "platform", "appVersion"]
        if not dispatcharrSyncRosterString(value[field]) then return denied
    end for
    stamp = dispatcharrSyncIsoEpoch(value["updatedAt"])
    if stamp = invalid then return denied
    if type(value["categories"]) <> "roAssociativeArray" then return denied
    result = {ok: true, state: "ready", allowWrite: false, updatedAt: stamp, raw: value, profilesState: "absent", profiles: invalid, malformedCategories: []}
    for each name in value["categories"]
        category = value["categories"][name]
        valid = dispatcharrSyncCategoryValid(category)
        if name = "profiles"
            result.profilesState = "invalid"
            if valid
                decoded = dispatcharrSyncRosterDecode(category["data"])
                valid = decoded.ok
                if valid
                    result.profilesState = "ready"
                    result.profiles = decoded
                end if
            end if
        end if
        if not valid then result.malformedCategories.push(name)
    end for
    return result
end function

function dispatcharrSyncIsoEpoch(value as dynamic) as dynamic
    if not dispatcharrSyncRosterString(value) then return invalid
    return guideEpoch(value)
end function

function dispatcharrSyncCategoryValid(value as dynamic) as boolean
    if type(value) <> "roAssociativeArray" then return false
    if dispatcharrSyncIsoEpoch(value["updatedAt"]) = invalid then return false
    if type(value["data"]) <> "roAssociativeArray" then return false
    if value.doesExist("extra")
        if type(value["extra"]) <> "roAssociativeArray" then return false
    end if
    if value.doesExist("deviceId")
        if not dispatcharrSyncRosterString(value["deviceId"]) then return false
    end if
    return true
end function
