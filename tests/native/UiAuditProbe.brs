' Replaces ONLY the probe's application init. No registry, account, network
' client, receiver, video playback or persistence observer is created here.
sub initUiAudit()
    m.devicePreferences = normalizeDevicePreferences({})
    m.global.addFields({appearance: m.devicePreferences, clockFormat: "24", audioGuide: false})
    m.accountPreferences = normalizeAccountPreferences({})
    m.screen = m.top.findNode("screen")
    m.guide = m.top.findNode("guide")
    m.settingsHub = m.top.findNode("settingsHub")
    m.phoneSetup = m.top.findNode("phoneSetup")
    m.transport = m.top.findNode("transport")
    m.playerOptions = m.top.findNode("playerOptions")
    m.auditExtra = invalid
    m.auditDialog = invalid
    m.auditTimer = m.top.createChild("Timer")
    m.auditTimer.duration = 0.8
    m.auditTimer.observeField("fire", "uiAuditReady")
    m.top.auditScreen = "welcome"
end sub

sub showUiAudit()
    if m.screen = invalid then return
    if m.auditDialog <> invalid
        m.auditDialog.close = true
        m.auditDialog = invalid
    end if
    if m.auditExtra <> invalid
        m.top.removeChild(m.auditExtra)
        m.auditExtra = invalid
    end if
    m.guide.active = false
    m.settingsHub.active = false
    m.transport.active = false
    m.playerOptions.active = false
    for each child in m.top.getChildren(-1, 0)
        if child.hasField("visible") then child.visible = false
    end for
    m.screen.removeChildrenIndex(m.screen.getChildCount(), 0)
    name = m.top.auditScreen
    m.devicePreferences = normalizeDevicePreferences({})
    if left(name, 6) = "large-" then m.devicePreferences.textSize = 120
    if left(name, 6) = "light-" then m.devicePreferences.appearanceMode = "light"
    m.global.appearance = m.devicePreferences
    if name = "welcome"
        m.screen.visible = true
        m.setupIndex = 0
        drawWelcome()
        m.top.setFocus(true)
    else if left(name, 6) = "setup-"
        m.screen.visible = true
        provider = mid(name, 7)
        m.connectionStore = defaultConnectionStore()
        entry = normalizeConnectionEntry({id: "demo", name: "Synthetic connection", provider: provider, url: "http://example.invalid", remember: true})
        m.connectionStore.entries.push(entry)
        m.selectedConnectionId = "demo"
        m.baseUrl = "http://example.invalid"
        m.guideUrl = ""
        m.authMode = "key"
        m.username = "synthetic-user"
        m.password = ""
        m.apiKey = ""
        m.remember = true
        m.selectedProfileName = ""
        m.busy = false
        m.status = "Synthetic UI only - no connection is made."
        m.setupIndex = 99
        drawSetup()
        m.top.setFocus(true)
    else if left(name, 6) = "phone-" or name = "large-phone"
        kind = "ready"
        if name = "phone-expired" then kind = "expired"
        if name = "phone-failed" then kind = "failed"
        m.phoneSetup.callFunc("seedUiAuditPhone", kind)
    else if left(name, 9) = "settings-" or name = "large-settings" or name = "light-settings"
        model = {account: "synthetic", version: "TEST", device: m.devicePreferences, guide: m.accountPreferences.guide, vodEnabled: true, vodTmdbEnabled: false, startupBehavior: "guide", movies: "allowed", series: "allowed", dvr: "manage", catchup: "allowed", dvrPreRollMinutes: 0, dvrPostRollMinutes: 0}
        m.settingsHub.model = model
        m.settingsHub.active = true
        target = mid(name, 10)
        if name = "large-settings" or name = "light-settings" then target = "appearance"
        entries = settingsHubEntries("", model)
        for i = 0 to entries.count() - 1
            if entries[i].page = target then m.settingsHub.callFunc("selectSettingsCategory", i)
        end for
        if target = "whatsnew" then m.settingsHub.callFunc("seedUiAuditSettings", "whatsNew")
        if target = "licenses" then m.settingsHub.callFunc("seedUiAuditSettings", "licenses")
    else if name = "guide-picker" or name = "guide-picker-scroll"
        m.guide.visible = true
        items = []
        for each title in ["Program details", "Toggle favorite", "Channel groups", "Search channels", "Jump to Now", "Guide settings", "Refresh guide", "Cancel"]
            items.push({title: title, action: "fixture"})
        end for
        if name = "guide-picker-scroll"
            for i = 1 to 5
                items.push({title: "Additional synthetic action " + i.toStr(), action: "fixture"})
            end for
        end if
        m.guide.callFunc("openPicker", "Guide options", items, "fixture")
    else if name = "player-options" or name = "large-options"
        items = []
        for each title in ["Audio track: English", "Subtitles: Off", "Video scaling: Fit", "A long option that must remain inside the rounded control", "Sleep timer", "Stream information", "Hide picture", "Close"]
            items.push({title: title, action: "fixture"})
        end for
        m.playerOptions.menu = {title: "Player options", note: "Synthetic choices; nothing is applied.", items: items}
        m.playerOptions.active = true
    else if name = "program-details"
        m.auditExtra = m.top.createChild("ProgramDetails")
        startAt = uiNow() - 600
        program = {id: "fixture", title: "A Synthetic Programme", subtitle: "", description: "An original fixture for checking text alignment and action buttons on the Roku.", startsAt: startAt, endsAt: startAt + 3600, poster: "", categories: [], rating: "", year: "", quality: "HD", language: "", country: "", credits: ""}
        m.auditExtra.model = {channel: {id: "1", name: "Synthetic channel"}, program: program, settings: m.accountPreferences.guide, baseUrl: "", apiKey: "", dvrPermission: "manage", reminded: false, catchupAvailable: true, restartAvailable: false}
        m.auditExtra.active = true
    else if name = "vod-details"
        m.auditExtra = m.top.createChild("VodDetails")
        m.auditExtra.title = "Synthetic Movie Details"
        m.auditExtra.message = "Original test data. No provider, credentials or media playback is used."
        m.auditExtra.buttons = ["Play movie", "Choose a source", "Mark watched", "Add to Favorites", "Add to Watchlist", "Refresh metadata", "Back to library"]
        m.auditExtra.callFunc("focusActions")
    else if name = "navigation"
        m.auditExtra = m.top.createChild("TopNavigation")
        m.auditExtra.translation = [96, 220]
        m.auditExtra.availableWidth = 1728
        m.auditExtra.items = [{id: "live", label: "Live TV", enabled: true}, {id: "vod", label: "Movies & TV", enabled: true}, {id: "settings", label: "Settings", enabled: true}]
        m.auditExtra.selected = "live"
        m.auditExtra.active = true
    else if name = "group-pills" or name = "group-sidebar"
        m.auditExtra = m.top.createChild("GroupNavigator")
        layout = "pills"
        if name = "group-sidebar" then layout = "sidebar"
        groups = [{id: "all", name: "All channels"}, {id: "favorite", name: "Favorites"}, {id: "news", name: "News"}, {id: "sports", name: "Sports"}, {id: "long", name: "A longer channel group"}]
        m.auditExtra.model = {groups: groups, layout: layout, selected: "all"}
        m.auditExtra.active = true
    else if name = "player-controls" or name = "recording-controls"
        m.transport.context = "live"
        if name = "recording-controls" then m.transport.context = "recording"
        m.transport.active = true
    else if name = "tips" or name = "light-tips"
        m.auditExtra = m.top.createChild("Group")
        uiRect(m.auditExtra, 0, 0, 1920, 1080, "0x0A1628FF")
        for i = 0 to 3
            hints = uiRemoteHints(m.auditExtra, 160, 230 + i * 140, 1600, 36 + i * 4, 22)
            hints.text = "OK  Select     Hold Left  Groups     Up/Down  Scroll     Play/Pause  Pause     Back  Return"
        end for
    else if left(name, 7) = "dialog-" or name = "light-dialog"
        dialog = CreateObject("roSGNode", "AerioDialog")
        dialog.title = "Synthetic confirmation"
        dialog.message = "No account data or actions are connected to this visual fixture."
        dialog.buttons = ["Cancel", "Add Anyway", "Replace"]
        dialog.focusButton = 2
        if name = "dialog-delete"
            dialog.title = "Delete synthetic item?"
            dialog.buttons = ["Delete", "Cancel"]
            dialog.focusButton = 1
        else if name = "dialog-diagnostics"
            dialog.title = "Diagnostics"
            dialog.buttons = ["Show support code", "Close"]
            dialog.focusButton = 0
        end if
        m.auditDialog = dialog
        m.top.dialog = dialog
    else if name = "keyboard"
        dialog = CreateObject("roSGNode", "StandardKeyboardDialog")
        dialog.title = "Synthetic text entry"
        dialog.text = "Fixture"
        dialog.buttons = ["Done", "Cancel"]
        m.auditDialog = dialog
        m.top.dialog = dialog
    end if
    uiApplyAppearanceTree(m.top)
    m.auditTimer.control = "stop"
    m.auditTimer.control = "start"
end sub

sub uiAuditReady()
    print "[ui-audit] "; formatJson({ready: true, screen: m.top.auditScreen})
end sub

sub uiAuditCheck()
    focused = -1
    if m.auditDialog <> invalid
        focused = m.auditDialog.buttonFocused
    else
        list = uiAuditFocusedList(m.top)
        if list <> invalid then focused = list.itemFocused
    end if
    print "[ui-audit] "; formatJson({check: true, screen: m.top.auditScreen, focused: focused})
end sub

function uiAuditFocusedList(node as object) as dynamic
    if node.subtype() = "AerioPillList" and node.isInFocusChain() then return node
    for each child in node.getChildren(-1, 0)
        found = uiAuditFocusedList(child)
        if found <> invalid then return found
    end for
    return invalid
end function

function onKeyEvent(key as string, press as boolean) as boolean
    ' Child controls may exercise focus and emit events, but the normal Scene's
    ' handlers are never connected. Never call its account/media actions.
    return true
end function
