' Unavailable Child access never routes through connection/receiver setup.
' keyRejected is independent of key presence so deletion cannot bypass it.
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
