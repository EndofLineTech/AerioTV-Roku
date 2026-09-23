' Dispatcharr 0.31 /api/channels/series-rules/ is distinct from recurring-rules.
' Preview is read-only; saving an exact existing identity would UPSERT it, so
' preflight and refuse duplicates. Never bulk-remove other users' rules.
function seriesRuleBody(draft as dynamic) as dynamic
    if type(draft) <> "roAssociativeArray" then return invalid
    title = left(textValue(draft.title).trim(), 160)
    if title = "" or len(textValue(draft.title)) > 160 then return invalid
    if draft.mode <> "all" and draft.mode <> "new" then return invalid
    if draft.titleMode <> "exact" and draft.titleMode <> "contains" and draft.titleMode <> "search" then return invalid
    if draft.descriptionMode <> "contains" and draft.descriptionMode <> "search" then return invalid
    description = left(textValue(draft.description).trim(), 160)
    if len(textValue(draft.description)) > 160 then return invalid
    body = {title: title, mode: draft.mode, title_mode: draft.titleMode, description: description, description_mode: draft.descriptionMode}
    tvg = left(textValue(draft.tvgId).trim(), 128)
    if tvg <> "" then body.tvg_id = tvg
    channelId = textValue(draft.channelId)
    if channelId <> ""
        if not recordingIdValid(channelId) then return invalid
        body.channel_id = channelId.toInt()
    end if
    sourceId = textValue(draft.epgSourceId)
    if sourceId <> ""
        if not recordingIdValid(sourceId) then return invalid
        body.epg_source_id = sourceId.toInt()
    end if
    if draft.mode = "new" and draft.untaggedIsNew = true then body.untagged_is_new = true
    return body
end function

function normalizeSeriesRule(raw as dynamic) as dynamic
    if type(raw) <> "roAssociativeArray" then return invalid
    title = textValue(raw.title)
    if title = "" or len(title) > 160 then return invalid
    mode = textValue(raw.mode)
    if mode <> "all" and mode <> "new" then return invalid
    titleMode = textValue(raw.title_mode)
    if titleMode = "" then titleMode = "exact"
    descriptionMode = textValue(raw.description_mode)
    if descriptionMode = "" then descriptionMode = "contains"
    return {title: title, tvgId: textValue(raw.tvg_id), channelId: textValue(raw.channel_id), mode: mode, titleMode: titleMode, description: textValue(raw.description), descriptionMode: descriptionMode, epgSourceId: textValue(raw.epg_source_id)}
end function

function listSeriesRules(baseUrl as string, apiKey as string) as object
    m.base = baseUrl
    m.key = apiKey
    m.timeout = 30000
    m.maxResponseBytes = 200000
    response = requestJson(m.base + "/api/channels/series-rules/")
    if response = invalid then return recordingFailure()
    if type(response.rules) <> "roArray" then return {ok: false, message: "Invalid server series rules."}
    if response.rules.count() > 100 then return {ok: false, message: "Series rules exceed this Roku's 100-item limit."}
    rows = []
    for each raw in response.rules
        row = normalizeSeriesRule(raw)
        if row <> invalid then rows.push(row)
    end for
    return {ok: true, rules: rows}
end function

function previewSeriesRule(baseUrl as string, apiKey as string, draft as dynamic) as object
    body = seriesRuleBody(draft)
    if body = invalid then return {ok: false, message: "Choose a valid series title and matching options."}
    m.base = baseUrl
    m.key = apiKey
    m.timeout = 30000
    m.maxResponseBytes = 200000
    body.limit = 10
    response = requestJson(m.base + "/api/channels/series-rules/preview/", body, "", "POST")
    if response = invalid then return recordingFailure()
    if response.epg_found = false then return {ok: false, message: "No matching EPG channel was found. Check the series scope."}
    if type(response.matches) <> "roArray" or not recordingEpochValid(response.total) then return {ok: false, message: "Invalid series preview response."}
    return {ok: true, total: response.total, matches: response.matches, warn: response.warn = true}
end function

function sameSeriesRule(rule as object, body as object) as boolean
    return rule.title = body.title and rule.tvgId = textValue(body.tvg_id) and rule.epgSourceId = textValue(body.epg_source_id)
end function

function dvrSeriesEscape(value as string) as string
    encoded = ""
    safe = CreateObject("roRegex", "^[a-zA-Z0-9_.~-]$", "")
    digits = "0123456789ABCDEF"
    for i = 1 to len(value)
        letter = mid(value, i, 1)
        if safe.isMatch(letter)
            encoded += letter
        else
            byte = asc(letter)
            encoded += "%" + mid(digits, (byte \ 16) + 1, 1) + mid(digits, (byte mod 16) + 1, 1)
        end if
    end for
    return encoded
end function

function createSeriesRule(baseUrl as string, apiKey as string, draft as dynamic) as object
    body = seriesRuleBody(draft)
    if body = invalid then return {ok: false, message: "Choose a valid series title and matching options."}
    if textValue(body.tvg_id) = "" then return {ok: false, message: "Choose a mapped EPG channel for safe rule evaluation."}
    existing = listSeriesRules(baseUrl, apiKey)
    if not existing.ok then return existing
    for each rule in existing.rules
        if rule.title = body.title and rule.tvgId = textValue(body.tvg_id) then return {ok: false, category: "duplicate", message: "A rule for this series and EPG channel already exists. Open Series rules to review it."}
    end for
    response = requestJson(m.base + "/api/channels/series-rules/", body, "", "POST")
    if response = invalid then return recordingFailure()
    if response.success <> true then return {ok: false, message: "Server did not confirm the series rule. Refresh rules before retrying."}
    evaluation = requestJson(m.base + "/api/channels/series-rules/evaluate/", {tvg_id: textValue(body.tvg_id)}, "", "POST")
    if evaluation = invalid or evaluation.success <> true then return {ok: false, category: "ambiguous", message: "Rule saved but evaluation was not confirmed. Check Series rules and Scheduled before retrying."}
    return {ok: true, evaluation: evaluation}
end function

function deleteSeriesRule(baseUrl as string, apiKey as string, draft as dynamic) as object
    body = seriesRuleBody(draft)
    if body = invalid then return {ok: false, message: "Invalid series rule identity."}
    existing = listSeriesRules(baseUrl, apiKey)
    if not existing.ok then return existing
    count = 0
    siblings = 0
    for each rule in existing.rules
        if rule.title = body.title and rule.tvgId = textValue(body.tvg_id) then siblings++
        if sameSeriesRule(rule, body) then count++
    end for
    ' The server DELETE treats an absent source as a wildcard and a specified
    ' source as also matching unsourced legacy copies. Never remove siblings.
    if count <> 1 or siblings <> 1 then return {ok: false, category: "state", message: "Rule changed or shares this title and EPG channel with another source. Refresh Series rules before removing it."}
    url = m.base + "/api/channels/series-rules/?tvg_id=" + dvrSeriesEscape(textValue(body.tvg_id)) + "&title=" + dvrSeriesEscape(body.title)
    if body.epg_source_id <> invalid then url += "&epg_source_id=" + dvrSeriesEscape(textValue(body.epg_source_id))
    response = requestJson(url, invalid, "", "DELETE")
    if response = invalid then return recordingFailure()
    if response.success <> true then return {ok: false, message: "Server did not confirm rule removal. Refresh before retrying."}
    return {ok: true, removed: response.removed}
end function
