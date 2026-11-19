function normalizeGuideSettings(raw as dynamic) as object
    p = {}
    if type(raw) = "roAssociativeArray"
        ' ParseJson uses case-sensitive maps on device. Normalize schema keys
        ' into a fresh case-insensitive map; preserve nested ID/value data.
        for each key in raw
            p[lcase(key)] = copyGuideValue(raw[key])
        end for
        ' Recover a previous dynamic camel-case selection over an older default.
        for each key in ["groupSort", "channelSort", "groupLayout", "startupGroup", "collectionsPosition", "historyDays", "futureDays", "hiddenGroups", "groupOrder", "favoriteOrder", "tmdbFallback"]
            if raw.doesExist(key) then p[lcase(key)] = copyGuideValue(raw[key])
        end for
    end if
    ' Drop retired category-color fields on read so old account preferences
    ' cannot restore the feature or keep obsolete rules in the registry.
    p.delete("categorycolors")
    p.delete("categoryrules")
    p.delete("palette")
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
    if (p.historyDays < 1 or p.historyDays > 14) and p.historyDays <> 30 then p.historyDays = 3
    if (p.futureDays < 1 or p.futureDays > 14) and p.futureDays <> 30 then p.futureDays = 7
    if type(p.badges) <> "roAssociativeArray" then p.badges = {}
    for each key in ["new", "live", "premiere", "finale", "episode"]
        if type(p.badges[key]) <> "Boolean" and type(p.badges[key]) <> "roBoolean" then p.badges[key] = true
    end for
    if type(p.tmdbFallback) <> "Boolean" and type(p.tmdbFallback) <> "roBoolean" then p.tmdbFallback = false
    if p.guideDensity <> "preview" and p.guideDensity <> "basic" then p.guideDensity = "preview"
    p.guideDisplayScale = normalizeGuideDisplayScale(p.guideDisplayScale)
    if type(p.showLogos) <> "Boolean" and type(p.showLogos) <> "roBoolean" then p.showLogos = true
    if type(p.showNumbers) <> "Boolean" and type(p.showNumbers) <> "roBoolean" then p.showNumbers = true
    if type(p.showNames) <> "Boolean" and type(p.showNames) <> "roBoolean" then p.showNames = true
    if type(p.showSubtitles) <> "Boolean" and type(p.showSubtitles) <> "roBoolean" then p.showSubtitles = true
    p.channelLogoSize = normalizeChannelLogoSize(p.channelLogoSize)
    for each field in ["roundedGuideLogos", "roundedProgramCells"]
        if type(p[field]) <> "Boolean" and type(p[field]) <> "roBoolean" then p[field] = false
    end for
    return p
end function

function normalizeGuideDisplayScale(value as dynamic) as integer
    kind = type(value)
    if kind <> "Integer" and kind <> "roInt" and kind <> "roInteger" and kind <> "LongInteger" and kind <> "roLongInteger" and kind <> "Float" and kind <> "roFloat" and kind <> "Double" and kind <> "roDouble" then return 100
    for each choice in [90, 100, 110, 120]
        if value = choice then return choice
    end for
    return 100
end function

function guideScalePixels(pixels as integer, scale as integer) as integer
    return int(pixels * scale / 100.0 + 0.5)
end function

function guideChannelGeometry(row as object, settings as object) as object
    stockWidth = 58
    stockHeight = 58
    logoY = 40
    maxWidth = 98
    maxHeight = row.tileHeight - 8
    nameY = 40
    nameHeight = 62
    nameLines = 2
    if row.basic
        stockWidth = 32
        stockHeight = 30
        logoY = 27
        maxWidth = 66
        nameY = 26
        nameHeight = 32
        nameLines = 1
    end if
    indicatorY = guideScalePixels(4, row.scale)
    indicatorHeight = guideScalePixels(27, row.scale)
    indicatorBottom = indicatorY + indicatorHeight
    logoY = guideScalePixels(logoY, row.scale)
    stockWidth = guideScalePixels(stockWidth, row.scale)
    stockHeight = guideScalePixels(stockHeight, row.scale)
    nameY = guideScalePixels(nameY, row.scale)
    nameHeight = guideScalePixels(nameHeight, row.scale)
    ' Keep the indicator lane reserved even when the number is hidden.
    if (not settings.showNumbers or row.scale <> 100) and nameY < indicatorBottom then nameY = indicatorBottom
    if nameY + nameHeight > row.tileHeight then nameHeight = row.tileHeight - nameY
    layout = {textX: 12, numberX: 12, numberWidth: 170, nameY: nameY, nameHeight: nameHeight, nameLines: nameLines, indicatorY: indicatorY, indicatorHeight: indicatorHeight}
    if settings.showLogos
        layout.logo = boundedChannelLogo(12, row.tileHeight, settings.channelLogoSize, stockWidth, stockHeight, maxWidth, maxHeight)
        if settings.channelLogoSize <= 100
            layout.logo.y = logoY
            if logoY + layout.logo.h > row.tileHeight then layout.logo.y = row.tileHeight - layout.logo.h
        end if
        layout.textX = layout.logo.x + layout.logo.w + 10
        if settings.channelLogoSize > 100 and layout.logo.y < indicatorBottom
            layout.numberX = layout.textX
            layout.numberWidth = 182 - layout.numberX
        end if
    end if
    layout.nameWidth = 230 - layout.textX
    if settings.showLogos and settings.channelLogoSize = 100 and row.scale = 100 then layout.nameWidth = 150
    return layout
end function

function browserChannelGeometry(size as integer, showLogo as boolean) as object
    if not showLogo then return {textX: 10}
    logo = boundedChannelLogo(10, 84, size, 76, 54, 112, 72)
    if size = 100 then logo.y = 14
    return {logo: logo, textX: logo.x + logo.w + 19}
end function

function boundedChannelLogo(x as integer, rowHeight as integer, size as integer, stockWidth as integer, stockHeight as integer, maxWidth as integer, maxHeight as integer) as object
    w = int(stockWidth * size / 100.0 + 0.5)
    h = int(stockHeight * size / 100.0 + 0.5)
    if w > maxWidth then w = maxWidth
    if h > maxHeight then h = maxHeight
    return {x: x, y: int((rowHeight - h) / 2), w: w, h: h}
end function

function guideRowPoolSize() as integer
    ' The largest visible count is eleven Basic rows at 90%.
    return 11
end function

function guidePresentationGeometry(density as string, showSubtitles = true as boolean, rawScale = 100 as dynamic) as object
    scale = normalizeGuideDisplayScale(rawScale)
    if density = "basic"
        row = {basic: true, rowHeight: 64, tileHeight: 60, titleY: 3, titleHeight: 27, timeY: 32, timeHeight: 24, badgeY: 34}
        viewport = 640
    else
        ' Both Preview modes occupy the same 672px guide viewport.
        row = {basic: false, rowHeight: 96, tileHeight: 95, titleY: 14, titleHeight: 37, timeY: 55, timeHeight: 29, badgeY: 57}
        if showSubtitles
            row = {basic: false, rowHeight: 112, tileHeight: 111, titleY: 14, titleHeight: 37, timeY: 74, timeHeight: 25, badgeY: 75, withSubtitle: {titleY: 8, titleHeight: 31, subtitleY: 43, subtitleHeight: 27, timeY: 78, timeHeight: 23, badgeY: 77}}
        end if
        viewport = 672
    end if
    for each field in ["rowHeight", "tileHeight", "titleY", "titleHeight", "timeY", "timeHeight", "badgeY"]
        row[field] = guideScalePixels(row[field], scale)
    end for
    if row.tileHeight >= row.rowHeight then row.tileHeight = row.rowHeight - 1
    if row.withSubtitle <> invalid
        for each field in row.withSubtitle
            row.withSubtitle[field] = guideScalePixels(row.withSubtitle[field], scale)
        end for
    end if
    row.badgeHeight = guideScalePixels(24, scale)
    row.scale = scale
    row.rowCount = viewport \ row.rowHeight
    return row
end function

function copyGuideValue(value as dynamic) as dynamic
    if type(value) = "roAssociativeArray" or type(value) = "roArray" then return copyPreferenceValue(value)
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

function guideProfileActionAllowed(role as dynamic, action as dynamic) as boolean
    if role = invalid then return true ' Legacy/direct-provider configuration.
    if type(role) <> "String" and type(role) <> "roString" then return false
    if role = "user" or role = "admin" then return true
    if role <> "child" then return false
    if type(action) <> "String" and type(action) <> "roString" then return false
    for each blocked in ["groups", "groupList", "manageGroups", "groupEdit", "startup", "collections", "collectionEdit", "collectionMembers", "collectionName", "guideSettings", "settingValue", "navigationLayout", "settings", "toggleVod", "diagnostics", "clock", "tmdb", "tmdbKey", "badges", "sourceMenu", "sourceConfirm", "source", "markRadio"]
        if action = blocked then return false
    end for
    return true
end function

function guideOptionItems(items as object, advanced as boolean) as object
    result = []
    if advanced then result.push({title: "Back to common actions", action: "mainOptions"})
    for each item in items
        action = textValue(item.action)
        common = action = "details" or action = "favorite" or action = "groups" or action = "search" or action = "programSearch" or action = "now" or action = "expandPlayer" or action = "stopPlayer" or action = "cancelPendingTune"
        if action = "recentHistory" then common = true
        if common <> advanced then result.push(item)
    end for
    if not advanced then result.push({title: "More guide actions", action: "moreOptions"})
    return result
end function

function organizedChannels(channels as object, group as string, favorites as object, recent as object, collections as object, settings as object, query as string) as object
    if query <> "" then group = "all"
    rows = playerBrowserChannels(channels, group, favorites, recent, collections)
    hidden = {}
    for each id in settings.hiddenGroups
        if left(id, 6) = "group:" then hidden[id] = true
    end for
    visible = []
    for each channel in rows
        if not hidden.doesExist("group:" + textValue(channel.groupId)) then visible.push(channel)
    end for
    rows = visible
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

function guideResumeAnchor(anchor as integer, followNow as boolean, now as integer, settings as object) as integer
    if followNow then return now
    return guideTimeClamp(anchor, now, settings)
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
