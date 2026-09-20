' Isolated feasibility fixture: not imported by a production component.
sub init()
    m.top.functionName = "probeOperation"
end sub

sub probeOperation()
    m.base = normalizeBaseUrl(m.top.baseUrl)
    m.key = m.top.apiKey
    m.timeout = 4000
    result = {ok: false}
    if m.top.operation = "status"
        status = requestJson(m.base + "/proxy/ts/status/" + m.top.channelUuid)
        ids = sourceClientSnapshot(status)
        if ids <> invalid
            result = {ok: true, clients: ids, count: ids.count()}
        else if type(m.httpFailure) = "roAssociativeArray"
            if m.httpFailure.status = 404 then result = {ok: true, clients: {}, count: 0}
        end if
    else if m.top.operation = "archiveStats"
        stats = requestJson(m.base + "/proxy/catchup/stats/")
        if type(stats) = "roAssociativeArray"
            if type(stats.timeshift_sessions) = "roArray"
                result = {ok: true, found: false, providerId: ""}
                for each session in stats.timeshift_sessions
                    if session.session_id = m.top.sessionId
                        result.found = true
                        if type(session.connections) = "roArray"
                            for each connection in session.connections
                                if type(connection.m3u_profile) = "roAssociativeArray" then result.providerId = textValue(connection.m3u_profile.account_id)
                            end for
                        end if
                    end if
                end for
            end if
        end if
    else if m.top.operation = "delete"
        response = sessionMutation(m.base + "/api/catchup/sessions/" + m.top.sessionId + "/", "DELETE")
        result = {ok: response.status = 204 or response.status = 404, status: response.status}
    else if m.top.operation = "restart"
        user = requestJson(m.base + "/api/accounts/users/me/")
        if type(user) = "roAssociativeArray"
            if textValue(user.id) = m.top.accountId and not m.top.cancelRequested
                stamp = CreateObject("roDateTime")
                stamp.fromSeconds(m.top.startEpoch)
                response = sessionMutation(m.base + "/api/catchup/sessions/", "POST", {channel_uuid: m.top.channelUuid, start: stamp.toISOString(), duration: m.top.durationMinutes})
                url = catchupSessionUrl(m.base, m.top.channelUuid, response.data, CreateObject("roDateTime").asSeconds())
                result.status = response.status
                if response.status = 201 and url <> ""
                    result = {ok: true, status: 201, url: url, sessionId: response.data.session_id, echoedStart: response.data.start}
                    if m.top.cancelRequested then sessionMutation(m.base + "/api/catchup/sessions/" + result.sessionId + "/", "DELETE")
                else if response.status = 201 and type(response.data) = "roAssociativeArray"
                    id = textValue(response.data.session_id)
                    if CreateObject("roRegex", "^[A-Za-z0-9_-]{16,128}$", "").isMatch(id) then sessionMutation(m.base + "/api/catchup/sessions/" + id + "/", "DELETE")
                end if
            end if
        end if
    end if
    m.key = ""
    m.top.apiKey = ""
    if m.top.cancelRequested then return
    m.top.result = result
end sub
