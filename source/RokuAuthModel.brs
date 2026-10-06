' Roku account data is consent-based and session-only. Never persist the RFI
' payload or substitute the Roku account for a provider account automatically.
function rokuSharedEmail(data as dynamic) as string
    if type(data) <> "roAssociativeArray" then return ""
    if GetInterface(data.email, "ifString") = invalid then return ""
    if CreateObject("roRegex", "[\x00-\x1F]", "").isMatch(data.email) then return ""
    email = data.email.trim()
    if len(email) > 254 then return ""
    if not CreateObject("roRegex", "^[^@\s]+@[^@\s]+\.[^@\s]+$", "").isMatch(email) then return ""
    return email
end function
