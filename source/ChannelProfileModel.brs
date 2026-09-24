' Server-authorized channel summary is the upper bound. A viewer-selected
' profile can only narrow that lineup; missing memberships fail closed.
function profileRestrictedLineup(channels as object, profiles as dynamic, selectedId as string) as object
    if selectedId = "" then return {ok: true, channels: channels}
    denied = {ok: false, message: "Selected channel profile could not be verified. Choose another profile before connecting."}
    numeric = CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "")
    if not numeric.isMatch(selectedId) or type(profiles) <> "roArray" then return denied
    if profiles.count() > 200 then return denied
    chosen = invalid
    for each profile in profiles
        if type(profile) = "roAssociativeArray"
            if textValue(profile.id) = selectedId then chosen = profile
        end if
    end for
    if chosen = invalid or type(chosen.channels) <> "roArray" then return denied
    if chosen.channels.count() > 5000 then return denied
    allowed = {}
    for each id in chosen.channels
        value = textValue(id)
        if not numeric.isMatch(value) then return denied
        allowed["id_" + value] = true
    end for
    filtered = []
    for each channel in channels
        if allowed.doesExist("id_" + textValue(channel.id)) then filtered.push(channel)
    end for
    return {ok: true, channels: filtered}
end function

function profileChoiceList(profiles as dynamic, selectedId as string) as object
    result = [{title: "Server-authorized default", id: ""}]
    if selectedId = "" then result[0].title = "[Selected] " + result[0].title
    if type(profiles) <> "roArray" then return result
    numeric = CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "")
    for each profile in profiles
        if type(profile) = "roAssociativeArray" and result.count() <= 200
            id = textValue(profile.id)
            name = textValue(profile.name)
            if numeric.isMatch(id) and name <> "" and type(profile.channels) = "roArray"
                title = left(name, 60)
                if id = selectedId then title = "[Selected] " + title
                result.push({title: title, id: id})
            end if
        end if
    end for
    return result
end function
