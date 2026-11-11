' Pure synthetic catalog, shared by the read-only Task substitutes and tests.
function uiAuditVodItem(number as integer, kind as string) as object
    id = number.toStr()
    title = "Synthetic Movie " + id
    if kind = "series" then title = "Synthetic Series " + id
    if kind = "episode" then title = "Episode " + id + ": Across the stars"
    if number mod 20 = 2 then title = "A deliberately long synthetic title for checking wrapping and readable focus"
    synopsis = "The crew explores a distant world and discovers a new way home. This is original synthetic test data, not provider media. "
    return {id: id, uuid: "fixture-" + kind + "-" + id, key: kind + ":fixture-" + kind + "-" + id, accountScope: "ui-audit", kind: kind, title: title
        description: synopsis + synopsis + synopsis + synopsis + synopsis + synopsis + synopsis + synopsis + synopsis
        year: "2026", rating: "PG", genre: "Adventure", duration: 5400, logoId: "", season: ((number - 1) \ 8 + 1).toStr(), episode: id, seriesId: "1", seriesTitle: "Synthetic Series 1", seriesLogoId: ""
        streamFormat: "mp4", actors: "Synthetic Actor A, Synthetic Actor B", director: "Synthetic Director", airDate: "2026-11-11", tmdbId: "", seriesTmdbId: "", trailerId: "", providerId: "", tmdbPosterPath: ""}
end function

function uiAuditVodResult(kind as string, operation as string, page as integer, itemId as string, scenario as string) as object
    result = {ok: true, items: [], total: 45, next: "", message: "", patches: [], partial: false}
    if instr(1, scenario, "error") > 0 or instr(1, scenario, "denied") > 0
        result.ok = false
        result.message = "Synthetic provider unavailable. No real request was made."
        result.status = 503
        if instr(1, scenario, "denied") > 0
            result.message = "Synthetic permission denied (403)."
            result.status = 403
        end if
        return result
    end if
    if instr(1, scenario, "empty") > 0
        result.total = 0
        return result
    end if
    if itemId <> "" and operation <> "versions"
        result.item = uiAuditVodItem(itemId.toInt(), kind)
        return result
    end if
    if page < 1 then page = 1
    for i = (page - 1) * 20 + 1 to page * 20
        if i > result.total then exit for
        item = uiAuditVodItem(i, kind)
        if operation = "categories" or operation = "providers" or operation = "versions"
            item.kind = "category"
            item.value = i.toStr()
            item.title = "Synthetic category " + i.toStr()
            if operation = "providers" then item.title = "Synthetic provider " + i.toStr()
            if operation = "versions" then item.title = "Synthetic source version " + i.toStr()
            if i = 2 then item.title = "A deliberately long category or source label that wraps inside its control"
            item.year = ""
            item.rating = ""
        end if
        result.items.push(item)
    end for
    if page < 3 then result.next = "synthetic-next"
    return result
end function

function uiAuditRecordings(scenario as string) as object
    rows = []
    now = CreateObject("roDateTime").asSeconds()
    states = ["recording", "scheduled", "completed", "failed"]
    if scenario = "dvr-empty" or scenario = "dvr-rules" then return rows
    if scenario = "dvr-completed" then states = ["completed"]
    if scenario = "dvr-scheduled" then states = ["scheduled"]
    if scenario = "dvr-recording" then states = ["recording"]
    if scenario = "dvr-failed" then states = ["failed"]
    for each state in states
        for i = 1 to 12
            n = rows.count() + 1
            startAt = now - n * 3600
            if state = "scheduled" then startAt = now + n * 3600
            if state = "recording" then startAt = now - 600
            startTime = CreateObject("roDateTime") : startTime.fromSeconds(startAt)
            endTime = CreateObject("roDateTime") : endTime.fromSeconds(startAt + 1800)
            title = "Synthetic " + state + " " + i.toStr()
            if i = 2 then title = "A deliberately long recording title for checking grid captions and dialogs"
            rows.push({id: n.toStr(), channelId: "1", startTime: startTime.toISOString(), endTime: endTime.toISOString(), status: state, programId: "fixture"
                title: title, description: "Original synthetic recording. No server file or stream exists.", posterLogoId: "", fileReady: state = "completed", fileFormat: "mp4", hlsReady: state = "recording"
                comskipStatus: "", comskipReason: "", comskipSkipped: false, comskipMode: ""})
        end for
    end for
    return rows
end function

function uiAuditRules(scenario as string) as object
    if scenario = "dvr-empty" then return []
    return [{title: "Synthetic Series Rule", mode: "new", titleMode: "exact", tvgId: "synthetic-channel", description: "Match new episodes only.", epgSourceId: "1", channelId: "1"}
        {title: "A long synthetic series rule title for checking details and removal confirmation", mode: "all", titleMode: "contains", tvgId: "synthetic-channel", description: "Original fixture", epgSourceId: "1", channelId: "1"}]
end function
