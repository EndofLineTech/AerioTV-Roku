sub init()
    m.list = m.top.findNode("list")
    m.heading = m.top.findNode("heading")
    m.note = m.top.findNode("note")
    uiSetColor(m.top.findNode("background"), "0x0A1628FF")
    uiSetColor(m.top.findNode("detailSurface"), "0x0D1E35FF")
    uiSetColor(m.heading, "0xE8F3FAFF")
    uiSetColor(m.top.findNode("railTitle"), "0xE8F3FAFF")
    uiSetColor(m.note, "0x9EB5C9FF")
    uiSetColor(m.list, "0xE8F3FAFF")
    uiSetColor(m.list, "0xE8F3FAFF", "focusedColor")
    uiSetColor(m.list, "0x365163FF", "focusBitmapBlendColor")
    m.list.observeField("itemSelected", "onSettingSelected")
    m.page = ""
    m.stack = []
    m.choice = invalid
    m.top.visible = false
    buildSettingsRail()
    headingFont = m.heading.font
    headingFont.size = uiTypeSize("section")
    m.heading.font = headingFont
    noteFont = m.note.font
    noteFont.size = uiTypeSize("secondary")
    m.note.font = noteFont
    listFont = m.list.font
    listFont.size = uiTypeSize("body")
    m.list.font = listFont
    focusedFont = m.list.focusedFont
    focusedFont.size = uiTypeSize("body")
    m.list.focusedFont = focusedFont
    for each entry in [{id: "railTitle", role: "heading"}]
        label = m.top.findNode(entry.id)
        font = label.font
        font.size = uiTypeSize(entry.role)
        label.font = font
    end for
end sub

sub onActive()
    m.top.visible = m.top.active
    if not m.top.active then return
    m.page = "live"
    m.stack = []
    m.choice = invalid
    m.railSelected = 0
    renderSettings()
    focusSettingsRail()
end sub

sub renderSettings()
    if m.top.model = invalid then return
    focused = m.list.itemFocused
    model = m.top.model
    if m.choice <> invalid and m.choice.action <> "remoteSlot" and m.choice.action <> "resetRemoteMapConfirm" and m.choice.action <> "resetAppearanceConfirm"
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
    titles = {live: "Live TV", player: "Player", remote: "Remote control", remotePlayer: "While watching", remoteGuide: "In the TV Guide", appearance: "Appearance", general: "General", connection: "Connection", about: "About", whatsNew: "What's New", licenses: "License notices"}
    if titles.doesExist(m.page) then m.heading.text = titles[m.page]
    m.note.text = "Changes are saved on this Roku. Back returns to the previous page without moving the guide."
    if m.page = "player" then m.note.text = "Archive skip supports whole-minute provider windows. Audio compatibility changes take effect on the next tune."
    if m.page = "appearance" then m.note.text = "Appearance changes apply on this Roku without interrupting playback. Reset restores the default colors."
    if m.page = "general" then m.note.text = "Guide startup never plays automatically. Mini startup resumes only the last available channel after it starts."
    if m.page = "about" then m.note.text = "This is an independent Roku client. License and attribution text is included in the installed package."
    if m.page = "whatsNew" then m.note.text = "Release notes describe implemented Roku features. Marking read only dismisses this version's startup notice."
    if m.page = "licenses" then m.note.text = "License and attribution notices included with this Roku package. Back returns to About."
    m.items = []
    if m.choice <> invalid and m.choice.action = "remoteSlot"
        m.heading.text = m.choice.title
        m.note.text = "Applies immediately in this context. Back, Home and fullscreen * cannot be reassigned."
        current = resolveRemoteAction(model.device.remoteMap, m.choice.context, m.choice.slot)
        for each value in m.choice.values
            title = remoteActionText(value)
            if value = current then title = "[Selected] " + title
            m.items.push({title: title, value: value})
        end for
    else if m.choice <> invalid and (m.choice.action = "resetRemoteMapConfirm" or m.choice.action = "resetAppearanceConfirm")
        m.heading.text = m.choice.title
        m.note.text = "Restore defaults? Other preferences are retained."
        m.items = [{title: "Reset to defaults", value: "reset"}, {title: "Cancel", value: "cancel"}]
    else if m.choice <> invalid
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
        if m.page = "licenses"
            m.items = []
            for each path in ["pkg:/LICENSE.md", "pkg:/images/material-icons-LICENSE.txt"]
                for each line in CreateObject("roRegex", "\r?\n", "").split(ReadAsciiFile(path))
                    text = line.trim()
                    if text <> "" then m.items.push({title: left(text, 220)})
                end for
            end for
        end if
    end if
    content = CreateObject("roSGNode", "ContentNode")
    for each item in m.items
        label = item.title
        if item.action = "customAccent"
            accent = textValue(model.device.customAccent)
            if accent = "" then accent = "Preset"
            label += ": " + accent
        end if
        if item.action = "remoteSlot" then label += ": " + remoteActionText(resolveRemoteAction(model.device.remoteMap, item.context, item.slot))
        if item.key <> invalid then label += ": " + settingsValueText(settingsHubValue(model, item.scope, item.key), item.key)
        content.createChild("ContentNode").title = "   " + label
    end for
    m.list.content = content
    if focused >= 0 and focused < m.items.count() then m.list.jumpToItem = focused
    drawSettingsRail()
end sub

sub onSettingSelected(event as object)
    if not m.top.active or not m.list.isSameNode(event.getRoSGNode()) then return
    selectSetting(event.getData())
end sub

sub selectSetting(index as integer)
    if not m.top.active then return
    if index < 0 or index >= m.items.count() then return
    item = m.items[index]
    ' Informational About/license/What's New rows are not choice editors.
    if m.choice = invalid and item.page = invalid and item.action = invalid and item.values = invalid then return
    if m.choice <> invalid and m.choice.action = "remoteSlot"
        choice = m.choice
        m.top.selection = {account: m.top.model.account, action: "setRemoteAction", context: choice.context, slot: choice.slot, value: item.value}
        goBackSettings()
    else if m.choice <> invalid and (m.choice.action = "resetRemoteMapConfirm" or m.choice.action = "resetAppearanceConfirm")
        action = "resetRemoteMap"
        if m.choice.action = "resetAppearanceConfirm" then action = "resetAppearance"
        if item.value = "reset" then m.top.selection = {account: m.top.model.account, action: action}
        goBackSettings()
    else if m.choice <> invalid
        choice = m.choice
        m.top.selection = {account: m.top.model.account, scope: choice.scope, key: choice.key, value: item.value}
        goBackSettings()
    else if item.action = "connection"
        m.top.selection = {account: m.top.model.account, action: "connection"}
    else if item.action = "customAccent"
        m.accentDialog = CreateObject("roSGNode", "KeyboardDialog")
        m.accentDialog.title = "Accent: 6 hex digits (empty = preset)"
        m.accentDialog.text = textValue(m.top.model.device.customAccent)
        m.accentDialog.buttons = ["Save", "Cancel"]
        m.accentDialog.observeField("buttonSelected", "onAccentChoice")
        m.accentDialog.observeField("wasClosed", "onAccentClosed")
        m.top.getScene().dialog = m.accentDialog
    else if item.action = "about" or item.action = "whatsNew" or item.action = "licenses"
        m.stack.push({page: m.page, index: index})
        m.page = item.action
        renderSettings()
        m.list.jumpToItem = 0
    else if item.action = "markWhatsNew"
        m.top.selection = {account: m.top.model.account, action: "markWhatsNew", value: m.top.model.version}
        goBackSettings()
    else if item.action = "resetRemoteMap" or item.action = "resetAppearance"
        m.stack.push({page: m.page, index: index})
        m.choice = {title: item.title + "?", action: item.action + "Confirm"}
        renderSettings()
        m.list.jumpToItem = 0
    else
        m.stack.push({page: m.page, index: index})
        if item.page <> invalid then m.page = item.page else m.choice = item
        renderSettings()
        m.list.jumpToItem = 0
    end if
end sub

sub onAccentChoice(event as object)
    if m.accentDialog = invalid then return
    if not m.accentDialog.isSameNode(event.getRoSGNode()) then return
    if event.getData() = 0
        value = ucase(m.accentDialog.text.trim())
        if not settingsHubChangeAllowed(m.top.model, "device", "customAccent", value)
            m.accentDialog.title = "Use exactly 6 hex digits, or leave empty"
            return
        end if
        m.top.selection = {account: m.top.model.account, scope: "device", key: "customAccent", value: value}
    end if
    m.accentDialog.close = true
end sub

sub onAccentClosed(event as object)
    if m.accentDialog = invalid then return
    if not m.accentDialog.isSameNode(event.getRoSGNode()) then return
    m.accentDialog = invalid
    if m.top.active then m.list.setFocus(true)
end sub

sub goBackSettings()
    if m.stack.count() = 0
        if m.focusRegion = "detail" then focusSettingsRail() else m.top.closed = true
        return
    end if
    previous = m.stack.pop()
    m.page = previous.page
    m.choice = invalid
    renderSettings()
    m.list.jumpToItem = previous.index
    m.list.setFocus(true)
    m.focusRegion = "detail"
    drawSettingsRail()
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    return handleSettingsKey(key, press)
end function

function handleSettingsKey(key as string, press as boolean) as boolean
    if not m.top.active then return false
    if handleSettingsRailKey(key, press) then return true
    if press and (key = "back" or key = "left")
        goBackSettings()
        return true
    end if
    return false
end function
