' Runs in GuideView's component scope.
sub handleOptionsShortcut()
    if not m.top.active then return
    cancelGuideHold()
    if m.searchView.active
        editProgramSearch()
    else if m.picker <> invalid
        closePicker()
        m.top.setFocus(true)
    else if not m.details.active
        m.navigator.active = false
        openOptions()
    end if
end sub

sub openNavigationLayout()
    m.settingField = "groupLayout"
    items = []
    for each choice in [{value: "modal", title: "Modal group list"}, {value: "pills", title: "Top group pills (always visible)"}, {value: "sidebar", title: "Docked group sidebar (always visible)"}]
        label = choice.title
        if m.settings.groupLayout = choice.value then label = "[Selected] " + label
        items.push({title: label, value: choice.value})
    end for
    openPicker("Group navigation layout", items, "settingValue")
end sub

sub refreshPresentation()
    if not m.ready then return
    if m.top.active then drawGuide()
    if m.details.active then updateRichDetails()
end sub

function applyHubGuideSetting(key as string, value as dynamic) as dynamic
    if not m.ready then return invalid
    if key <> "historyDays" and key <> "futureDays" and key <> "channelSort" and key <> "groupLayout" and key <> "categoryColors" then return invalid
    m.settings[lcase(key)] = value
    m.settings = normalizeGuideSettings(m.settings)
    m.anchor = guideTimeClamp(m.anchor, uiNow(), m.settings)
    keepAnchorVisible()
    m.navigator.active = false
    m.navigator.callFunc("applyPresentation", {groups: m.groups, layout: m.settings.groupLayout, selected: m.groups[m.groupIndex].id})
    rebuildGuideGroups()
    return m.settings
end function

sub onGroupPreview(event as object)
    for i = 0 to m.groups.count() - 1
        if m.groups[i].id = event.getData() then m.groupIndex = i
    end for
    filterLineup()
    savePreferences()
    drawGuide()
    scheduleLoad()
end sub

sub onNavigatorClosed()
    if m.top.active
        drawGuide()
        m.top.setFocus(true)
    end if
end sub
sub rebuildGuideGroups()
    old = m.groups[m.groupIndex].id
    m.groups = organizedGroups(m.serverGroups, m.collections, m.settings, false, m.channels)
    m.groupIndex = 0
    for i = 0 to m.groups.count() - 1
        if m.groups[i].id = old then m.groupIndex = i
    end for
    filterLineup()
    savePreferences()
    drawGuide()
    scheduleLoad()
end sub

sub updateHistory()
    if not m.ready then return
    m.recent = m.top.recentIds
    if m.groups[m.groupIndex].id = "recent"
        filterLineup()
        if m.top.active then drawGuide()
    end if
end sub

sub applyRefreshedLineup(data as object)
    suspendGuide()
    cancelMetadataLoads()
    m.global.cacheEpoch = CreateObject("roDeviceInfo").getRandomUUID()
    m.cacheScope = textValue(data.scope)
    m.lineupGeneration = textValue(data.generation)
    m.cacheGeneration = m.lineupGeneration
    m.metadataElapsed = CreateObject("roTimespan")
    m.metadataElapsed.mark()
    if type(data.preferences) = "roAssociativeArray"
        m.recent = data.preferences.recent
        m.reminders = data.preferences.reminders
    end if
    m.channels = data.channels
    m.serverGroups = data.groups
    m.connectionWarning = data.warning
    m.allowedKeys = guideDictionary()
    for each channel in m.channels
        m.allowedKeys[channel.uuid] = true
        if channel.epgKey <> "" then m.allowedKeys[channel.epgKey] = true
    end for
    m.cache = guideNewCache()
    m.failures = {}
    m.detailCache = {}
    m.detailOrder = []
    loadMappings(true)
    rebuildGuideGroups()
    if m.top.active then onActive()
    if m.top.playbackChannel <> invalid then onPlaybackChannel()
end sub

sub openGuideSetting(kind as string)
    items = []
    if kind = "guideSettings"
        items = [
            {title: "Group order: " + m.settings.groupSort, field: "groupSort", choices: ["default", "alpha", "manual"]}
            {title: "Channel sort: " + m.settings.channelSort, field: "channelSort", choices: ["number", "name", "id"]}
            {title: "Group navigation: " + m.settings.groupLayout, field: "groupLayout", choices: ["modal", "pills", "sidebar"]}
            {title: "Collections position: " + m.settings.collectionsPosition, field: "collectionsPosition", choices: ["first", "last"]}
            {title: "History days: " + m.settings.historyDays.toStr(), field: "historyDays", choices: [1, 3, 7, 14, 30]}
            {title: "Future days: " + m.settings.futureDays.toStr(), field: "futureDays", choices: [1, 3, 7, 14, 30]}
            {title: "All available (bounded to 30 days each way)", action: "allAvailable"}
            {title: "Startup group", action: "startup"}
            {title: "Badges", action: "badges"}
            {title: "Category colors", action: "colors"}
            {title: "Optional TMDB artwork fallback", action: "tmdb"}
        ]
    else if kind = "manageGroups" or kind = "startup"
        if kind = "startup" then items.push({title: "Last browsed group", groupId: "last"})
        hidden = {}
        for each id in m.settings.hiddenGroups
            hidden[id] = true
        end for
        for each g in organizedGroups(m.serverGroups, m.collections, m.settings, true, m.channels)
            title = g.name
            if hidden.doesExist(g.id) then title = "[Hidden] " + title
            items.push({title: title, groupId: g.id})
        end for
    else if kind = "collections"
        items.push({title: "Create collection", action: "newCollection"})
        for each c in m.collections
            items.push({title: c.name + " (" + c.channels.count().toStr() + ")", collectionId: c.id})
        end for
    else if kind = "reminders"
        for each reminder in m.reminders
            title = uiLocalDate(reminder.startsAt) + " " + uiTime(reminder.startsAt) + " " + reminder.title
            if reminder.unavailable = true then title = "[Schedule unavailable] " + title
            items.push({title: title, reminderId: reminder.id})
        end for
        if items.count() = 0 then items.push({title: "No saved reminders", action: "close"})
    else if kind = "favoriteOrder"
        for each c in organizedChannels(m.channels, "favorites", m.favorites, [], [], m.settings, "")
            items.push({title: c.number + " " + c.name, favoriteId: c.id})
        end for
        if items.count() = 0 then items.push({title: "No favorites yet", action: "close"})
    else if kind = "badges"
        for each key in ["new", "live", "premiere", "finale", "episode"]
            value = "Off"
            if m.settings.badges[key] then value = "On"
            items.push({title: key + ": " + value, badge: key})
        end for
    else if kind = "colors"
        label = "Enable category colors"
        if m.settings.categoryColors then label = "Disable category colors"
        items = [{title: label, action: "toggleColors"}, {title: "Reset category palette and rules", action: "resetColors"}, {title: "Edit category matching rules", action: "categoryRules"}]
        for each bucket in ["kids", "sports", "news", "movie", "documentary", "drama", "comedy", "reality", "educational", "scifi", "music"]
            items.push({title: bucket, bucket: bucket})
        end for
    else if kind = "categoryRules"
        for each bucket in ["kids", "sports", "news", "movie", "documentary", "drama", "comedy", "reality", "educational", "scifi", "music"]
            items.push({title: bucket, bucket: bucket})
        end for
    else if kind = "tmdb"
        label = "Enable optional TMDB fallback"
        if m.settings.tmdbFallback then label = "Disable optional TMDB fallback"
        items = [{title: label, action: "toggleTmdb"}, {title: "Test and save TMDB API key on this Roku", action: "tmdbKey"}, {title: "Forget TMDB API key", action: "forgetTmdb"}]
    end if
    titles = {guideSettings: "Guide settings", manageGroups: "Manage groups", startup: "Startup group", collections: "Collections", favoriteOrder: "Favorite order", badges: "Program badges", colors: "Category colors", categoryRules: "Category matching rules", tmdb: "Optional TMDB artwork", reminders: "Program reminders"}
    title = kind
    if titles.doesExist(kind) then title = titles[kind]
    openPicker(title, items, kind)
end sub

function handleGuideSetting(kind as string, item as object) as boolean
    if kind = "guideSettings"
        if item.field <> invalid
            if item.field = "groupLayout"
                openNavigationLayout()
                return true
            end if
            m.settingField = item.field
            items = []
            for each value in item.choices
                items.push({title: textValue(value), value: value})
            end for
            openPicker(item.title, items, "settingValue")
        else if item.action = "allAvailable"
            m.settings.historyDays = 30
            m.settings.futureDays = 30
            rebuildGuideGroups()
        else
            openGuideSetting(item.action)
        end if
    else if kind = "settingValue"
        m.settings[lcase(m.settingField)] = item.value
        if m.settingField = "groupLayout"
            ' A layout switch must replace the current presentation even when
            ' the old navigator still owns active state. Ordinary redraws avoid
            ' reconfiguring an active navigator to preserve its preview focus.
            m.navigator.active = false
            m.navigator.callFunc("applyPresentation", {groups: m.groups, layout: item.value, selected: m.groups[m.groupIndex].id})
        end if
        m.anchor = guideTimeClamp(m.anchor, uiNow(), m.settings)
        keepAnchorVisible()
        rebuildGuideGroups()
    else if kind = "startup"
        m.settings.startupGroup = item.groupId
        unhideStartupGroup()
        rebuildGuideGroups()
        savePreferences()
    else if kind = "manageGroups"
        m.editGroup = item.groupId
        openPicker(item.title, [{title: "Show / hide", action: "visibility"}, {title: "Move earlier", delta: -1}, {title: "Move later", delta: 1}, {title: "Use at startup", action: "default"}], "groupEdit")
    else if kind = "groupEdit"
        if item.action = "default"
            m.settings.startupGroup = m.editGroup
            unhideStartupGroup()
        else if item.action = "visibility"
            hidden = []
            wasHidden = false
            for each id in m.settings.hiddenGroups
                if id = m.editGroup then wasHidden = true else hidden.push(id)
            end for
            if not wasHidden and m.groups.count() > 1 then hidden.push(m.editGroup)
            m.settings.hiddenGroups = hidden
        else
            if left(m.editGroup, 11) = "collection:"
                for i = 0 to m.collections.count() - 1
                    target = i + item.delta
                    if "collection:" + m.collections[i].id = m.editGroup and target >= 0 and target < m.collections.count()
                        collection = m.collections[i]
                        m.collections[i] = m.collections[target]
                        m.collections[target] = collection
                        exit for
                    end if
                end for
            else
                ids = []
                for each g in organizedGroups(m.serverGroups, m.collections, m.settings, true, m.channels)
                    ids.push(g.id)
                end for
                m.settings.groupOrder = moveGuideId(ids, m.editGroup, item.delta)
                m.settings.groupSort = "manual"
            end if
        end if
        rebuildGuideGroups()
        openGuideSetting("manageGroups")
    else if kind = "reminders"
        if item.action = "close" then return true
        m.editReminder = item.reminderId
        openPicker(item.title, [{title: "Cancel reminder", action: "cancel"}, {title: "Keep reminder", action: "keep"}], "reminderEdit")
    else if kind = "reminderEdit"
        if item.action = "cancel"
            rows = []
            for each reminder in m.reminders
                if reminder.id <> m.editReminder then rows.push(reminder)
            end for
            m.reminders = rows
            savePreferences()
        end if
        openGuideSetting("reminders")
    else if kind = "collections"
        if item.action = "newCollection"
            m.editCollection = ""
            openGuideKeyboard("collectionName", "New collection name (up to 20 collections)", "")
        else
            m.editCollection = item.collectionId
            openPicker(item.title, [{title: "Add / remove selected channel", action: "membership"}, {title: "Rename", action: "rename"}, {title: "Reorder members", action: "members"}, {title: "Move collection earlier", action: "earlier"}, {title: "Move collection later", action: "later"}, {title: "Delete collection", action: "delete"}], "collectionEdit")
        end if
    else if kind = "collectionEdit"
        at = collectionIndex()
        if at < 0 then return true
        c = m.collections[at]
        if item.action = "rename"
            openGuideKeyboard("collectionName", "Rename collection", c.name)
            return true
        else if item.action = "delete"
            m.collections.delete(at)
        else if item.action = "membership"
            if m.filtered.count() > 0
                id = m.filtered[m.selected].id
                ids = []
                found = false
                for each member in c.channels
                    if member = id then found = true else ids.push(member)
                end for
                if not found then ids.push(id)
                m.collections[at].channels = ids
            end if
        else if item.action = "members"
            items = []
            for each id in c.channels
                channel = collectionChannel(id)
                if channel <> invalid then items.push({title: channel.name, memberId: id})
            end for
            if items.count() = 0 then items.push({title: "Empty collection", action: "close"})
            openPicker("Select member to move", items, "collectionMember")
            return true
        else
            nextAt = at - 1
            if item.action = "later" then nextAt = at + 1
            if nextAt >= 0 and nextAt < m.collections.count()
                m.collections[at] = m.collections[nextAt]
                m.collections[nextAt] = c
            end if
        end if
        rebuildGuideGroups()
        openGuideSetting("collections")
    else if kind = "collectionMember" or kind = "favoriteOrder"
        if item.action = "close" then return true
        m.editMember = item.memberId
        if kind = "favoriteOrder" then m.editMember = item.favoriteId
        m.memberKind = kind
        openPicker(item.title, [{title: "Move earlier", delta: -1}, {title: "Move later", delta: 1}], "memberMove")
    else if kind = "memberMove"
        if m.memberKind = "favoriteOrder"
            ids = []
            for each c in organizedChannels(m.channels, "favorites", m.favorites, [], [], m.settings, "")
                ids.push(c.id)
            end for
            m.settings.favoriteOrder = moveGuideId(ids, m.editMember, item.delta)
        else
            at = collectionIndex()
            if at >= 0 then m.collections[at].channels = moveGuideId(m.collections[at].channels, m.editMember, item.delta)
        end if
        rebuildGuideGroups()
    else if kind = "badges"
        m.settings.badges[item.badge] = not m.settings.badges[item.badge]
        savePreferences()
        drawGuide()
        openGuideSetting("badges")
    else if kind = "colors"
        if item.action = "toggleColors"
            m.settings.categoryColors = not m.settings.categoryColors
        else if item.action = "resetColors"
            m.settings.palette = {}
            m.settings.categoryRules = {}
        else if item.action = "categoryRules"
            openGuideSetting("categoryRules")
            return true
        else
            m.editBucket = item.bucket
            openPicker("Category tint", [{title: "Indigo", value: "3949AB"}, {title: "Purple", value: "5E35B1"}, {title: "Blue", value: "039BE5"}, {title: "Green", value: "43A047"}, {title: "Red", value: "C62828"}, {title: "Teal", value: "00897B"}], "colorValue")
            return true
        end if
        savePreferences()
        drawGuide()
    else if kind = "categoryRules"
        m.editBucket = item.bucket
        openGuideKeyboard("categoryWords", "Matching category words, comma-separated (blank resets)", "")
    else if kind = "tmdb"
        if item.action = "tmdbKey"
            openGuideKeyboard("tmdbKey", "TMDB API key — test and save in this Roku's registry", "")
            return true
        else if item.action = "forgetTmdb"
            m.tmdbKey = ""
            m.settings.tmdbFallback = false
            m.top.devicePreference = {tmdbKey: ""}
        else
            m.settings.tmdbFallback = not m.settings.tmdbFallback
        end if
        m.detailCache = {}
        m.detailOrder = []
        savePreferences()
    else if kind = "colorValue"
        m.settings.palette[m.editBucket] = item.value
        savePreferences()
        drawGuide()
    else
        return false
    end if
    return true
end function

sub unhideStartupGroup()
    visible = []
    for each id in m.settings.hiddenGroups
        if id <> m.settings.startupGroup then visible.push(id)
    end for
    m.settings.hiddenGroups = visible
end sub

function moveGuideId(ids as object, id as string, delta as integer) as object
    result = []
    result.append(ids)
    for i = 0 to result.count() - 1
        target = i + delta
        if result[i] = id and target >= 0 and target < result.count()
            result[i] = result[target]
            result[target] = id
            exit for
        end if
    end for
    return result
end function

function collectionIndex() as integer
    for i = 0 to m.collections.count() - 1
        if m.collections[i].id = m.editCollection then return i
    end for
    return -1
end function

sub openGuideKeyboard(kind as string, title as string, text as string)
    m.guideKeyboardKind = kind
    dialog = CreateObject("roSGNode", "KeyboardDialog")
    dialog.title = title
    dialog.text = text
    if kind = "tmdbKey" then dialog.keyboard.textEditBox.secureMode = true
    dialog.buttons = ["Save", "Cancel"]
    if kind = "number" then dialog.buttons = ["Go", "Cancel"]
    if kind = "tmdbKey" then dialog.buttons = ["Test and save", "Cancel"]
    dialog.observeField("buttonSelected", "onGuideKeyboard")
    dialog.observeField("wasClosed", "onDialogClosed")
    m.top.getScene().dialog = dialog
end sub

sub onGuideKeyboard(event as object)
    dialog = event.getRoSGNode()
    text = dialog.text.trim()
    if event.getData() = 0
        if m.guideKeyboardKind = "number"
            index = channelNumberIndex(m.filtered, text)
            if index >= 0
                m.selected = index
                m.message = ""
            else
                m.message = "No matching channel number in the current list."
            end if
        else if m.guideKeyboardKind = "categoryWords"
            words = []
            for each word in text.tokenize(",")
                word = lcase(word.trim())
                if word <> "" and words.count() < 12 then words.push(left(word, 50))
            end for
            if words.count() = 0 then m.settings.categoryRules.delete(m.editBucket) else m.settings.categoryRules[m.editBucket] = words
            savePreferences()
        else if m.guideKeyboardKind = "tmdbKey" and text <> ""
            m.tmdbTask = CreateObject("roSGNode", "TmdbKeyTask")
            m.tmdbTask.token = text
            m.tmdbTask.observeField("result", "onTmdbKeyTest")
            m.tmdbTask.control = "RUN"
            m.message = "Testing TMDB API key..."
        else if m.guideKeyboardKind = "collectionName" and text <> ""
            at = collectionIndex()
            if at >= 0
                m.collections[at].name = left(text, 50)
            else if m.collections.count() < 20
                m.collections.push({id: CreateObject("roDeviceInfo").getRandomUUID(), name: left(text, 50), channels: []})
            else
                m.message = "Collection limit reached (20). Delete a collection before adding another."
            end if
            rebuildGuideGroups()
        end if
        drawGuide()
        scheduleLoad()
    end if
    dialog.close = true
end sub

function collectionChannel(id as string) as dynamic
    for each channel in m.channels
        if channel.id = id or channel.uuid = id then return channel
    end for
    return invalid
end function

sub onTmdbKeyTest(event as object)
    if not isCurrentTaskEvent(event, m.tmdbTask) then return
    result = event.getData()
    m.tmdbTask.unobserveField("result")
    m.tmdbTask = invalid
    if result.ok
        m.tmdbKey = result.token
        m.top.devicePreference = {tmdbKey: result.token}
        m.settings.tmdbFallback = true
        m.message = "TMDB key verified. Optional artwork enabled. TMDB data is not endorsed or certified by TMDB."
        m.detailCache = {}
        m.detailOrder = []
        savePreferences()
    else
        m.message = "TMDB test failed. " + result.message
    end if
    drawGuide()
end sub
