sub init()
    m.top.functionName = "runSourceOperation"
end sub

sub runSourceOperation()
    m.base = m.top.baseUrl
    m.key = m.top.apiKey
    m.uuid = m.top.channelUuid
    m.operation = m.top.operation
    channelId = m.top.channelId
    streamId = m.top.streamId
    m.clock = CreateObject("roTimespan")
    m.clock.mark()
    m.deadlineMs = 30000
    if not CreateObject("roRegex", "^[0-9]+$", "").isMatch(channelId) or not CreateObject("roRegex", "^[A-Za-z0-9-]+$", "").isMatch(m.uuid)
        failSource("Invalid channel identifier.")
        return
    end if
    ' Recheck identity and permission immediately before any shared mutation.
    user = requestJson(m.base + "/api/accounts/users/me/")
    cap = normalizeCapabilities(user, invalid, invalid, CreateObject("roDateTime").asSeconds())
    if cap.accountId <> m.top.accountId or cap.switchStreams <> "allowed"
        failSource("Source switching requires an authorized Dispatcharr admin account.")
        return
    end if
    user = invalid
    rows = apiRows(requestJson(m.base + "/api/channels/channels/" + channelId + "/streams/"))
    if rows = invalid
        failSource("Could not load stream sources. " + m.failure)
        return
    end if
    status = requestJson(m.base + "/proxy/ts/status/" + m.uuid)
    if type(status) <> "roAssociativeArray"
        failSource("Could not read this channel's active source. " + m.failure)
        return
    end if
    choices = normalizeStreamChoices(rows, status)
    if m.operation = "list"
        completeSource({ok: true, choices: choices, clientCount: textValue(status.client_count).toInt()})
        return
    end if
    valid = false
    for each choice in choices
        if choice.id = streamId then valid = true
    end for
    if not valid
        failSource("That source is no longer a member of this channel. Refresh the source list.")
        return
    end if
    beforeClients = textValue(status.client_count).toInt()
    response = requestJson(m.base + "/proxy/ts/change_stream/" + m.uuid, {stream_id: streamId.toInt()})
    if type(response) <> "roAssociativeArray"
        failSource("The source change failed or could not be confirmed. " + m.failure)
        return
    end if
    targetUrl = textValue(response.url)
    if targetUrl = ""
        failSource("The server accepted the request but did not provide source confirmation. Refresh the source list.")
        return
    end if
    confirmed = false
    untilMs = m.clock.totalMilliseconds() + 6000
    m.timeout = 1500
    while m.clock.totalMilliseconds() < untilMs
        current = requestJson(m.base + "/proxy/ts/status/" + m.uuid)
        if type(current) = "roAssociativeArray"
            if textValue(current.url) = targetUrl
                confirmed = true
                exit while
            end if
        end if
        sleep(200)
    end while
    targetUrl = ""
    if not confirmed
        failSource("Source change was not confirmed. Playback has not been reloaded; refresh the source list before retrying.")
        return
    end if
    ' No video control/content changes: the shared TS connection follows the swap.
    completeSource({ok: true, streamId: streamId, clientCountBefore: beforeClients, clientCountAfter: textValue(current.client_count).toInt()})
end sub

sub failSource(message as string)
    completeSource({ok: false, message: message})
end sub

sub completeSource(result as object)
    result.channelUuid = m.uuid
    result.operation = m.operation
    m.key = ""
    m.top.apiKey = ""
    m.top.result = result
end sub
