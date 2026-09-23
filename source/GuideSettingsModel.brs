function normalizeGuideSettings(raw as dynamic) as object
    p = {}
    if type(raw) = "roAssociativeArray"
        ' ParseJson uses case-sensitive maps on device. Normalize schema keys
        ' into a fresh case-insensitive map; preserve nested ID/value data.
        for each key in raw
            p[lcase(key)] = copyGuideValue(raw[key])
        end for
        ' Recover a previous dynamic camel-case selection over an older default.
        for each key in ["groupSort", "channelSort", "groupLayout", "startupGroup", "collectionsPosition", "historyDays", "futureDays", "hiddenGroups", "groupOrder", "favoriteOrder", "categoryColors", "categoryRules", "tmdbFallback"]
            if raw.doesExist(key) then p[lcase(key)] = copyGuideValue(raw[key])
        end for
    end if
    for each field in ["groupSort", "channelSort", "groupLayout", "startupGroup", "collectionsPosition"]
        p[field] = textValue(p[field])
    end for
    p.historyDays = textValue(p.historyDays).toInt()
    p.futureDays = textValue(p.futureDays).toInt()
    if p.groupSort <> "alpha" and p.groupSort <> "manual" then p.groupSort = "default"
    if p.channelSort <> "name" and p.channelSort <> "id" then p.channelSort = "number"
    if p.groupLayout <> "pills" and p.groupLayout <> "sidebar" then p.groupLayout = "modal"
    if textValue(p.startupGroup) = "" then p.startupGroup = "all"
    p.hiddenGroups = compactIds(p.hiddenGroups, 300)
    p.groupOrder = compactIds(p.groupOrder, 300)
    p.favoriteOrder = compactIds(p.favoriteOrder, 2000)
    if p.collectionsPosition <> "last" then p.collectionsPosition = "first"
    if p.historyDays <> 1 and p.historyDays <> 3 and p.historyDays <> 7 and p.historyDays <> 14 and p.historyDays <> 30 then p.historyDays = 3
    if p.futureDays <> 1 and p.futureDays <> 3 and p.futureDays <> 7 and p.futureDays <> 14 and p.futureDays <> 30 then p.futureDays = 7
    if type(p.badges) <> "roAssociativeArray" then p.badges = {}
    for each key in ["new", "live", "premiere", "finale", "episode"]
        if type(p.badges[key]) <> "Boolean" and type(p.badges[key]) <> "roBoolean" then p.badges[key] = true
    end for
    if type(p.categoryColors) <> "Boolean" and type(p.categoryColors) <> "roBoolean" then p.categoryColors = true
    if type(p.tmdbFallback) <> "Boolean" and type(p.tmdbFallback) <> "roBoolean" then p.tmdbFallback = false
    if type(p.palette) <> "roAssociativeArray" then p.palette = {}
    if type(p.categoryRules) <> "roAssociativeArray" then p.categoryRules = {}
    if p.guideDensity <> "preview" and p.guideDensity <> "basic" then p.guideDensity = "preview"
    if type(p.showLogos) <> "Boolean" and type(p.showLogos) <> "roBoolean" then p.showLogos = true
    if type(p.showNumbers) <> "Boolean" and type(p.showNumbers) <> "roBoolean" then p.showNumbers = true
    if type(p.showNames) <> "Boolean" and type(p.showNames) <> "roBoolean" then p.showNames = true
    if type(p.showSubtitles) <> "Boolean" and type(p.showSubtitles) <> "roBoolean" then p.showSubtitles = true
    return p
end function

function guidePresentationGeometry(density as string) as object
    if density = "basic" then return {basic: true, rowHeight: 64, rowCount: 10, tileHeight: 60, titleY: 3, titleHeight: 27, timeY: 32, timeHeight: 24, badgeY: 34}
    return {basic: false, rowHeight: 96, rowCount: 7, tileHeight: 95, titleY: 14, titleHeight: 37, timeY: 55, timeHeight: 29, badgeY: 57}
end function

function copyGuideValue(value as dynamic) as dynamic
    if type(value) = "roAssociativeArray" or type(value) = "roArray" then return copyJson(value)
    return value
end function

function orderGuideIds(preferred as object, available as object) as object
    result = []
    seen = {}
    allowed = {}
    for each id in available
        allowed[id] = true
    end for
    all = []
    all.append(preferred)
    all.append(available)
    for each id in all
        if allowed.doesExist(id) and not seen.doesExist(id)
            result.push(id)
            seen[id] = true
        end if
    end for
    return result
end function

function organizedGroups(server as object, collections as object, settings as object, includeHidden = false as boolean, channels = invalid as dynamic) as object
    groups = [{id: "all", name: "All Channels"}, {id: "favorites", name: "Favorites"}, {id: "recent", name: "Recently Watched"}]
    extras = []
    for each c in collections
        extras.push({id: "collection:" + c.id, name: c.name})
    end for
    if settings.collectionsPosition = "first" then groups.append(extras)
    orderedServer = server
    if settings.groupSort = "default" and type(channels) = "roArray" then orderedServer = channelOrderedGroups(server, channels)
    for each g in orderedServer
        groups.push({id: "group:" + g.id, name: g.name})
    end for
    if settings.collectionsPosition = "last" then groups.append(extras)
    if settings.groupSort = "alpha"
        for each g in groups
            g.sortName = lcase(g.name) + "|" + g.id
        end for
        groups.sortBy("sortName")
    end if
    ids = []
    byId = {}
    hidden = {}
    for each id in settings.hiddenGroups
        hidden[id] = true
    end for
    for each g in groups
        ids.push(g.id)
        byId[g.id] = g
    end for
    if settings.groupSort = "manual" then ids = orderGuideIds(settings.groupOrder, ids)
    normalIds = []
    collectionIds = []
    for each id in ids
        if left(id, 11) <> "collection:" then normalIds.push(id)
    end for
    for each c in collections
        collectionIds.push("collection:" + c.id)
    end for
    ids = []
    if settings.collectionsPosition = "first" then ids.append(collectionIds)
    ids.append(normalIds)
    if settings.collectionsPosition = "last" then ids.append(collectionIds)
    result = []
    for each id in ids
        if includeHidden or not hidden.doesExist(id) then result.push(byId[id])
    end for
    if result.count() = 0 then result.push({id: "all", name: "All Channels"})
    return result
end function

function channelOrderedGroups(groups as object, channels as object) as object
    minima = {}
    numeric = CreateObject("roRegex", "^[0-9]+([.][0-9]+)?$", "")
    for each channel in channels
        number = textValue(channel.number).trim()
        if numeric.isMatch(number)
            key = channelNumberSortKey(number)
            id = textValue(channel.groupId)
            if not minima.doesExist(id)
                minima[id] = key
            else if key < minima[id]
                minima[id] = key
            end if
        end if
    end for
    rows = []
    for each group in groups
        key = "1|"
        id = textValue(group.id)
        if minima.doesExist(id) then key = "0|" + minima[id] + "|"
        rows.push({group: group, sortKey: key + lcase(group.name) + "|" + id})
    end for
    rows.sortBy("sortKey")
    result = []
    for each row in rows
        result.push(row.group)
    end for
    return result
end function

function guideHoldStep(elapsedMs as integer) as integer
    if elapsedMs >= 3000 then return 7
    if elapsedMs >= 1500 then return 3
    return 1
end function

function organizedChannels(channels as object, group as string, favorites as object, recent as object, collections as object, settings as object, query as string) as object
    if query <> "" then group = "all"
    rows = playerBrowserChannels(channels, group, favorites, recent, collections)
    if group = "favorites" and settings.favoriteOrder.count() > 0
        ids = []
        index = {}
        for each channel in rows
            ids.push(channel.id)
            index[channel.id] = channel
            index[channel.uuid] = channel
        end for
        preferred = []
        for each id in settings.favoriteOrder
            if index.doesExist(id) then preferred.push(index[id].id)
        end for
        ordered = []
        for each id in orderGuideIds(preferred, ids)
            ordered.push(index[id])
        end for
        rows = ordered
    else if group <> "recent" and left(group, 11) <> "collection:"
        wrapped = []
        for i = 0 to rows.count() - 1
            key = lcase(rows[i].name)
            if settings.channelSort = "number" then key = channelNumberSortKey(rows[i].number)
            if settings.channelSort = "id" then key = right("0000000000" + rows[i].id, 10)
            wrapped.push({channel: rows[i], sortName: key + "|" + right("000000" + i.toStr(), 6)})
        end for
        wrapped.sortBy("sortName")
        rows = []
        for each row in wrapped
            rows.push(row.channel)
        end for
    end if
    result = []
    for each channel in rows
        if query = "" or instr(1, lcase(channel.name + " " + channel.number), lcase(query)) > 0 then result.push(channel)
    end for
    return result
end function

function normalizeCollections(raw as dynamic) as object
    result = []
    if type(raw) <> "roArray" then return result
    seen = {}
    for each c in raw
        if type(c) = "roAssociativeArray"
            id = textValue(c.id)
            name = left(textValue(c.name).trim(), 50)
            if id <> "" and name <> "" and not seen.doesExist(id) and result.count() < 20
                result.push({id: left(id, 64), name: name, channels: compactIds(c.channels, 1500)})
                seen[id] = true
            end if
        end if
    end for
    return result
end function

function guideTimeClamp(epoch as integer, now as integer, settings as object) as integer
    low = now - settings.historyDays * 86400
    high = now + settings.futureDays * 86400 - 1
    if epoch < low then return low
    if epoch > high then return high
    return epoch
end function

function channelNumberIndex(channels as object, number as string) as integer
    numeric = CreateObject("roRegex", "^[0-9]+(\.[0-9]+)?$", "")
    if not numeric.isMatch(number.trim()) then return -1
    for i = 0 to channels.count() - 1
        if numeric.isMatch(channels[i].number)
            if channelNumberSortKey(channels[i].number) = channelNumberSortKey(number.trim()) then return i
        end if
    end for
    return -1
end function

function channelNumberSortKey(number as string) as string
    parts = CreateObject("roRegex", "^([0-9]+)(\.([0-9]+))?$", "").match(number.trim())
    if parts.count() = 0 then return "z" + number
    whole = parts[1]
    while len(whole) > 1 and left(whole, 1) = "0"
        whole = mid(whole, 2)
    end while
    fraction = ""
    if parts.count() > 3 then fraction = textValue(parts[3])
    return right("0000000000" + whole, 10) + "." + left(fraction + "0000000000", 10)
end function
