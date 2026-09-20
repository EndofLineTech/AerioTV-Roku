sub init()
    m.top.functionName = "runCatchup"
end sub

sub runCatchup()
    m.base = normalizeBaseUrl(m.top.baseUrl)
    m.key = m.top.apiKey
    m.timeout = 10000
    root = m.base + "/api/catchup/sessions/"
    result = {ok: false, message: "Archive session unavailable."}
    if m.top.operation = "delete"
        if CreateObject("roRegex", "^[A-Za-z0-9_-]{16,128}$", "").isMatch(m.top.sessionId)
            response = sessionMutation(root + m.top.sessionId + "/", "DELETE")
            result = {ok: response.status = 204 or response.status = 404, status: response.status}
        end if
    else if m.top.operation = "position"
        if CreateObject("roRegex", "^[A-Za-z0-9_-]{16,128}$", "").isMatch(m.top.sessionId) and not m.top.cancelRequested
            response = sessionMutation(root + m.top.sessionId + "/position/", "POST", {position_secs: m.top.position, paused: m.top.paused})
            result = {ok: response.status = 204, status: response.status}
        end if
    else if not m.top.cancelRequested
        user = requestJson(m.base + "/api/accounts/users/me/")
        if type(user) = "roAssociativeArray"
            if textValue(user.id) = m.top.accountId and not m.top.cancelRequested and catchupEligible(m.top.program, 30, CreateObject("roDateTime").asSeconds())
                stamp = CreateObject("roDateTime")
                stamp.fromSeconds(m.top.program.startsAt)
                duration = int((m.top.program.endsAt - m.top.program.startsAt + 59) / 60)
                response = sessionMutation(root, "POST", {channel_uuid: m.top.channelUuid, start: stamp.toISOString(), duration: duration})
                result.status = response.status
                url = catchupSessionUrl(m.base, m.top.channelUuid, response.data, CreateObject("roDateTime").asSeconds())
                if response.status = 201 and url <> ""
                    result = {ok: true, url: url, sessionId: response.data.session_id, expiresAt: response.data.expires_at}
                    if m.top.cancelRequested then sessionMutation(root + result.sessionId + "/", "DELETE")
                else
                    if response.status = 201 and type(response.data) = "roAssociativeArray"
                        id = textValue(response.data.session_id)
                        if CreateObject("roRegex", "^[A-Za-z0-9_-]{16,128}$", "").isMatch(id) then sessionMutation(root + id + "/", "DELETE")
                    end if
                    result.message = "Archive unavailable (HTTP " + response.status.toStr() + "). The provider may not retain this program. Live playback was not substituted."
                end if
            end if
        end if
    end if
    m.key = ""
    m.top.apiKey = ""
    if m.top.cancelRequested then return
    m.top.result = result
end sub
