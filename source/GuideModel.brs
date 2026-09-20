' All guide times are UTC epoch seconds. Local time is a presentation concern.
function guideDictionary() as object
    result = {}
    result.setModeCaseSensitive()
    return result
end function

function guideEpoch(value as dynamic) as dynamic
    if value = invalid then return invalid
    if GetInterface(value, "ifString") = invalid
        if GetInterface(value, "ifInt") <> invalid then return value
        if GetInterface(value, "ifFloat") <> invalid then return int(value)
        return invalid
    end if
    pattern = CreateObject("roRegex", "^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(\.\d+)?(Z|[+-]\d{2}:\d{2})$", "")
    parts = pattern.match(value)
    if parts.count() = 0 then return invalid
    date = CreateObject("roDateTime")
    date.fromISO8601String(parts[1] + "Z")
    if left(date.toISOString(), 19) <> parts[1] then return invalid
    seconds = date.asSeconds()
    zone = parts[3]
    if zone <> "Z"
        hours = val(mid(zone, 2, 2))
        minutes = val(right(zone, 2))
        if hours > 23 or minutes > 59 then return invalid
        offset = hours * 3600 + minutes * 60
        if left(zone, 1) = "+" then seconds -= offset else seconds += offset
    end if
    return seconds
end function

function normalizeProgram(raw as dynamic) as dynamic
    if type(raw) <> "roAssociativeArray" then return invalid
    startsAt = guideEpoch(raw.start_time)
    endsAt = guideEpoch(raw.end_time)
    if startsAt = invalid or endsAt = invalid then return invalid
    if endsAt <= startsAt then return invalid
    title = textValue(raw.title)
    if title = "" then title = "Untitled program"
    result = {
        id: textValue(raw.id), title: left(title, 256)
        description: left(textValue(raw.description), 1500)
        subtitle: left(textValue(raw.sub_title), 256)
        startsAt: startsAt, endsAt: endsAt, key: textValue(raw.tvg_id)
    }
    cp = raw.custom_properties
    if type(cp) <> "roAssociativeArray" then cp = {}
    for each field in ["is_new", "is_live", "is_premiere", "is_finale", "is_previously_shown"]
        result[field] = invalid
        if type(raw[field]) = "Boolean" or type(raw[field]) = "roBoolean" then result[field] = raw[field]
    end for
    result.season = textValue(raw.season)
    result.episode = textValue(raw.episode)
    categories = raw.categories
    if categories = invalid then categories = cp.categories
    result.categories = programTextList(categories, 12)
    result.rating = left(textValue(raw.rating), 40)
    result.year = left(textValue(raw.production_date), 10)
    result.language = left(textValue(raw.language), 40)
    result.country = left(textValue(raw.country), 60)
    result.quality = left(textValue(raw.video_quality), 40)
    result.poster = textValue(raw.poster_url)
    if result.poster = "" then result.poster = textValue(raw.icon)
    if result.poster = "" then result.poster = textValue(cp.icon)
    result.credits = ""
    if type(raw.credits) = "roAssociativeArray"
        actors = programTextList(raw.credits.actors, 8)
        for each actor in actors
            if result.credits <> "" then result.credits += ", "
            result.credits += actor
        end for
    end if
    return result
end function

function programTextList(raw as dynamic, limit as integer) as object
    result = []
    if type(raw) <> "roArray" then return result
    for each item in raw
        text = textValue(item)
        if type(item) = "roAssociativeArray" then text = textValue(item.name)
        if text <> "" then result.push(left(text, 80))
        if result.count() >= limit then exit for
    end for
    return result
end function

function mergeProgramFacts(base as object, details as object) as object
    result = {}
    result.append(base)
    for each field in details
        lower = lcase(field)
        if lower <> "id" and lower <> "startsat" and lower <> "endsat" and lower <> "key" then result[field] = details[field]
    end for
    return result
end function

function programBadges(program as object, settings as object) as string
    result = ""
    for each badge in ["new", "live", "premiere", "finale"]
        if settings.badges[badge] and program["is_" + badge] = true then result += ucase(badge) + " "
    end for
    if settings.badges.episode
        if textValue(program.season) <> "" then result += "S" + program.season
        if textValue(program.episode) <> "" then result += "E" + program.episode
    end if
    return result.trim()
end function

function programCategory(program as object, settings = invalid as dynamic) as string
    text = ""
    if type(program.categories) = "roArray"
        for each category in program.categories
            text += lcase(category) + " "
        end for
    end if
    rules = [{bucket: "kids", words: ["kids", "children", "jeunesse"]}, {bucket: "sports", words: ["sport", "football", "soccer", "baseball"]}, {bucket: "news", words: ["news", "noticias"]}, {bucket: "movie", words: ["movie", "film"]}, {bucket: "documentary", words: ["documentary"]}, {bucket: "drama", words: ["drama"]}, {bucket: "comedy", words: ["comedy"]}, {bucket: "reality", words: ["reality"]}, {bucket: "educational", words: ["educational"]}, {bucket: "scifi", words: ["sci-fi", "science fiction", "fantasy"]}, {bucket: "music", words: ["music"]}]
    for each rule in rules
        if type(settings) = "roAssociativeArray"
            if type(settings.categoryRules) = "roAssociativeArray"
                custom = settings.categoryRules[rule.bucket]
                if type(custom) = "roArray" then rule.words = programTextList(custom, 12)
            end if
        end if
        for each word in rule.words
            if instr(1, text, word) > 0 then return rule.bucket
        end for
    end for
    return ""
end function

function programTint(program as object, settings as object) as string
    if not settings.categoryColors then return "0x0D1E35FF"
    bucket = programCategory(program, settings)
    defaults = {kids: "039BE5", sports: "3949AB", news: "43A047", movie: "5E35B1", documentary: "6D4C41", drama: "C62828", comedy: "F9A825", reality: "EC407A", educational: "00897B", scifi: "00838F", music: "D81B60"}
    if not defaults.doesExist(bucket) then return "0x0D1E35FF"
    color = defaults[bucket]
    if settings.palette.doesExist(bucket)
        custom = textValue(settings.palette[bucket])
        if CreateObject("roRegex", "^[0-9a-f]{6}$", "i").isMatch(custom) then color = custom
    end if
    return "0x" + color + "55"
end function

function guideClamp(value as integer, now as integer) as integer
    if value < now - 259200 then return now - 259200
    if value >= now + 604800 then return now + 604799
    return value
end function

function guideWindowStart(value as integer) as integer
    ' Integer division avoids float32 rounding at modern epoch magnitudes on Roku.
    return (value \ 10800) * 10800
end function

function guideNavigate(anchor as integer, cell as dynamic, direction as integer, now as integer) as integer
    if cell = invalid then return guideClamp(anchor, now)
    if direction < 0 then return guideClamp(cell.startsAt - 1, now)
    return guideClamp(cell.endsAt, now)
end function

function guideChannelKey(channel as object, index as object) as string
    if index.doesExist(channel.uuid) then return channel.uuid
    return channel.epgKey
end function

' Produce complete, disjoint focus regions. Gaps have no invented program data.
function guideCells(programs as object, startsAt as integer, endsAt as integer) as object
    sorted = []
    sorted.append(programs)
    sorted.sortBy("startsAt")
    cells = []
    cursor = startsAt
    for each program in sorted
        if program.endsAt > cursor and program.startsAt < endsAt
            start = program.startsAt
            if start < cursor then start = cursor
            finish = program.endsAt
            if finish > endsAt then finish = endsAt
            if start > cursor then cells.push({startsAt: cursor, endsAt: start, program: invalid})
            cells.push({startsAt: start, endsAt: finish, program: program})
            cursor = finish
        end if
    end for
    if cursor < endsAt then cells.push({startsAt: cursor, endsAt: endsAt, program: invalid})
    return cells
end function

function guideCellAt(cells as object, anchor as integer) as dynamic
    for each cell in cells
        if cell.startsAt <= anchor and cell.endsAt > anchor then return cell
    end for
    return invalid
end function

function guideNewCache() as object
    return {entries: {}, order: [], limit: 3}
end function

sub guideCacheTouch(cache as object, start as integer)
    key = start.toStr()
    order = []
    for each old in cache.order
        if old <> key then order.push(old)
    end for
    order.push(key)
    cache.order = order
end sub

sub guideCachePut(cache as object, start as integer, index as object, now as integer, ttl = 300 as integer)
    key = start.toStr()
    cache.entries[key] = {index: index, fetchedAt: now, expiresAt: now + ttl, staleUntil: now + ttl + 600}
    guideCacheTouch(cache, start)
    while cache.order.count() > cache.limit
        oldest = cache.order.shift()
        cache.entries.delete(oldest)
    end while
end sub

sub guideCachePrune(cache as object, now as integer)
    retained = []
    for each key in cache.order
        entry = cache.entries[key]
        expired = false
        if entry.staleUntil <> invalid then expired = now >= entry.staleUntil
        if entry.fetchedAt <> invalid
            if entry.fetchedAt > now then expired = true
        end if
        if expired then cache.entries.delete(key) else retained.push(key)
    end for
    cache.order = retained
end sub

function guideCacheHas(cache as object, start as integer, now as integer) as boolean
    key = start.toStr()
    if not cache.entries.doesExist(key) then return false
    return cache.entries[key].expiresAt > now
end function

function guideCachePrograms(cache as object, key as string, startsAt as integer, endsAt as integer) as object
    result = []
    seen = guideDictionary()
    for each window in cache.entries
        index = cache.entries[window].index
        if index.doesExist(key)
            for each program in index[key]
                if program.endsAt > startsAt and program.startsAt < endsAt
                    identity = program.id + ":" + program.startsAt.toStr() + ":" + program.endsAt.toStr()
                    if not seen.doesExist(identity)
                        result.push(program)
                        seen[identity] = true
                    end if
                end if
            end for
        end if
    end for
    return result
end function
