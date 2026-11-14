' Unavailable Child access never routes through connection/receiver setup.
' keyRejected is independent of key presence so deletion cannot bypass it.
function userProfileChildCredentialName(connection as object, profile as dynamic) as string
    if type(profile) <> "roAssociativeArray" then return ""
    if connection.provider <> "dispatcharr" or profile.role <> "child" or profile.playlistId <> connection.id then return ""
    if not userProfileBoolean(profile.isDefault) or userProfileLocalId(textValue(profile.id)) = "" then return ""
    if profile.isDefault then return connectionRegistryKey(connection.id)
    return userProfileKeyName(connection.id, profile.id)
end function

' Presence does not admit a held/rejected credential. The caller supplies only
' the memory map already resolved for this exact address/slot/local profile.
function userProfileChildKeyPresent(registry as object, connection as object, profile as dynamic, memoryKeys as object) as boolean
    name = userProfileChildCredentialName(connection, profile)
    if name = "" then return false
    if memoryKeys.doesExist(name)
        if textValue(memoryKeys[name]) <> "" then return true
    end if
    if connection.remember <> true then return false
    key = registry.read(name)
    if key = "" and profile.isDefault and connection.id = "legacy" then key = registry.read("apiKey")
    return key <> ""
end function

function userProfileChildAccessPlan(profile as dynamic, keyPresent as boolean, keyRejected as boolean) as object
    denied = {retry: false, signIn: false, manage: false, setup: false}
    if type(profile) <> "roAssociativeArray" then return denied
    if profile.role <> "child" then return denied
    if not userProfileBoolean(profile.isDefault) or not userProfileBoolean(profile.addressHeld) then return denied
    if profile.isDefault and profile.addressHeld then return denied
    retry = keyPresent and not keyRejected and not profile.addressHeld
    signIn = (not keyPresent and not keyRejected) or (profile.isDefault and keyRejected)
    return {retry: retry, signIn: signIn, manage: true, setup: false}
end function

function userProfileChildRejectedPrompt(profile as dynamic, playlist as string, ownFormAllowed as boolean) as dynamic
    if type(profile) <> "roAssociativeArray" then return invalid
    if profile.role <> "child" or not userProfileBoolean(profile.isDefault) then return invalid
    signIn = profile.isDefault and ownFormAllowed
    message = "Dispatcharr no longer accepts the API key for " + playlist + ". It may have been changed on the server."
    buttons = ["Not Now"]
    if signIn
        message += " Sign in with your Dispatcharr username and password to reconnect."
        buttons.unshift("Sign In with Remote")
    end if
    return {title: "API key no longer valid", message: message, buttons: buttons, signIn: signIn}
end function
