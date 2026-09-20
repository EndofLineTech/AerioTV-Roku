sub init()
    m.top.functionName = "loadInfo"
end sub

sub loadInfo()
    m.base = m.top.baseUrl
    m.key = m.top.apiKey
    uuid = m.top.channelUuid
    result = {ok: false, message: "Invalid channel identifier.", channelUuid: uuid, details: serverStreamDetails(invalid)}
    if CreateObject("roRegex", "^[A-Za-z0-9-]+$", "").isMatch(uuid)
        ' Existing admin-only metadata endpoint; no media URL or probe connection.
        raw = requestJson(m.base + "/proxy/ts/status/" + uuid)
        result.ok = type(raw) = "roAssociativeArray"
        result.details = serverStreamDetails(raw, m.key)
        result.message = m.failure
    end if
    m.key = ""
    m.top.apiKey = ""
    if m.top.cancelRequested = true then return
    m.top.result = result
end sub
