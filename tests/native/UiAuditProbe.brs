' Replaces ONLY the probe's application init. No registry, account, network
' client, receiver, video playback or persistence observer is created here.
sub initUiAudit()
    uiSetColor(m.top, "0x0A1628FF", "backgroundColor")
    m.top.backgroundUri = ""
    m.devicePreferences = normalizeDevicePreferences({})
    m.global.addFields({appearance: m.devicePreferences, clockFormat: "24", audioGuide: false})
    m.global.addFields({uiAuditLibraryCase: ""})
    m.accountPreferences = normalizeAccountPreferences({})
    m.screen = m.top.findNode("screen")
    m.guide = m.top.findNode("guide")
    m.settingsHub = m.top.findNode("settingsHub")
    m.phoneSetup = m.top.findNode("phoneSetup")
    m.transport = m.top.findNode("transport")
    m.playerOptions = m.top.findNode("playerOptions")
    m.browser = m.top.findNode("channelBrowser")
    m.banner = m.top.findNode("playerBanner")
    m.channelTuneTimer = m.top.findNode("channelTuneTimer")
    m.heldZapTimer = m.top.findNode("heldZapTimer")
    m.bannerTimer = m.top.findNode("bannerTimer")
    m.playerOkTimer = m.top.findNode("playerOkTimer")
    m.playerOptions.observeField("selection", "uiAuditPlayerSelection")
    m.playerOptions.observeField("backRequested", "uiAuditPlayerBack")
    m.browser.observeField("historyRequest", "uiAuditHistory")
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
        if m.auditExtra.hasField("active") then m.auditExtra.active = false
        m.top.removeChild(m.auditExtra)
        m.auditExtra = invalid
    end if
    closeRecordDialog()
    closeConnectionDialog()
    closeRecentHistoryDialog()
    cancelPlaybackFailure()
    cancelAacFailure()
    if m.top.dialog <> invalid then m.top.dialog.close = true
    m.guide.active = false
    m.settingsHub.active = false
    m.transport.active = false
    m.playerOptions.active = false
    m.browser.active = false
    for each child in m.top.getChildren(-1, 0)
        if child.hasField("visible") then child.visible = false
    end for
    m.screen.removeChildrenIndex(m.screen.getChildCount(), 0)
    name = m.top.auditScreen
    m.devicePreferences = normalizeDevicePreferences({})
    if left(name, 6) = "large-" then m.devicePreferences.textSize = 120
    if left(name, 6) = "light-" then m.devicePreferences.appearanceMode = "light"
    m.global.appearance = m.devicePreferences
    scenario = name
    if left(name, 6) = "large-" or left(name, 6) = "light-" then scenario = mid(name, 7)
    m.global.uiAuditLibraryCase = scenario
    if left(scenario, 6) = "popup-"
        m.page = "fixture"
        m.accountIdentity = "ui-audit"
        m.apiKey = ""
        if scenario = "popup-live-failure" or scenario = "popup-live-retry"
            if scenario = "popup-live-retry" then m.playbackRetry = {account: "ui-audit", channel: uiAuditChannels()[0]}
            showPlaybackFailure(-5, "Synthetic buffering timeout; no media request.")
            m.playbackFailureDialog.unobserveField("buttonSelected")
        else if scenario = "popup-aac-failure"
            showAacUnavailable({account: "ui-audit"}, "Synthetic compatibility profile unavailable.")
            m.aacFailureDialog.unobserveField("buttonSelected")
        else if scenario = "popup-diagnostics"
            m.diagnosticLog = []
            recordDiagnostic("playback", -5, "Synthetic event for layout inspection.")
            showDiagnostics()
            m.diagnosticDialog.unobserveField("buttonSelected")
        else if scenario = "popup-recent-history"
            seedUiAuditLive("live-recent")
            m.accountPreferences.recent = ["audit-1", "audit-2"]
            m.browser.callFunc("handleOptionsShortcut")
        end if
    else if scenario = "search-populated"
        m.auditExtra = m.top.createChild("ProgramSearchView")
        channels = uiAuditChannels()
        programs = uiAuditPrograms(channels[0], uiNow())
        rows = []
        for i = 0 to 5
            rows.push({channel: channels[i], program: programs[i]})
        end for
        m.auditExtra.model = {query: "Synthetic", searchField: "Title", items: rows, loading: false, hasNext: true, page: 1, message: "Synthetic results; no search request."}
        m.auditExtra.active = true
    else if left(scenario, 11) = "connection-"
        m.page = "fixture"
        m.busy = false
        m.connectionStore = defaultConnectionStore()
        for i = 1 to 4
            m.connectionStore.entries.push(normalizeConnectionEntry({id: "audit-" + i.toStr(), name: "Synthetic connection " + i.toStr(), provider: "dispatcharr", url: "https://example.invalid", remember: false}))
        end for
        m.selectedConnectionId = "audit-1"
        if scenario = "connection-picker" then openConnectionPicker()
        if scenario = "connection-manager" then openConnectionManager()
        if scenario = "connection-advanced" then openConnectionAdvanced()
        if scenario = "connection-auth" then openConnectionAuthModes()
        if scenario = "connection-forget" then openRemoveConnectionConfirmation()
        if m.connectionDialog <> invalid then m.connectionDialog.unobserveField("buttonSelected")
    else if left(scenario, 7) = "record-"
        m.page = "fixture"
        m.accountIdentity = "ui-audit"
        m.capabilities = {dvr: "manage"}
        channels = uiAuditChannels()
        programs = uiAuditPrograms(channels[0], uiNow())
        openRecordFlow(channels[0], programs[4], "ui-audit")
        if scenario = "record-confirm" then openRecordPicker("Confirm server recording", recordingConfirmationText(m.recordIntent, m.recordPadding), [{title: "Cancel", action: "cancel"}, {title: "Record once on server", action: "confirm"}])
        m.recordDialog.unobserveField("buttonSelected")
    else if left(scenario, 6) = "guide-" and scenario <> "guide-picker" and scenario <> "guide-picker-scroll"
        m.guide.callFunc("seedUiAuditGuide", scenario)
        m.guide.observeField("watchChannel", "uiAuditForbiddenPlay")
        m.guide.observeField("archiveRequest", "uiAuditForbiddenPlay")
        m.guide.observeField("recordRequest", "uiAuditForbiddenPlay")
    else if left(scenario, 5) = "live-"
        seedUiAuditLive(scenario)
    else if left(scenario, 8) = "library-" or left(scenario, 4) = "dvr-"
        kind = "VodView"
        if left(scenario, 4) = "dvr-" then kind = "DvrView"
        m.auditExtra = m.top.createChild(kind)
        m.auditExtra.observeField("playRequested", "uiAuditForbiddenPlay")
        hook = "seedUiAuditVod"
        if kind = "DvrView" then hook = "seedUiAuditDvr"
        m.auditExtra.callFunc(hook, scenario)
    else if scenario = "series-options"
        m.page = "fixture"
        m.accountIdentity = "ui-audit"
        m.capabilities = {dvr: "manage"}
        m.recordTask = invalid
        m.recordIntent = {account: "ui-audit", scope: "ui-audit", channelId: "1", tvgId: "synthetic-channel"}
        m.seriesDraft = {title: "A long synthetic series title for checking rule configuration", tvgId: "synthetic-channel", channelId: "1", mode: "new", titleMode: "exact", description: "A synthetic description phrase", untaggedIsNew: false}
        showSeriesOptions()
    else if name = "welcome"
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
        if target = "choice" or target = "remote-player" or target = "remote-guide" or target = "reset" then m.settingsHub.callFunc("seedUiAuditSettings", target)
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
    state = {check: true, screen: m.top.auditScreen, focused: focused}
    if m.guide.active then state.guide = m.guide.callFunc("uiAuditGuideState")
    if m.playerOptions.active then state.player = {kind: m.optionKind, focused: m.playerOptions.focusedIndex, menu: m.playerOptions.menu}
    state.browser = m.browser.active
    if m.auditExtra <> invalid
        if m.auditExtra.subtype() = "VodView" or m.auditExtra.subtype() = "DvrView" then state.library = m.auditExtra.callFunc("uiAuditLibraryState")
    end if
    if m.top.dialog <> invalid
        state.sceneDialog = m.top.dialog.subtype()
        state.buttons = m.top.dialog.buttons
        if state.sceneDialog = "AerioDialog" then state.focused = m.top.dialog.buttonFocused
    end if
    print "[ui-audit] "; formatJson(state)
end sub

sub seedUiAuditLive(scenario as string)
    channels = uiAuditChannels()
    now = uiNow()
    ' A record supplies native snapshot inputs, never an actual media node.
    m.video = {globalCaptionMode: "Off", state: "playing", content: invalid, audioTrack: "1", subtitleTrack: ""
        availableAudioTracks: [{track: "1", language: "eng", name: "English stereo"}, {track: "2", language: "spa", name: "Spanish stereo"}]
        availableSubtitleTracks: [{trackName: "1", language: "eng", description: "English captions"}, {trackName: "2", language: "spa", description: "Spanish captions"}]}
    m.page = "fixture"
    m.mini = false
    m.serverAccountId = "fixture"
    m.capabilities = {dvr: "manage", catchup: "denied", switchStreams: "denied"}
    m.channelFacts = {}
    m.playingChannel = channels[0]
    m.sleepDeadline = 0
    m.serverStreamInfo = serverStreamDetails(invalid)
    m.serverStreamMessage = "Synthetic snapshot; no stream or server request."
    m.streamReady = false
    m.optionReturnAction = ""
    m.optionKind = ""
    m.apiKey = ""
    if left(scenario, 12) = "live-banner-"
        m.banner.playhead = invalid
        m.banner.visible = true
        m.banner.preferences = m.devicePreferences
        m.banner.session = {baseUrl: "", apiKey: ""}
        m.banner.channel = channels[0]
        m.banner.info = {channelUuid: channels[0].uuid, programs: uiAuditPrograms(channels[0], now), status: "ready"}
        m.banner.playbackState = mid(scenario, 13)
        m.banner.hint = "OK  Info    Hold OK  Options    Down  Controls    Back  Guide"
        m.banner.now = now
        if scenario = "live-banner-paused" then m.banner.playhead = {known: true, delayed: true, epoch: now - 120, delay: 120, estimated: false}
    else if scenario = "live-browser" or scenario = "live-recent"
        mode = "channels"
        if scenario = "live-recent" then mode = "recent"
        m.browser.model = {channels: channels, groups: [{id: "all", name: "All channels"}, {id: "group:news", name: "News"}], favorites: {}, recent: ["audit-1", "audit-2"], historyAccount: "ui-audit", collections: [], settings: m.accountPreferences.guide, baseUrl: "", apiKey: "", mode: mode, group: "all"}
        m.browser.playingUuid = channels[0].uuid
        m.browser.active = true
        m.browser.observeField("channelSelected", "uiAuditForbiddenPlay")
    else
        kind = mid(scenario, 6)
        if kind = "audiomode" then kind = "audioMode"
        if kind = "livetransport" then kind = "liveTransport"
        if kind = "streaminfo" then kind = "streamInfo"
        openPlayerOptions(kind)
    end if
end sub

sub uiAuditPlayerSelection(event as object)
    ' Only display submenu choices. No production media/settings handler attached.
    routes = {audioMenu: "audio", subtitleMenu: "subtitle", captionsMenu: "captions", scaleMenu: "scale", sleepMenu: "sleep", audioModeMenu: "audioMode", liveTransportMenu: "liveTransport", clockMenu: "clock", directionMenu: "direction", streamInfo: "streamInfo", aspectMenu: "aspect"}
    item = event.getData()
    if routes.doesExist(item.action)
        openPlayerOptions(routes[item.action])
    else
        print "[ui-audit] "; formatJson({forbidden: true, action: item.action})
    end if
end sub

sub uiAuditPlayerBack()
    if m.optionKind <> "main" and left(m.global.uiAuditLibraryCase, 5) = "live-" then openPlayerOptions("main")
end sub

sub uiAuditHistory(event as object)
    onRecentHistoryRequested(event)
    if m.historyDialog <> invalid then m.historyDialog.unobserveField("buttonSelected")
end sub

sub uiAuditForbiddenPlay()
    print "[ui-audit] "; formatJson({forbidden: true, action: "playRequested"})
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
