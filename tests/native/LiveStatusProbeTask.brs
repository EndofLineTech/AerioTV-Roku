sub init()
    m.top.functionName = "sampleStatus"
end sub

sub sampleStatus()
    m.base = m.top.baseUrl
    m.key = m.top.apiKey
    m.timeout = 1500
    clock = CreateObject("roTimespan")
    clock.mark()
    baseline = invalid
    firstSource = ""
    port = CreateObject("roMessagePort")
    while clock.totalSeconds() < 115 and not m.top.cancelRequested
        data = requestJson(m.base + "/proxy/ts/status/" + m.top.channelUuid)
        if type(data) = "roAssociativeArray" and type(data.clients) = "roArray"
            otherIds = {}
            for each client in data.clients
                id = textValue(client.id)
                if id = "" then id = textValue(client.client_id)
                if id <> "" then otherIds[id] = true
            end for
            if baseline = invalid then baseline = otherIds
            lost = 0
            for each id in baseline
                if not otherIds.doesExist(id) then lost++
            end for
            added = 0
            for each id in otherIds
                if not baseline.doesExist(id) then added++
            end for
            source = textValue(data.url)
            if firstSource = "" then firstSource = source
            sameSource = "unknown"
            if source <> "" and firstSource <> ""
                sameSource = "changed"
                if source = firstSource then sameSource = "same"
            end if
            print "[live-probe-status] seconds="; clock.totalSeconds(); " clients="; data.clients.count(); " newIds="; added; " baseline="; baseline.count(); " missingBaseline="; lost; " source="; sameSource
        else
            status = 0
            if type(m.httpFailure) = "roAssociativeArray" then status = m.httpFailure.status
            if baseline = invalid and status = 404 then baseline = {}
            print "[live-probe-status] seconds="; clock.totalSeconds(); " status-unavailable HTTP="; status
        end if
        m.top.ready = baseline <> invalid
        wait(2000, port)
    end while
    m.key = ""
    m.top.apiKey = ""
end sub
