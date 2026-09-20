sub init()
    m.top.functionName = "loadEnglishDescription"
end sub

sub loadEnglishDescription()
    m.base = normalizeBaseUrl(m.top.baseUrl)
    m.key = m.top.apiKey
    m.clock = CreateObject("roTimespan")
    m.clock.mark()
    m.deadlineMs = 12000
    m.timeout = 4000
    m.maxResponseBytes = 1048576
    item = m.top.item
    result = {ok: false, key: item.key}
    user = requestJson(m.base + "/api/accounts/users/me/")
    cap = normalizeCapabilities(user, invalid, invalid, CreateObject("roDateTime").asSeconds())
    permitted = cap.movies
    if item.kind <> "movie" then permitted = cap.series
    if cap.accountId <> m.top.accountId or permitted <> "allowed"
        publishDescription(result)
        return
    end if
    props = user.custom_properties
    if type(props) <> "roAssociativeArray" then props = {}
    authorization = metadataCacheDigest(FormatJson({account: cap.accountId, level: cap.level, movies: cap.movies, series: cap.series, hideAdult: props.hide_adult_content}))
    if authorization <> textValue(item.authorization)
        publishDescription(result)
        return
    end if
    scope = metadataCacheDigest(m.base + "|" + cap.accountId)
    generation = authorization + "|english-v1"
    key = "description:" + item.key
    now = CreateObject("roDateTime").asSeconds()
    cached = metadataCacheRead(scope, "vod", key, generation, now, true)
    if cached.state = "fresh"
        publishDescription({ok: true, key: item.key, description: cached.payload.description})
        return
    end if
    numeric = CreateObject("roRegex", "^[0-9]+$", "")
    if not numeric.isMatch(textValue(item.id)) or (item.kind <> "movie" and item.kind <> "series")
        publishDescription(result)
        return
    end if
    root = m.base + "/api/vod/" + vodKindPath(item.kind) + "/" + item.id
    m.maxResponseBytes = 8388608
    rows = apiRows(requestJson(root + "/providers/"))
    m.maxResponseBytes = 1048576
    description = providerEnglishDescription(rows)
    if description = "" and item.kind = "movie" and rows <> invalid
        seen = {}
        if textValue(item.providerId) <> "" then seen[item.providerId] = true
        attempts = 0
        for each row in rows
            if attempts >= 2 or m.top.cancelRequested then exit for
            if type(row) = "roAssociativeArray" and type(row.m3u_account) = "roAssociativeArray"
                provider = textValue(row.m3u_account.id)
                relation = textValue(row.id)
                if numeric.isMatch(provider) and numeric.isMatch(relation) and not seen.doesExist(provider)
                    seen[provider] = true
                    attempts++
                    info = requestJson(root + "/provider-info/?relation_id=" + relation)
                    if type(info) = "roAssociativeArray"
                        for each field in ["description", "plot"]
                            candidate = left(textValue(info[field]), 2000)
                            if descriptionLanguage(candidate) = "en" then description = candidate
                        end for
                    end if
                    if description <> "" then exit for
                end if
            end if
        end for
    end if
    if description <> ""
        metadataCacheWrite(scope, "vod", key, generation, now, {description: description})
        result = {ok: true, key: item.key, description: description}
    end if
    publishDescription(result)
end sub

sub publishDescription(result as object)
    m.key = ""
    m.top.apiKey = ""
    m.top.item = invalid
    if m.top.cancelRequested then return
    m.top.result = result
end sub
