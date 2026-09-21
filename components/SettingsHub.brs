sub init()
    m.list = m.top.findNode("list")
    m.heading = m.top.findNode("heading")
    m.note = m.top.findNode("note")
    m.list.observeField("itemSelected", "onSettingSelected")
    m.page = ""
    m.stack = []
    m.choice = invalid
    m.top.visible = false
end sub

sub onActive()
    m.top.visible = m.top.active
    if not m.top.active then return
    m.page = ""
    m.stack = []
    m.choice = invalid
    renderSettings()
    m.list.setFocus(true)
end sub

sub renderSettings()
    if m.top.model = invalid then return
    focused = m.list.itemFocused
    model = m.top.model
    if m.choice <> invalid
        currentValue = settingsHubValue(model, m.choice.scope, m.choice.key)
        if not settingsHubChangeAllowed(model, m.choice.scope, m.choice.key, currentValue)
            m.choice = invalid
            if m.stack.count() > 0
                previous = m.stack.pop()
                m.page = previous.page
                focused = previous.index
            end if
        end if
    end if
    m.heading.text = "Settings"
    titles = {live: "Live TV", player: "Player", appearance: "Appearance", general: "General", connection: "Connection"}
    if titles.doesExist(m.page) then m.heading.text += " / " + titles[m.page]
    m.note.text = "Changes are saved on this Roku. Back returns to the previous page without moving the guide."
    if m.page = "player" then m.note.text = "Archive skip supports whole-minute provider windows. Audio compatibility changes take effect on the next tune."
    m.items = []
    if m.choice <> invalid
        m.heading.text = m.choice.title
        if m.choice.key = "vodTmdbEnabled" then m.note.text = "Uses the key saved in Guide options > Guide settings > Optional TMDB artwork fallback. Optional: playback does not depend on TMDB."
        current = settingsHubValue(model, m.choice.scope, m.choice.key)
        for each value in m.choice.values
            title = settingsValueText(value, m.choice.key)
            if value = current then title = "[Selected] " + title
            m.items.push({title: title, value: value})
        end for
    else
        m.items = settingsHubEntries(m.page, model)
    end if
    content = CreateObject("roSGNode", "ContentNode")
    for each item in m.items
        label = item.title
        if item.key <> invalid then label += ": " + settingsValueText(settingsHubValue(model, item.scope, item.key), item.key)
        content.createChild("ContentNode").title = label
    end for
    m.list.content = content
    if focused >= 0 and focused < m.items.count() then m.list.jumpToItem = focused
end sub

sub onSettingSelected(event as object)
    if not m.top.active or not m.list.isSameNode(event.getRoSGNode()) then return
    selectSetting(event.getData())
end sub

sub selectSetting(index as integer)
    if not m.top.active then return
    if index < 0 or index >= m.items.count() then return
    item = m.items[index]
    if m.choice <> invalid
        choice = m.choice
        m.top.selection = {account: m.top.model.account, scope: choice.scope, key: choice.key, value: item.value}
        goBackSettings()
    else if item.action = "connection"
        m.top.selection = {account: m.top.model.account, action: "connection"}
    else
        m.stack.push({page: m.page, index: index})
        if item.page <> invalid then m.page = item.page else m.choice = item
        renderSettings()
        m.list.jumpToItem = 0
    end if
end sub

sub goBackSettings()
    if m.stack.count() = 0
        m.top.closed = true
        return
    end if
    previous = m.stack.pop()
    m.page = previous.page
    m.choice = invalid
    renderSettings()
    m.list.jumpToItem = previous.index
    m.list.setFocus(true)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    return handleSettingsKey(key, press)
end function

function handleSettingsKey(key as string, press as boolean) as boolean
    if not m.top.active then return false
    if press and key = "back"
        goBackSettings()
        return true
    end if
    return false
end function
