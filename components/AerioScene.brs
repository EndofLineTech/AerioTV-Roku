sub init()
    m.global.addFields({metadataSession: CreateObject("roDeviceInfo").getRandomUUID(), cacheEpoch: CreateObject("roDeviceInfo").getRandomUUID(), networkTimeoutMs: 20000})
    m.top.focusable = true
    m.top.backgroundColor = "0x0A1628FF"
    m.top.backgroundUri = ""
    m.vod = m.top.findNode("vodLibrary")
    m.vod.observeField("playRequested", "onVodPlay")
    m.vod.observeField("stateChange", "onVodStateChange")
    m.vod.observeField("bookmark", "onVodBookmark")
    m.vod.observeField("exitRequested", "closeVodLibrary")
    m.vod.observeField("destination", "onLibraryDestination")
    m.mediaPlayer = m.top.findNode("onDemandPlayer")
    m.mediaPlayer.observeField("closed", "onMediaClosed")
    m.mediaPlayer.observeField("progress", "onMediaProgress")
    m.mediaPlayer.observeField("diagnostic", "onMediaDiagnostic")
    m.mediaPlayer.observeField("archiveSeek", "onArchiveSeek")
    m.mediaPlayer.observeField("goLiveRequested", "onArchiveGoLive")
    m.mediaPlayer.observeField("skipPreference", "onArchiveSkipPreference")
    m.screen = m.top.findNode("screen")
    m.guide = m.top.findNode("guide")
    m.settingsHub = m.top.findNode("settingsHub")
    m.settingsHub.observeField("selection", "onSettingsHubSelection")
    m.settingsHub.observeField("closed", "closeSettingsHub")
    m.video = m.top.findNode("video")
    m.playerOkDown = false
    m.playerOkTimer = m.top.findNode("playerOkTimer")
    m.playerOkTimer.observeField("fire", "onPlayerOkHold")
    m.video.observeField("optionsKeyPress", "onNativeVideoOptions")
    m.video.observeField("playerKey", "onNativePlayerKey")
    m.hiddenCaptionMode = false
    m.playerInput = m.top.findNode("playerInput")
    m.videoViewport = m.top.findNode("videoViewport")
    m.audioCheck = m.top.findNode("audioCheck")
    m.audioCheck.observeField("fire", "checkPlaybackAudio")
    m.reminderClock = m.top.findNode("reminderClock")
    m.reminderClock.observeField("fire", "checkReminders")
    m.refreshTask = invalid
    m.aacProfile = invalid
    m.aacDiscoveryState = "idle"
    m.aacDiscoveryMessage = ""
    m.pendingAacTune = invalid
    m.aacFailureDialog = invalid
    m.aacFailureRequest = invalid
    m.aacWaitTimer = m.top.findNode("aacWaitTimer")
    m.aacWaitTimer.observeField("fire", "processAacWait")
    m.activeAudioProfile = ""
    m.sourceWatch = m.top.findNode("sourceWatch")
    m.sourceWatch.observeField("fire", "checkSourceVideo")
    m.sourceWatchState = invalid
    m.recoveryTask = invalid
    m.recoveryIssued = false
    m.recoveryPausePending = false
    m.pendingScale = ""
    m.banner = m.top.findNode("playerBanner")
    m.transport = m.top.findNode("transport")
    m.transport.observeField("action", "onTransportAction")
    m.transport.observeField("dismissed", "onTransportDismissed")
    m.transport.observeField("infoFocus", "onTransportInfoFocus")
    m.browser = m.top.findNode("channelBrowser")
    m.browser.observeField("channelSelected", "onBrowserSelected")
    m.browser.observeField("closed", "onBrowserClosed")
    m.browser.observeField("infoRequest", "onBrowserInfoRequest")
    m.miniFrame = m.top.findNode("miniFrame")
    m.miniCaption = m.top.findNode("miniCaption")
    captionFont = m.miniCaption.font
    captionFont.size = 18
    m.miniCaption.font = captionFont
    m.mini = false
    m.userInfoOpen = false
    m.sleepDeadline = 0
    m.bannerTimer = m.top.findNode("bannerTimer")
    m.bannerTimer.observeField("fire", "onBannerTimeout")
    m.playerClock = m.top.findNode("playerClock")
    m.playerClock.observeField("fire", "onPlayerClock")
    m.playerOptions = m.top.findNode("playerOptions")
    m.playerOptions.observeField("selection", "onPlayerOption")
    m.playerOptions.observeField("closed", "onPlayerOptionsClosed")
    m.playerOptions.observeField("backRequested", "onPlayerOptionsBack")
    m.optionKind = "main"
    m.optionReturnAction = ""
    m.pictureCover = m.top.findNode("pictureCover")
    m.pictureHint = m.top.findNode("pictureHint")
    m.pictureHintTimer = m.top.findNode("pictureHintTimer")
    m.pictureHintTimer.observeField("fire", "hidePictureHint")
    m.pictureWakeKey = ""
    m.connectionClock = m.top.findNode("connectionClock")
    m.connectionClock.observeField("fire", "onConnectionTick")
    m.channelTuneTimer = m.top.findNode("channelTuneTimer")
    m.channelTuneTimer.observeField("fire", "commitChannelSwitch")
    m.heldZapTimer = m.top.findNode("heldZapTimer")
    m.heldZapTimer.observeField("fire", "repeatHeldZap")
    m.heldZap = ""
    m.playingChannel = invalid
    m.startupWatch = invalid
    m.startupRetryCount = 0
    m.pendingChannel = invalid
    m.video.observeField("state", "onVideoState")
    m.video.enableDecoderStats = true
    print "[video] native fields="; FormatJson(m.video.getFields().keys())
    m.video.observeField("decoderStats", "onDecoderStats")
    m.streamReady = false
    m.decoderKeysReported = false
    m.decoderSnapshot = {}
    m.capabilities = normalizeCapabilities(invalid, invalid, invalid, 0)
    m.channelFacts = {}
    m.capabilityTask = invalid
    m.sourceTask = invalid
    m.streamInfoTask = invalid
    m.serverStreamInfo = invalid
    m.serverStreamMessage = ""
    m.sourceChoices = []
    m.sourceClientCount = 0
    m.serverAccountId = ""
    m.capabilityClock = m.top.findNode("capabilityClock")
    m.capabilityClock.observeField("fire", "refreshCapabilities")
    m.guide.observeField("watchChannel", "onWatchChannel")
    m.guide.observeField("exitRequested", "showConnection")
    m.guide.observeField("archiveRequest", "onArchiveRequested")
    m.guide.observeField("metadataEvent", "onMetadataDiagnostic")
    m.guide.observeField("preferences", "onPreferences")
    m.guide.observeField("playbackInfo", "onPlaybackInfo")
    m.guide.observeField("playerRequest", "onGuidePlayerRequest")
    m.guide.observeField("devicePreference", "onDevicePreference")
    m.registry = CreateObject("roRegistrySection", "AerioTV")
    m.preferenceStore = loadPreferenceStore(m.registry)
    m.devicePreferences = m.preferenceStore.device
    m.global.addFields({clockFormat: "24", clockPreference: m.devicePreferences.clockFormat})
    applyClockFormat()
    applyDevicePreferences()
    m.accountPreferences = normalizeAccountPreferences(invalid)
    m.recordedChannel = ""
    m.notice = m.top.findNode("notice")
    m.noticeText = m.top.findNode("noticeText")
    m.noticeTimer = m.top.findNode("noticeTimer")
    m.noticeTimer.observeField("fire", "hideNotice")
    m.baseUrl = m.registry.read("serverUrl")
    m.remember = loadRememberPolicy(m.registry)
    m.apiKey = ""
    if m.remember then m.apiKey = m.registry.read("apiKey")
    m.username = ""
    m.password = ""
    m.authMode = "key"
    m.setupIndex = 0
    m.busy = false
    m.task = invalid
    m.accountIdentity = ""
    m.status = "Dispatcharr 0.31  |  Live TV and guide"
    m.page = "setup"
    drawSetup()
    m.top.setFocus(true)
    if m.baseUrl <> "" and m.apiKey <> "" then connectServer()
end sub

sub drawSetup()
    m.screen.removeChildrenIndex(m.screen.getChildCount(), 0)
    uiLabel(m.screen, "AerioTV", 160, 70, 1600, 86, 64)
    uiLabel(m.screen, "Dispatcharr Direct Connect", 164, 171, 1500, 50, 34, "0x1AC4D8FF")
    uiLabel(m.screen, "Your Live TV guide. Three days back, seven days ahead.", 164, 233, 1500, 42, 26, "0x9EB5C9FF")
    method = "API key"
    if m.authMode = "password" then method = "Dashboard username and password"
    urlText = m.baseUrl
    if urlText = "" then urlText = "http://your-dispatcharr-server:9191"
    m.setupRows = [
        {field: "url", title: "Server URL", value: urlText}
        {field: "method", title: "Sign-in method", value: method}
    ]
    if m.authMode = "password"
        m.setupRows.push({field: "username", title: "Username", value: m.username})
        value = "Select to enter"
        if m.password <> "" then value = "****************"
        m.setupRows.push({field: "password", title: "Dashboard password", value: value})
    else
        value = "Select to enter"
        if m.apiKey <> "" then value = "****************"
        m.setupRows.push({field: "key", title: "API key", value: value})
    end if
    remember = "Off — this session only"
    if m.remember then remember = "On — stored in this Roku's app registry"
    m.setupRows.push({field: "remember", title: "Remember API key", value: remember})
    connect = "CONNECT TO DISPATCHARR"
    if m.busy then connect = "CONNECTING..."
    m.setupRows.push({field: "connect", title: "Connect", value: connect})
    m.setupRows.push({field: "forget", title: "Forget connection", value: "Remove saved credentials and preferences"})
    if m.setupIndex >= m.setupRows.count() then m.setupIndex = m.setupRows.count() - 1
    for i = 0 to m.setupRows.count() - 1
        row = m.setupRows[i]
        if row.field = "connect" or row.field = "forget" then exit for
        y = 310 + i * 78
        border = "0x17344AFF"
        fill = "0x0D1E35FF"
        if i = m.setupIndex
            border = "0x1AC4D8FF"
            fill = "0x10344AFF"
        end if
        uiRect(m.screen, 160, y, 1600, 68, border)
        uiRect(m.screen, 162, y + 2, 1596, 64, fill)
        uiLabel(m.screen, row.title, 186, y + 18, 380, 40, 25, "0x1AC4D8FF")
        uiLabel(m.screen, row.value, 570, y + 18, 1155, 40, 25)
    end for
    actionY = 310 + (m.setupRows.count() - 2) * 78 + 22
    uiRect(m.screen, 160, actionY - 12, 1600, 1, "0x17344AFF")
    focusedConnect = m.setupIndex = m.setupRows.count() - 2
    focusedForget = m.setupIndex = m.setupRows.count() - 1
    connectBorder = "0x1AC4D8FF"
    connectFill = "0x1A8FA8FF"
    if focusedConnect
        connectBorder = "0xFFFFFFFF"
        connectFill = "0x1AC4D8FF"
    end if
    uiRect(m.screen, 160, actionY, 990, 90, connectBorder)
    uiRect(m.screen, 164, actionY + 4, 982, 82, connectFill)
    buttonLabel = uiLabel(m.screen, connect, 172, actionY + 24, 966, 46, 30, "0x0A1628FF")
    buttonLabel.horizAlign = "center"
    forgetBorder = "0xAA7381FF"
    forgetFill = "0x291E30FF"
    if focusedForget
        forgetBorder = "0xFFFFFFFF"
        forgetFill = "0x704151FF"
    end if
    uiRect(m.screen, 1182, actionY, 578, 90, forgetBorder)
    uiRect(m.screen, 1186, actionY + 4, 570, 82, forgetFill)
    buttonLabel = uiLabel(m.screen, "FORGET CONNECTION", 1194, actionY + 26, 554, 42, 25, "0xFFE3E8FF")
    buttonLabel.horizAlign = "center"
    hint = "Connect opens your guide. Forget removes saved credentials and preferences."
    if m.busy then hint = "Connecting to your server. Press Back to cancel."
    uiLabel(m.screen, hint, 164, actionY + 106, 1590, 42, 23, "0x9EB5C9FF")
    m.statusLabel = uiLabel(m.screen, m.status, 164, actionY + 164, 1590, 100, 24, "0x9EB5C9FF")
    m.statusLabel.wrap = true
end sub

sub editSetupField()
    field = m.setupRows[m.setupIndex].field
    if field = "connect"
        connectServer()
        return
    else if field = "remember"
        m.remember = not m.remember
        if not saveRememberPolicy(m.registry, m.remember) then showNotice("Could not save the Remember API key policy or remove its saved key. The choice is active for this session; retry before exiting.")
        drawSetup()
        return
    else if field = "method"
        if m.authMode = "key" then m.authMode = "password" else m.authMode = "key"
        drawSetup()
        return
    else if field = "forget"
        forgetConnection()
        return
    end if
    m.editingField = field
    dialog = CreateObject("roSGNode", "KeyboardDialog")
    dialog.buttons = ["Save", "Cancel"]
    dialog.title = m.setupRows[m.setupIndex].title
    if field = "url" then dialog.text = m.baseUrl
    if field = "username" then dialog.text = m.username
    if field = "password" then dialog.text = m.password
    if field = "key" then dialog.text = m.apiKey
    if field = "password" or field = "key" then dialog.keyboard.textEditBox.secureMode = true
    dialog.observeField("buttonSelected", "onKeyboardButton")
    dialog.observeField("wasClosed", "onDialogClosed")
    m.top.dialog = dialog
end sub

sub onKeyboardButton(event as object)
    dialog = event.getRoSGNode()
    if event.getData() = 0
        if m.editingField = "url"
            base = normalizeBaseUrl(dialog.text)
            if base = ""
                m.status = "Enter an http:// or https:// URL without credentials or query parameters."
            else
                if m.baseUrl <> base
                    ' Never silently reuse the old server's credential at a new URL.
                    m.apiKey = ""
                    m.password = ""
                end if
                m.baseUrl = base
                m.status = "Server URL updated. Enter credentials for this server."
            end if
        else if m.editingField = "username"
            m.username = dialog.text.trim()
        else if m.editingField = "password"
            m.password = dialog.text
        else if m.editingField = "key"
            m.apiKey = dialog.text.trim()
        end if
    end if
    dialog.close = true
    drawSetup()
end sub

sub onDialogClosed()
    if m.page = "setup" then m.top.setFocus(true)
    if m.page = "guide" then m.guide.setFocus(true)
    if m.page = "player" then focusPlaybackInput()
end sub

sub connectServer()
    if m.busy then return
    resetMediaNavigation()
    cancelPlaybackFailure()
    if m.playingChannel <> invalid then stopPlayback()
    cancelCapabilityRefresh()
    m.capabilities = normalizeCapabilities(invalid, invalid, invalid, 0)
    m.channelFacts = {}
    validCredential = m.apiKey <> ""
    if m.authMode = "password" then validCredential = m.username <> "" and m.password <> ""
    if normalizeBaseUrl(m.baseUrl) = "" or not validCredential
        m.status = "Enter a valid server URL and credentials for the selected sign-in method."
        drawSetup()
        return
    end if
    m.busy = true
    m.guide.callFunc("cancelMetadataLoads")
    m.global.cacheEpoch = CreateObject("roDeviceInfo").getRandomUUID()
    m.connectionStage = "Starting connection"
    m.connectionElapsed = CreateObject("roTimespan")
    m.connectionElapsed.mark()
    m.status = "Starting connection..."
    drawSetup()
    m.task = CreateObject("roSGNode", "DispatcharrTask")
    m.task.cacheEpoch = m.global.cacheEpoch
    m.task.baseUrl = m.baseUrl
    m.task.apiKey = m.apiKey
    if m.authMode = "password"
        m.task.username = m.username
        m.task.password = m.password
    end if
    m.task.observeField("result", "onChannelsLoaded")
    m.task.observeField("progress", "onConnectionProgress")
    m.connectionClock.control = "start"
    m.task.control = "RUN"
end sub

sub onChannelsLoaded(event as object)
    if not isCurrentTaskEvent(event, m.task) then return
    completeConnection(event.getData())
end sub

sub onConnectionProgress(event as object)
    if not isCurrentTaskEvent(event, m.task) then return
    m.connectionStage = event.getData()
    updateConnectionStatus()
end sub

sub updateConnectionStatus()
    m.status = m.connectionStage + "..." + chr(10) + m.connectionElapsed.totalSeconds().toStr() + " seconds elapsed. Back to cancel."
    m.statusLabel.text = m.status
end sub

sub onConnectionTick()
    if not m.busy or m.task = invalid then return
    ' Read terminal state as well as observing results: a task that exits without
    ' publishing must not strand the screen in its busy state.
    if m.task.state = "done" or m.task.state = "stop"
        if type(m.task.result) = "roAssociativeArray"
            completeConnection(m.task.result)
        else
            failConnection("Connection task stopped during: " + m.connectionStage + ". Please retry.")
        end if
        return
    end if
    if connectionTimedOut(m.connectionElapsed.totalSeconds())
        failConnection("Connection exceeded 120 seconds during: " + m.connectionStage + ". Please retry.")
        return
    end if
    updateConnectionStatus()
end sub

sub failConnection(message as string)
    recordDiagnostic("connect", -1, message)
    m.connectionClock.control = "stop"
    if m.task <> invalid
        m.task.unobserveField("result")
        m.task.unobserveField("progress")
        cancelNetworkTask(m.task)
        m.task = invalid
    end if
    m.busy = false
    m.status = message
    drawSetup()
end sub

sub completeConnection(result as dynamic)
    m.connectionClock.control = "stop"
    m.task.unobserveField("result")
    m.task.unobserveField("progress")
    m.task = invalid
    m.busy = false
    m.password = ""
    if type(result) <> "roAssociativeArray"
        m.status = "Unexpected connection result. Please retry."
        drawSetup()
        return
    end if
    if not result.ok
        recordDiagnostic("connect", -1, result.message)
        m.status = result.message
        drawSetup()
        return
    end if
    m.apiKey = result.apiKey
    recordDiagnostic("connect", 0, "Authorized lineup ready", m.connectionElapsed.totalMilliseconds())
    m.serverAccountId = result.accountId
    m.authMode = "key"
    m.accountIdentity = m.baseUrl + "|" + result.accountId
    m.global.cacheEpoch = CreateObject("roDeviceInfo").getRandomUUID()
    legacy = invalid
    legacyJson = m.registry.read("preferences")
    if legacyJson <> "" then legacy = ParseJson(legacyJson)
    prefs = accountPreferences(m.preferenceStore, m.accountIdentity, m.registry.read("accountIdentity"), legacy)
    m.accountPreferences = reconcileWatchHistory(prefs, result.channels)
    prefs = m.accountPreferences
    if persistAccountPreferences() then m.registry.delete("preferences")
    savedUrl = m.registry.write("serverUrl", m.baseUrl)
    savedIdentity = m.registry.write("accountIdentity", m.accountIdentity)
    savedKey = true
    if m.remember then savedKey = m.registry.write("apiKey", m.apiKey)
    savedPolicy = saveRememberPolicy(m.registry, m.remember)
    if not savedUrl or not savedIdentity or not savedKey or not savedPolicy
        result.warning = "Could not save this connection. Check Roku app storage."
    end if
    m.guide.config = {
        channels: result.channels, groups: result.groups, warning: result.warning
        baseUrl: m.baseUrl, apiKey: m.apiKey, preferences: prefs
        tmdbKey: m.registry.read("tmdbApiKey")
        scope: result.scope, generation: result.generation
    }
    m.banner.session = {baseUrl: m.baseUrl, apiKey: m.apiKey}
    m.banner.preferences = m.devicePreferences
    m.guide.remotePreferences = m.devicePreferences
    m.page = "guide"
    m.screen.visible = false
    m.guide.visible = true
    m.guide.active = true
    print "[startup] authorized lineup ms="; m.connectionElapsed.totalMilliseconds(); " channels="; result.channels.count()
    refreshCapabilities()
    m.capabilityClock.control = "start"
    m.reminderClock.control = "start"
    version = CreateObject("roAppInfo").getValue("major_version") + "." + CreateObject("roAppInfo").getValue("minor_version") + "." + CreateObject("roAppInfo").getValue("build_version")
    if m.accountPreferences.whatsNewVersion <> version then showNotice("What's New in " + version + ". Open Settings > General > About, licenses and What's New.")
    startConfiguredMiniPlayback(result.channels)
end sub

sub startConfiguredMiniPlayback(channels as object)
    m.startMiniAfterPlayback = false
    if m.accountPreferences.startupBehavior <> "mini" then return
    if m.accountPreferences.lastChannel = "" then return
    for each channel in channels
        if channel.uuid = m.accountPreferences.lastChannel
            m.startMiniAfterPlayback = true
            startPlayback(channel)
            return
        end if
    end for
    showNotice("The saved startup channel is no longer available. Opened the guide instead.")
end sub

sub cancelCapabilityRefresh()
    cancelAacWait()
    cancelAacFailure()
    m.aacDiscoveryState = "idle"
    if m.refreshTask <> invalid
        m.refreshTask.unobserveField("result")
        cancelNetworkTask(m.refreshTask)
        m.refreshTask = invalid
    end if
    m.aacProfile = invalid
    m.capabilityClock.control = "stop"
    if m.capabilityTask <> invalid
        m.capabilityTask.unobserveField("profileResult")
        m.capabilityTask.unobserveField("result")
        cancelNetworkTask(m.capabilityTask)
        m.capabilityTask = invalid
    end if
end sub

sub refreshCapabilities()
    if m.page = "setup" or m.apiKey = "" or m.serverAccountId = "" then return
    if m.capabilityTask <> invalid then return
    m.aacDiscoveryState = "pending"
    m.capabilityTask = CreateObject("roSGNode", "CapabilityTask")
    m.capabilityTask.baseUrl = m.baseUrl
    m.capabilityTask.apiKey = m.apiKey
    m.capabilityTask.accountId = m.serverAccountId
    m.capabilityTask.observeField("result", "onCapabilities")
    m.capabilityTask.observeField("profileResult", "onAacProfileDiscovered")
    m.capabilityTask.control = "RUN"
end sub

sub onAacProfileDiscovered(event as object)
    if not isCurrentTaskEvent(event, m.capabilityTask) then return
    result = event.getData()
    if result.accountId <> m.serverAccountId then return
    m.aacProfile = result.profile
    m.aacDiscoveryState = result.state
    m.aacDiscoveryMessage = result.message
    print "[aac-profile] discovery="; result.state
    processAacWait()
end sub

sub onCapabilities(event as object)
    if not isCurrentTaskEvent(event, m.capabilityTask) then return
    result = event.getData()
    m.capabilityTask.unobserveField("profileResult")
    m.capabilityTask.unobserveField("result")
    m.capabilityTask = invalid
    if result.ok
        m.capabilities = result.capabilities
        m.aacProfile = result.audioProfile
        if m.aacProfile <> invalid
            m.aacDiscoveryState = "ready"
        else if m.aacDiscoveryState = "pending"
            m.aacDiscoveryState = "unavailable"
            m.aacDiscoveryMessage = "No active copy-video/AAC output profile is available for this account."
        end if
        if m.playingChannel <> invalid then m.audioCheck.control = "start"
        m.channelFacts = result.channelFacts
        print "[capabilities] level="; m.capabilities.level; " source-switch="; m.capabilities.switchStreams; " version="; m.capabilities.version
    else
        m.capabilities = normalizeCapabilities(invalid, invalid, invalid, 0)
        m.aacProfile = invalid
        m.aacDiscoveryState = "error"
        m.aacDiscoveryMessage = result.message
        m.channelFacts = {}
        if result.identityChanged = true
            if m.playingChannel <> invalid then stopPlayback()
            showConnection()
            m.status = result.message
            drawSetup()
        end if
    end if
    m.guide.channelFacts = m.channelFacts
    m.guide.catchupPermission = m.capabilities.catchup
    updateLibraryPermissions()
    enforceMediaCapabilities()
    processAacWait()
end sub

sub onPreferences(event as object)
    if m.accountIdentity = "" then return
    m.accountPreferences = mergeAccountPreferences(m.accountPreferences, event.getData())
    persistAccountPreferences()
end sub

function persistAccountPreferences() as boolean
    if m.accountIdentity = "" then return false
    m.preferenceStore.accounts[preferenceScope(m.accountIdentity)] = m.accountPreferences
    return persistPreferences()
end function

function persistPreferences() as boolean
    m.preferenceStore.device = m.devicePreferences
    if savePreferenceStore(m.registry, m.preferenceStore) then return true
    showNotice("Your change is active for this session but could not be saved. Local storage is full, unavailable, or uses a newer settings format.")
    return false
end function

sub showNotice(message as string)
    m.noticeText.text = message
    m.notice.visible = true
    m.noticeTimer.control = "stop"
    m.noticeTimer.control = "start"
end sub

sub hideNotice()
    m.notice.visible = false
end sub

sub showAacUnavailable(request as object, message as string)
    if request.account <> m.accountIdentity then return
    cancelAacFailure()
    m.aacFailureRequest = request
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = "AAC compatibility unavailable"
    dialog.message = sanitizePlaybackDiagnostic(message, m.apiKey) + chr(10) + "No direct stream was started for this request. Choose another audio mode for this Roku, or Cancel to keep Always AAC."
    dialog.buttons = ["Use Automatic", "Use Direct", "Cancel"]
    dialog.observeField("buttonSelected", "onAacFailureChoice")
    dialog.observeField("wasClosed", "onAacFailureClosed")
    m.aacFailureDialog = dialog
    m.top.dialog = dialog
end sub

sub cancelAacFailure()
    if m.aacFailureDialog <> invalid
        m.aacFailureDialog.unobserveField("buttonSelected")
        m.aacFailureDialog.unobserveField("wasClosed")
        m.aacFailureDialog.close = true
    end if
    m.aacFailureDialog = invalid
    m.aacFailureRequest = invalid
end sub

sub onAacFailureChoice(event as object)
    if m.aacFailureDialog = invalid then return
    if not m.aacFailureDialog.isSameNode(event.getRoSGNode()) then return
    request = m.aacFailureRequest
    choice = event.getData()
    if choice < 0 or choice > 2 then return
    cancelAacFailure()
    onDialogClosed()
    if request = invalid or choice = 2 then return
    if request.account <> m.accountIdentity then return
    if choice = 0 then m.devicePreferences.audioMode = "auto" else m.devicePreferences.audioMode = "direct"
    persistPreferences()
    startPlayback(request.channel, true, false, false, request.tuneStartedAt)
end sub

sub onAacFailureClosed(event as object)
    if m.aacFailureDialog = invalid or event.getData() <> true then return
    if not m.aacFailureDialog.isSameNode(event.getRoSGNode()) then return
    cancelAacFailure()
    onDialogClosed()
end sub

sub showConnection()
    resetMediaNavigation()
    m.guide.active = false
    m.guide.visible = false
    m.screen.visible = true
    m.page = "setup"
    m.status = "Edit connection settings, or select Connect to reload."
    drawSetup()
    m.top.setFocus(true)
end sub

sub forgetConnection()
    resetMediaNavigation()
    cancelPlaybackFailure()
    m.metadataForgetTask = m.guide.callFunc("forgetStoredMetadata")
    m.browser.callFunc("invalidateLogos")
    cancelCapabilityRefresh()
    m.capabilities = normalizeCapabilities(invalid, invalid, invalid, 0)
    m.serverAccountId = ""
    m.channelFacts = {}
    if m.playingChannel <> invalid then stopPlayback()
    if m.accountIdentity <> ""
        m.preferenceStore.accounts.delete(preferenceScope(m.accountIdentity))
        persistPreferences()
    end if
    for each key in ["serverUrl", "apiKey", "accountIdentity", "preferences"]
        m.registry.delete(key)
    end for
    m.registry.flush()
    m.baseUrl = ""
    m.apiKey = ""
    m.username = ""
    m.password = ""
    m.accountIdentity = ""
    m.accountPreferences = normalizeAccountPreferences(invalid)
    m.guide.active = false
    ' Recreate the guide to release account data, cached programs and HTTP agent.
    m.top.removeChild(m.guide)
    m.guide = CreateObject("roSGNode", "GuideView")
    m.guide.observeField("archiveRequest", "onArchiveRequested")
    m.guide.observeField("metadataEvent", "onMetadataDiagnostic")
    m.guide.visible = false
    m.top.insertChild(m.guide, 1)
    m.guide.observeField("watchChannel", "onWatchChannel")
    m.guide.observeField("exitRequested", "showConnection")
    m.guide.observeField("preferences", "onPreferences")
    m.guide.observeField("playbackInfo", "onPlaybackInfo")
    m.guide.observeField("playerRequest", "onGuidePlayerRequest")
    m.guide.observeField("devicePreference", "onDevicePreference")
    m.banner.session = invalid
    m.banner.channel = invalid
    m.banner.info = invalid
    m.status = "Saved connection and preferences removed."
    drawSetup()
end sub

sub onWatchChannel(event as object)
    startPlayback(event.getData())
end sub

sub startPlayback(channel as object, forceRetune = false as boolean, useAac = false as boolean, preserveStartupBudget = false as boolean, tuneStartedAt = 0 as integer)
    if m.settingsHub <> invalid
        if m.settingsHub.active then closeSettingsHub()
    end if
    cancelPlaybackFailure()
    cancelAacWait()
    cancelAacFailure()
    cancelPlayerOkHold()
    cancelHeldZap()
    m.audioCheck.control = "stop"
    restorePicture()
    cancelSourceOperation()
    m.channelTuneTimer.control = "stop"
    m.pendingChannel = invalid
    if m.playingChannel <> invalid
        if not forceRetune and m.playingChannel.uuid = channel.uuid and m.video.state <> "error" and m.video.state <> "finished"
            expandPlayback()
            return
        end if
    end if
    descriptor = livePlaybackDescriptor(m.baseUrl, channel)
    if descriptor = invalid
        showPlaybackFailure(-4, "Channel or server information is missing or invalid.")
        return
    end if
    cancelStartupWatch()
    if deferRequiredAacTune(channel, forceRetune, useAac, preserveStartupBudget, tuneStartedAt) then return
    m.guide.active = false
    m.guide.visible = false
    m.screen.visible = false
    m.browser.active = false
    m.playerOptions.active = false
    m.transport.active = false
    m.transport.visible = false
    m.userInfoOpen = false
    m.mini = false
    m.miniFrame.visible = false
    m.guide.miniActive = false
    cancelStartupWatch()
    if not preserveStartupBudget then m.startupRetryCount = 0
    if not preserveStartupBudget then m.liveRetryCount = 0
    m.liveBufferWatch = invalid
    m.video.control = "stop"
    m.streamReady = false
    m.decoderKeysReported = false
    m.decoderSnapshot = {}
    m.playingChannel = channel
    m.liveSession = mediaSession(m.accountIdentity, CreateObject("roDeviceInfo").getRandomUUID(), "live", channel.uuid, uiNow())
    if tuneStartedAt > 0 and tuneStartedAt <= uiNow() then m.liveSession.openedAt = tuneStartedAt
    applyVideoLayout()
    m.recordedChannel = ""
    if not forceRetune then m.guide.callFunc("selectPlayingChannel", channel.uuid)
    m.guide.playbackChannel = channel
    content = CreateObject("roSGNode", "ContentNode")
    content.setFields(descriptor)
    m.activeAudioProfile = ""
    if m.devicePreferences.audioMode = "aac" then useAac = true
    if m.devicePreferences.audioMode = "auto"
        for each id in m.accountPreferences.aacChannels
            if id = channel.uuid then useAac = true
        end for
    end if
    if useAac and m.aacProfile <> invalid
        m.activeAudioProfile = m.aacProfile.id
        content.url += "&output_profile=" + m.activeAudioProfile
    else if m.devicePreferences.audioMode = "direct"
        content.url += "&output_profile=0"
    end if
    content.httpCertificatesFile = "common:/certs/ca-bundle.crt"
    content.httpHeaders = ["X-API-Key: " + m.apiKey, "Authorization: ApiKey " + m.apiKey, "User-Agent: AerioTV-Roku/0.3.36"]
    m.video.content = content
    m.page = "player"
    m.video.visible = true
    ' AerioVideo forwards keys to the Scene instead of native transport actions.
    print "[playback] tuning channel "; channel.number
    focusPlaybackInput()
    beginStartupWatch(content)
    m.video.control = "play"
    m.playerClock.control = "start"
    showChannelBanner(channel, playerInfoHint())
end sub

sub showChannelBanner(channel as object, hint as string)
    if m.mini or m.pictureCover.visible then return
    m.banner.channel = channel
    m.banner.info = m.guide.callFunc("cachedPlaybackInfo", channel, uiNow())
    m.banner.playhead = invalid
    if m.pendingChannel = invalid then updateLivePresentation()
    m.banner.hint = hint
    m.banner.playbackState = m.video.state
    if m.pendingChannel <> invalid then m.banner.playbackState = "preview"
    m.banner.visible = true
    m.banner.now = uiNow()
    m.bannerTimer.control = "stop"
    if not m.transport.active and not m.userInfoOpen then m.bannerTimer.control = "start"
end sub

function playerInfoHint() as string
    hint = playerRemoteHint(m.userInfoOpen = true)
    if m.video.state = "buffering"
        stage = "Buffering... "
        if m.startupWatch <> invalid then stage = "Starting stream (" + m.startupWatch.clock.totalSeconds().toStr() + "s)... "
        if m.liveBufferWatch <> invalid then stage = "Buffering (" + m.liveBufferWatch.clock.totalSeconds().toStr() + "s)... "
        hint = stage + hint
    end if
    remaining = sleepTimerRemaining(m.sleepDeadline, uiNow())
    if remaining > 0 then hint += "    Sleep " + ((remaining + 59) \ 60).toStr() + "m"
    return hint
end function

sub onPlaybackInfo(event as object)
    if not m.guide.isSameNode(event.getRoSGNode()) then return
    if m.page <> "player" or m.playingChannel = invalid or m.pendingChannel <> invalid then return
    info = event.getData()
    if type(info) <> "roAssociativeArray" then return
    if info.channelUuid <> m.playingChannel.uuid then return
    ' Never reopen a dismissed overlay or steal focus when metadata arrives.
    m.banner.info = info
    updateLivePresentation()
    m.banner.now = uiNow()
end sub

sub onPlayerClock()
    m.guide.sleepActive = m.sleepDeadline > uiNow()
    updateLivePresentation()
    if m.page = "player" then m.banner.now = uiNow()
    if m.playingChannel <> invalid
        if sleepTimerRemaining(m.sleepDeadline, uiNow()) = 0
            m.sleepDeadline = 0
            stopPlayback()
            showNotice("Sleep timer finished. Playback stopped.")
            print "[player] sleep timer expired"
        else if m.banner.visible
            m.banner.hint = playerInfoHint()
        end if
    end if
    checkStartupPlayback()
    checkLivePlayback()
end sub

sub updateLivePresentation()
    if m.liveSession = invalid or m.playingChannel = invalid then return
    if m.pendingChannel <> invalid then return
    now = uiNow()
    clock = mediaLiveClock(m.liveSession, m.video.state, m.video.position, m.video.positionInfo, m.video.clipId, now, m.video.pauseBufferOverflow)
    m.banner.playhead = clock
    playbackEpoch = 0
    if clock.known
        if clock.delayed or m.video.state = "paused"
            playbackEpoch = clock.epoch
            m.banner.info = m.guide.callFunc("cachedPlaybackInfo", m.playingChannel, clock.epoch)
        end if
    end if
    m.guide.playbackEpoch = playbackEpoch
end sub

sub togglePlayerInfo()
    if m.pendingChannel <> invalid then return
    if m.userInfoOpen
        m.bannerTimer.control = "stop"
        hideBanner()
    else if m.playingChannel <> invalid
        m.transport.active = false
        m.userInfoOpen = true
        m.transport.visible = true
        showChannelBanner(m.playingChannel, playerInfoHint())
        focusPlaybackInput()
    end if
end sub

sub queueChannelSwitch(direction as integer)
    if m.playingChannel = invalid then return
    current = m.playingChannel
    if m.pendingChannel <> invalid then current = m.pendingChannel
    selection = m.guide.callFunc("adjacentPlayingChannel", current.uuid, direction)
    if selection = invalid
        showNotice("This channel is outside the guide's current filter. Use Channels or change the guide group to continue browsing.")
        return
    end if
    if not selection.changed
        hint = "First channel in this list"
        if direction > 0 then hint = "Last channel in this list"
        showChannelBanner(selection.channel, hint)
        return
    end if
    m.pendingChannel = selection.channel
    showChannelBanner(m.pendingChannel, "Switching channel...  |  Up/Down to choose  |  Back to guide")
    ' Coalesce key repeats so rapidly browsing doesn't open every intermediate stream.
    m.channelTuneTimer.control = "stop"
    m.channelTuneTimer.control = "start"
end sub

sub commitChannelSwitch()
    if m.heldZap <> "" then return
    if m.page <> "player" or m.pendingChannel = invalid then return
    channel = m.pendingChannel
    m.pendingChannel = invalid
    if m.playingChannel <> invalid
        if m.playingChannel.uuid = channel.uuid
            showChannelBanner(channel, playerInfoHint())
            return
        end if
    end if
    startPlayback(channel)
end sub

sub onBannerTimeout()
    ' Explicitly summoned chrome belongs to the viewer, not the tune-in timer.
    ' Also guard an expiry event already queued before the timer was stopped.
    if m.userInfoOpen or m.transport.active then return
    hideBanner()
end sub

sub enterPlayerControls()
    cancelPlayerOkHold()
    m.bannerTimer.control = "stop"
    m.userInfoOpen = true
    m.banner.visible = true
    m.transport.visible = true
    m.transport.active = true
    ' Reassert focus even when active was already true after an interrupted handoff.
    m.transport.setFocus(true)
end sub

sub hideBanner()
    if m.transport.active then return
    m.banner.visible = false
    m.userInfoOpen = false
    m.transport.visible = false
end sub

sub stopPlayback()
    if m.settingsHub <> invalid then m.settingsHub.active = false
    m.startMiniAfterPlayback = false
    if m.liveSession <> invalid then mediaEnd(m.liveSession)
    cancelPlaybackFailure()
    m.liveBufferWatch = invalid
    cancelAacWait()
    cancelAacFailure()
    cancelStartupWatch()
    cancelPlayerOkHold()
    cancelHeldZap()
    m.audioCheck.control = "stop"
    restorePicture()
    cancelSourceOperation()
    wasSetup = m.page = "setup"
    m.browser.active = false
    m.transport.active = false
    m.transport.visible = false
    m.userInfoOpen = false
    m.mini = false
    m.miniFrame.visible = false
    m.guide.miniActive = false
    m.sleepDeadline = 0
    m.playerOptions.active = false
    m.guide.sleepActive = false
    m.playerClock.control = "stop"
    m.channelTuneTimer.control = "stop"
    m.pendingChannel = invalid
    m.playingChannel = invalid
    m.streamReady = false
    m.decoderSnapshot = {}
    m.page = "guide"
    m.video.control = "stop"
    m.video.visible = false
    m.video.content = invalid
    m.bannerTimer.control = "stop"
    m.banner.visible = false
    m.banner.channel = invalid
    m.banner.info = invalid
    m.guide.playbackChannel = invalid
    m.guide.playbackEpoch = 0
    m.guide.visible = true
    m.guide.active = true
    if wasSetup
        m.guide.active = false
        m.guide.visible = false
        m.page = "setup"
        m.screen.visible = true
        m.top.setFocus(true)
    end if
end sub

sub minimizePlayback()
    cancelPlayerOkHold()
    cancelHeldZap()
    restorePicture()
    if m.playingChannel = invalid then return
    m.channelTuneTimer.control = "stop"
    m.pendingChannel = invalid
    m.playerOptions.active = false
    m.browser.active = false
    m.transport.active = false
    hideBanner()
    m.bannerTimer.control = "stop"
    m.mini = true
    m.page = "guide"
    applyVideoLayout()
    m.miniCaption.text = m.playingChannel.name
    m.miniFrame.visible = true
    m.guide.miniActive = true
    m.screen.visible = false
    m.guide.visible = true
    m.guide.active = true
    print "[player] minimized without retune"
end sub

sub expandPlayback()
    restorePicture()
    if m.playingChannel = invalid then return
    m.mini = false
    m.page = "player"
    m.miniFrame.visible = false
    m.guide.miniActive = false
    m.guide.active = false
    m.guide.visible = false
    m.screen.visible = false
    applyVideoLayout()
    focusPlaybackInput()
    m.userInfoOpen = false
    showChannelBanner(m.playingChannel, playerInfoHint())
    print "[player] expanded without retune"
end sub

function currentVideoAspect() as string
    if m.playingChannel = invalid then return ""
    if m.accountPreferences.videoAspects.doesExist(m.playingChannel.uuid) then return m.accountPreferences.videoAspects[m.playingChannel.uuid]
    return ""
end function

sub applyVideoLayout()
    m.video.allowOptionsKeyOverride = m.mini
    width = 1920.0
    height = 1080.0
    origin = [0, 0]
    if m.mini
        width = 400.0
        height = 225.0
        origin = [1424, 16]
    end if
    layout = videoGeometry(width, height, m.devicePreferences.videoScale, currentVideoAspect())
    m.videoViewport.translation = origin
    m.videoViewport.clippingRect = [0, 0, width, height]
    m.video.width = layout.width
    m.video.height = layout.height
    m.video.scale = layout.scale
    m.video.translation = layout.translation
end sub

sub onGuidePlayerRequest(event as object)
    if not m.guide.isSameNode(event.getRoSGNode()) then return
    if event.getData() = "searchMovies" or event.getData() = "searchSeries"
        kind = "movie"
        if event.getData() = "searchSeries" then kind = "series"
        openVodLibrary(kind)
        if m.page = "library" then m.vod.callFunc("openVodSearch")
        return
    end if
    if event.getData() = "settingsHub"
        openSettingsHub()
        return
    end if
    if event.getData() = "vodHome"
        if m.capabilities.movies = "allowed" then openVodLibrary("movie") else if m.capabilities.series = "allowed" then openVodLibrary("series")
        return
    end if
    if event.getData() = "toggleVod"
        m.accountPreferences.vodEnabled = m.accountPreferences.vodEnabled = false
        persistAccountPreferences()
        updateLibraryPermissions()
        return
    end if
    if event.getData() = "diagnostics"
        showDiagnostics()
        return
    end if
    if event.getData() = "movies" or event.getData() = "series"
        kind = "movie"
        if event.getData() = "series" then kind = "series"
        openVodLibrary(kind)
        return
    end if
    if event.getData() = "cancelPendingTune"
        cancelAacWait()
        showNotice("Pending channel tune cancelled.")
        return
    end if
    if event.getData() = "cancelSleep"
        cancelSleepTimer()
        return
    end if
    if event.getData() = "refreshChannels"
        refreshChannelLineup()
        return
    end if
    if event.getData() = "expandPlayer" then expandPlayback()
    if event.getData() = "stopPlayer" then stopPlayback()
    if event.getData() = "optionsPlayer"
        expandPlayback()
        openPlayerOptions()
    end if
end sub

sub openChannelBrowser(mode = "channels" as string)
    cancelPlayerOkHold()
    cancelHeldZap()
    if m.playingChannel = invalid then return
    m.channelTuneTimer.control = "stop"
    m.pendingChannel = invalid
    m.transport.active = false
    hideBanner()
    m.playerOptions.active = false
    model = m.guide.callFunc("playerBrowserData")
    model.mode = mode
    model.recent = m.accountPreferences.recent
    model.baseUrl = m.baseUrl
    model.apiKey = m.apiKey
    m.browser.playingUuid = m.playingChannel.uuid
    m.browser.model = model
    m.browser.active = true
end sub

sub onBrowserSelected(event as object)
    if m.page <> "player" then return
    m.browser.active = false
    startPlayback(event.getData())
end sub

sub onBrowserClosed()
    if m.page = "player" then focusPlaybackInput()
end sub

sub onBrowserInfoRequest(event as object)
    if not m.browser.active then return
    m.browser.nowTitles = m.guide.callFunc("browserNowTitles", event.getData())
end sub

sub zapPreviousChannel()
    if m.playingChannel = invalid then return
    id = previousWatched(m.accountPreferences, m.playingChannel.uuid)
    channel = m.guide.callFunc("channelByUuid", id)
    if channel = invalid
        showNotice("No previous channel is available in this account.")
        return
    end if
    startPlayback(channel)
end sub

sub onTransportAction(event as object)
    action = event.getData()
    if action = "play"
        togglePause()
    else if action = "channels"
        openChannelBrowser()
    else if action = "recent"
        openChannelBrowser("recent")
    else if action = "minimize"
        minimizePlayback()
    else if action = "options"
        openPlayerOptions()
    else if action = "stop"
        stopPlayback()
    end if
end sub

sub onTransportDismissed()
    hideBanner()
    if m.page = "player" then focusPlaybackInput()
end sub

sub onTransportInfoFocus()
    if m.page <> "player" then return
    m.transport.active = false
    m.transport.visible = true
    m.banner.visible = true
    m.userInfoOpen = true
    focusPlaybackInput()
    m.bannerTimer.control = "stop"
end sub

sub togglePause()
    if m.video.state = "paused"
        m.video.control = "resume"
    else if m.video.state = "playing"
        m.video.control = "pause"
    end if
end sub

sub openPlayerOptions(kind = "main" as string)
    cancelPlayerOkHold()
    cancelHeldZap()
    previousKind = m.optionKind
    previousFocus = m.playerOptions.focusedIndex
    m.optionKind = kind
    if kind <> "aspect" then m.pendingScale = ""
    m.transport.active = false
    m.browser.active = false
    m.channelTuneTimer.control = "stop"
    m.pendingChannel = invalid
    m.bannerTimer.control = "stop"
    hideBanner()
    title = "AerioTV player options"
    note = "Back returns to the parent menu."
    if kind = "main" then note = "Up/Down scroll all choices. Back returns to playback."
    items = [
        {title: "Audio track", action: "audioMenu"}
        {title: "Audio compatibility: " + m.devicePreferences.audioMode, action: "audioModeMenu"}
        {title: "Captions: " + m.video.globalCaptionMode, action: "captionsMenu"}
        {title: "Subtitle track", action: "subtitleMenu"}
        {title: "Stream Info", action: "streamInfo"}
        {title: "Video scale preference: " + m.devicePreferences.videoScale, action: "scaleMenu"}
        {title: "Channels", action: "channels"}
        {title: "Recently Watched", action: "recent"}
        {title: "Last channel", action: "last"}
        {title: "Minimize to guide", action: "minimize"}
        {title: "Hide picture (foreground listening)", action: "hidePicture"}
        {title: "Sleep timer: " + sleepTimerLabel(m.sleepDeadline, uiNow()), action: "sleepMenu"}
        {title: "Channel direction", action: "directionMenu"}
        {title: "Clock format: " + m.devicePreferences.clockFormat, action: "clockMenu"}
        {title: "Stop playback", action: "stop"}
        {title: "Close", action: "close"}
    ]
    if m.sleepDeadline > 0 then items.unshift({title: "Cancel sleep timer", action: "cancelSleep"})
    if m.playingChannel <> invalid and m.capabilities.catchup = "allowed"
        if catchupChannelDays(m.capabilities.catchup, m.channelFacts, textValue(m.playingChannel.id)) > 0 then items.unshift({title: "Rewind history (provider)", action: "rewindHistory"})
    end if
    if m.capabilities.switchStreams = "allowed"
        items.unshift({title: "Recover frozen picture (this player)", action: "recoverPicture"})
        items.unshift({title: "Switch stream source", action: "sourceMenu"})
    else if m.capabilities.switchStreams = "unknown"
        items.unshift({title: "Refresh source-switch permissions", action: "refreshCapabilities"})
    end if
    if kind = "clock"
        title = "Clock format"
        items = []
        for each mode in ["system", "12", "24"]
            items.push({title: mode, action: "clock", value: mode})
        end for
    else if kind = "audioMode"
        title = "Audio compatibility"
        note = "Auto retries missing audio once using an existing copy-video/AAC server output profile. Retunes this client only."
        items = []
        for each choice in [{value: "auto", title: "Automatic AAC fallback"}, {value: "direct", title: "Direct source audio"}, {value: "aac", title: "Always use AAC compatibility"}]
            label = choice.title
            if choice.value = m.devicePreferences.audioMode then label = "[Selected] " + label
            items.push({title: label, action: "audioMode", value: choice.value})
        end for
    else if kind = "scale"
        title = "Video scale"
        aspect = currentVideoAspect()
        note = "Source aspect for this channel: " + aspect + ". Transforms keep the same player session."
        if aspect = "" then note = "Source aspect unknown: using native Fit. Fill/Stretch require a per-channel aspect setting."
        items = []
        for each mode in ["fit", "fill", "stretch"]
            label = mode
            if mode = "fit" then label = "Fit — preserve native aspect"
            if mode = "fill" then label = "Fill — crop edges (preview)"
            if mode = "stretch" then label = "Stretch — distortion (preview)"
            if mode = m.devicePreferences.videoScale then label = "[Preferred] " + label
            items.push({title: label, action: "scale", value: mode})
        end for
        items.push({title: "Set this channel's source aspect", action: "aspectMenu"})
    else if kind = "aspect"
        title = "Source aspect for this channel"
        note = "Use the full encoded picture's aspect, including baked-in black bars. Saved only for this account/channel."
        items = [{title: "Automatic / unknown — native Fit", action: "aspect", value: ""}]
        for each aspect in ["4:3", "16:9", "21:9"]
            label = aspect
            if aspect = currentVideoAspect() then label = "[Selected] " + aspect
            items.push({title: label, action: "aspect", value: aspect})
        end for
    else if kind = "streamInfo"
        title = "Stream Info"
        note = "Native and server-reported snapshots. OK refreshes; Back returns to options."
        if m.serverStreamInfo = invalid then loadServerStreamInfo()
        if m.serverStreamMessage <> "" then note = m.serverStreamMessage
        snapshot = invalid
        if m.streamReady
            snapshot = {videoFormat: m.video.videoFormat, audioFormat: m.video.audioFormat, streamInfo: m.video.streamInfo, bufferingStatus: m.video.bufferingStatus, decoderStats: m.decoderSnapshot}
        end if
        facts = nativeStreamDetails(snapshot, m.apiKey)
        items = []
        for each entry in [{label: "Video codec", key: "video"}, {label: "Audio codec", key: "audio"}, {label: "Decoded resolution", key: "resolution"}, {label: "Frame rate", key: "frameRate"}, {label: "Stream bitrate", key: "bitrate"}, {label: "Network estimate", key: "network"}, {label: "Buffering progress", key: "buffering"}]
            items.push({title: entry.label + ": " + facts[entry.key], action: "streamInfo"})
        end for
        items.push({title: "State: " + m.video.state + "  |  Transport: MPEG-TS", action: "streamInfo"})
        for each entry in [{label: "Rendered frames", key: "rendered"}, {label: "Dropped frames", key: "dropped"}, {label: "Repeated frames", key: "repeated"}, {label: "Stream errors", key: "errors"}]
            items.push({title: entry.label + ": " + facts[entry.key], action: "streamInfo"})
        end for
        server = m.serverStreamInfo
        if server = invalid then server = serverStreamDetails(invalid)
        for each entry in [{label: "Server resolution", key: "resolution"}, {label: "Server source frame rate", key: "frameRate"}, {label: "Server video codec", key: "video"}, {label: "Server audio codec", key: "audio"}, {label: "Server pixel format", key: "pixels"}]
            items.push({title: entry.label + ": " + server[entry.key], action: "streamInfo"})
        end for
    else if kind = "sleep"
        title = "Sleep timer"
        items = []
        remaining = sleepTimerRemaining(m.sleepDeadline, uiNow())
        if remaining >= 0
            note = ((remaining + 59) \ 60).toStr() + " minutes remaining"
            items.push({title: "Cancel timer", action: "sleep", minutes: 0})
        else
            note = "Stops playback; continues across channel changes and mini-player."
        end if
        for each minutes in [30, 60, 90, 120]
            items.push({title: minutes.toStr() + " minutes", action: "sleep", minutes: minutes})
        end for
    else if kind = "direction"
        title = "Channel direction"
        note = "Saved device preference; full remote customization is tracked separately."
        items = []
        for each choice in [{value: "apple", title: "Up next / Down previous (Apple TV)"}, {value: "guide", title: "Up previous / Down next (guide order)"}]
            titleText = choice.title
            if choice.value = m.devicePreferences.channelDirection then titleText = "[Selected] " + titleText
            items.push({title: titleText, action: "direction", value: choice.value})
        end for
    else if kind = "audio"
        title = "Audio track"
        items = playbackTrackChoices(m.video.availableAudioTracks, "audio", m.video.audioTrack)
        if items.count() = 0 then items.push({title: "No audio tracks reported by this stream", action: "close"})
    else if kind = "subtitle"
        title = "Subtitle track"
        note = "Current caption mode: " + m.video.globalCaptionMode
        items = playbackTrackChoices(m.video.availableSubtitleTracks, "subtitle", m.video.subtitleTrack)
        if items.count() = 0 then items.push({title: "No subtitle tracks reported by this stream", action: "close"})
    else if kind = "captions"
        title = "Captions"
        note = "This changes Roku's system-wide caption mode."
        items = []
        for each mode in ["Off", "On", "Instant replay"]
            text = mode
            if mode = m.video.globalCaptionMode then text = "[Selected] " + mode
            items.push({title: text, action: "captions", mode: mode})
        end for
    end if
    focusIndex = 0
    if kind = "streamInfo" and previousKind = kind and previousFocus <> invalid then focusIndex = previousFocus
    if kind = "main"
        for i = 0 to items.count() - 1
            if items[i].action = m.optionReturnAction then focusIndex = i
        end for
    end if
    m.playerOptions.menu = {title: title, note: note, items: items, focusIndex: focusIndex}
    m.playerOptions.active = true
end sub

sub onPlayerOption(event as object)
    if m.page <> "player" then return
    item = event.getData()
    if m.optionKind = "main" then m.optionReturnAction = item.action
    if item.action = "rewindHistory"
        m.playerOptions.active = false
        onPlayerOptionsClosed()
        openLiveRewind()
        return
    end if
    if item.action = "clockMenu"
        openPlayerOptions("clock")
        return
    else if item.action = "clock"
        m.devicePreferences.clockFormat = item.value
        applyClockFormat()
        persistPreferences()
    else if item.action = "audioModeMenu"
        openPlayerOptions("audioMode")
        return
    else if item.action = "audioMode"
        if item.value = "aac" and m.aacProfile = invalid and m.aacDiscoveryState <> "pending"
            showNotice("No active copy-video/AAC output profile is available. Refresh the connection or choose Automatic/Direct.")
            return
        end if
        m.devicePreferences.audioMode = item.value
        persistPreferences()
        m.playerOptions.active = false
        startPlayback(m.playingChannel, true)
        return
    else if item.action = "scaleMenu"
        openPlayerOptions("scale")
        return
    else if item.action = "aspectMenu"
        openPlayerOptions("aspect")
        return
    else if item.action = "scale"
        if item.value <> "fit" and currentVideoAspect() = ""
            m.pendingScale = item.value
            openPlayerOptions("aspect")
            return
        end if
        m.devicePreferences.videoScale = item.value
        applyVideoLayout()
        persistPreferences()
    else if item.action = "aspect"
        id = m.playingChannel.uuid
        if item.value = ""
            m.accountPreferences.videoAspects.delete(id)
        else
            if not m.accountPreferences.videoAspects.doesExist(id) and m.accountPreferences.videoAspects.count() >= 100
                showNotice("The 100-channel aspect limit is reached. Clear an existing channel's aspect before adding another.")
                return
            end if
            m.accountPreferences.videoAspects[id] = item.value
            if m.pendingScale <> "" then m.devicePreferences.videoScale = m.pendingScale
        end if
        m.pendingScale = ""
        applyVideoLayout()
        persistAccountPreferences()
    else if item.action = "streamInfo"
        m.serverStreamInfo = invalid
        openPlayerOptions("streamInfo")
        return
    else if item.action = "sleepMenu"
        openPlayerOptions("sleep")
        return
    else if item.action = "directionMenu"
        openPlayerOptions("direction")
        return
    else if item.action = "sourceMenu"
        loadStreamSources()
        return
    else if item.action = "sourceSelect"
        m.optionKind = "sourceConfirm"
        note = "Shared upstream: affects ALL viewers (" + m.sourceClientCount.toStr() + " clients reported). Roku stays connected."
        m.playerOptions.menu = {title: "Switch shared stream source?", note: note, items: [{title: "Switch to " + item.title, action: "sourceConfirm", id: item.id}, {title: "Cancel", action: "sourceMenu"}]}
        return
    else if item.action = "sourceConfirm"
        beginSourceOperation("switch", item.id)
        return
    else if item.action = "audioMenu"
        openPlayerOptions("audio")
        return
    else if item.action = "subtitleMenu"
        openPlayerOptions("subtitle")
        return
    else if item.action = "captionsMenu"
        openPlayerOptions("captions")
        return
    else if item.action = "audio"
        m.video.audioTrack = item.track
    else if item.action = "subtitle"
        m.video.subtitleTrack = item.track
    else if item.action = "captions"
        m.video.globalCaptionMode = item.mode
    else if item.action = "sleep"
        m.sleepDeadline = 0
        if item.minutes > 0 then m.sleepDeadline = uiNow() + item.minutes * 60
        m.guide.sleepActive = m.sleepDeadline > 0
        if item.minutes = 0 then showNotice("Sleep timer cancelled.")
    else if item.action = "cancelSleep"
        cancelSleepTimer()
    else if item.action = "direction"
        m.devicePreferences.channelDirection = item.value
        persistPreferences()
    end if
    m.playerOptions.active = false
    onPlayerOptionsClosed()
    if item.action = "channels" then openChannelBrowser()
    if item.action = "recent" then openChannelBrowser("recent")
    if item.action = "last" then zapPreviousChannel()
    if item.action = "minimize" then minimizePlayback()
    if item.action = "stop" then stopPlayback()
    if item.action = "recoverPicture" then recoverFrozenPicture()
    if item.action = "hidePicture"
        hidePicture()
        ' LabelList selection can transfer focus during the initiating OK event.
        ' Consume that press/repeats/release before allowing a new wake gesture.
        m.pictureWakeKey = "OK"
    end if
    if item.action = "refreshCapabilities"
        refreshCapabilities()
        showNotice("Refreshing account permissions. Reopen player options shortly.")
    end if
end sub

sub cancelSourceOperation()
    m.sourceWatch.control = "stop"
    m.sourceWatchState = invalid
    m.recoveryContent = invalid
    m.recoveryPausePending = false
    if m.recoveryTask <> invalid
        m.recoveryTask.unobserveField("ready")
        m.recoveryTask.unobserveField("result")
        m.recoveryTask.release = true
        m.recoveryTask = invalid
    end if
    clearServerStreamInfo()
    if m.sourceTask <> invalid
        m.sourceTask.unobserveField("result")
        cancelNetworkTask(m.sourceTask)
        m.sourceTask = invalid
    end if
end sub

sub clearServerStreamInfo()
    if m.streamInfoTask <> invalid
        m.streamInfoTask.unobserveField("result")
        cancelNetworkTask(m.streamInfoTask)
        m.streamInfoTask = invalid
    end if
    m.serverStreamInfo = invalid
    m.serverStreamMessage = ""
end sub

sub loadServerStreamInfo()
    if m.streamInfoTask <> invalid or m.playingChannel = invalid then return
    if m.capabilities.switchStreams <> "allowed"
        m.serverStreamMessage = "Server diagnostics require verified Dispatcharr admin access. Native metrics remain available."
        m.serverStreamInfo = serverStreamDetails(invalid)
        return
    end if
    m.serverStreamMessage = "Loading server metadata; native facts remain available."
    m.streamInfoTask = CreateObject("roSGNode", "StreamInfoTask")
    m.streamInfoTask.baseUrl = m.baseUrl
    m.streamInfoTask.apiKey = m.apiKey
    m.streamInfoTask.channelUuid = m.playingChannel.uuid
    m.streamInfoTask.observeField("result", "onServerStreamInfo")
    m.streamInfoTask.control = "RUN"
end sub

sub onServerStreamInfo(event as object)
    if not isCurrentTaskEvent(event, m.streamInfoTask) then return
    result = event.getData()
    m.streamInfoTask.unobserveField("result")
    m.streamInfoTask = invalid
    if m.playingChannel = invalid then return
    if result.channelUuid <> m.playingChannel.uuid then return
    m.serverStreamInfo = result.details
    m.serverStreamMessage = "Server values describe upstream metadata, which may be cached. OK refreshes."
    if not result.ok then m.serverStreamMessage = "Server diagnostics unavailable. " + result.message
    if m.playerOptions.active and m.optionKind = "streamInfo" then openPlayerOptions("streamInfo")
end sub

sub loadStreamSources()
    beginSourceOperation("list", "")
end sub

sub beginSourceOperation(operation as string, streamId as string)
    if m.playingChannel = invalid or m.capabilities.switchStreams <> "allowed"
        showNotice("Stream source changes require verified admin permission.")
        return
    end if
    m.optionKind = "source"
    note = "Checking current permission and source state..."
    if operation = "switch" then note = "Switching shared source. Closing this menu does not undo the request."
    m.playerOptions.menu = {title: "Stream sources", note: note, items: [{title: "Close", action: "close"}]}
    m.playerOptions.active = true
    if m.sourceTask <> invalid then return
    if operation = "switch" then clearServerStreamInfo()
    m.sourceTask = CreateObject("roSGNode", "StreamSourceTask")
    m.sourceTask.baseUrl = m.baseUrl
    m.sourceTask.apiKey = m.apiKey
    m.sourceTask.accountId = m.serverAccountId
    m.sourceTask.channelId = m.playingChannel.id
    m.sourceTask.channelUuid = m.playingChannel.uuid
    m.sourceTask.streamId = streamId
    m.sourceTask.operation = operation
    m.sourceTask.observeField("result", "onSourceResult")
    m.sourceTask.control = "RUN"
end sub

sub onSourceResult(event as object)
    if not isCurrentTaskEvent(event, m.sourceTask) then return
    result = event.getData()
    m.sourceTask.unobserveField("result")
    m.sourceTask = invalid
    if m.playingChannel = invalid then return
    if result.channelUuid <> m.playingChannel.uuid then return
    if not result.ok
        showNotice(result.message)
        if m.playerOptions.active and m.playerOptions.menu.title = "Stream sources"
            m.playerOptions.menu = {title: "Stream sources", note: result.message, items: [{title: "Refresh", action: "sourceMenu"}, {title: "Close", action: "close"}]}
        end if
        return
    end if
    if result.operation = "switch"
        print "[source-switch] confirmed id="; result.streamId; " clients="; result.clientCountBefore; "->"; result.clientCountAfter
        continuity = result.continuity.state
        print "[source-switch] client identity snapshot="; continuity
        message = "Source changed. Server client continuity could not be verified."
        if continuity = "preserved" then message = "Source changed. All original clients are still listed by the server."
        if continuity = "changed" then message = "Source changed, but some original clients are no longer listed by the server."
        if result.unchanged = true then message = "This source is already active. No source-change request was sent."
        if result.unchanged <> true
            m.sourceWatchState = {content: m.video.content, previous: m.video.positionInfo, ticks: 0, stalls: 0}
            m.sourceWatch.control = "start"
        end if
        showNotice(message)
        clearServerStreamInfo()
        if m.playerOptions.active and m.optionKind = "streamInfo" then openPlayerOptions("streamInfo")
        if m.playerOptions.active and m.playerOptions.menu.title = "Stream sources" then loadStreamSources()
        return
    end if
    m.sourceChoices = result.choices
    m.sourceClientCount = result.clientCount
    items = []
    for each choice in result.choices
        items.push({title: choice.title + "  (#" + choice.id + ")", action: "sourceSelect", id: choice.id})
    end for
    if items.count() = 0 then items.push({title: "No sources returned", action: "close"})
    if m.playerOptions.active and m.playerOptions.menu.title = "Stream sources"
        m.playerOptions.menu = {title: "Stream sources", note: "Active = URL-confirmed. Reported active = server ID (may lag). Changes affect ALL viewers.", items: items}
    end if
end sub

sub onPlayerOptionsClosed()
    cancelPlayerOkHold()
    if m.page = "player" then focusPlaybackInput()
end sub

sub focusPlaybackInput()
    ' Give the Video override an actual input owner. The hidden Video cannot
    ' receive focus, so foreground listening uses the separate input Group.
    if m.pictureCover.visible
        m.playerInput.setFocus(true)
    else
        m.video.setFocus(true)
    end if
end sub

sub onNativePlayerKey(event as object)
    input = event.getData()
    onKeyEvent(input.key, input.press)
end sub

sub onPlayerOptionsBack()
    if m.page <> "player" then return
    if m.optionKind = "main"
        onPlayerOptionsClosed()
    else if m.optionKind = "aspect"
        openPlayerOptions("scale")
    else if m.optionKind = "sourceConfirm"
        loadStreamSources()
    else
        openPlayerOptions()
    end if
end sub

sub hidePicture()
    cancelPlayerOkHold()
    if m.playingChannel = invalid or m.mini then return
    if m.pictureCover.visible then return
    cancelHeldZap()
    m.channelTuneTimer.control = "stop"
    m.pendingChannel = invalid
    m.browser.active = false
    m.playerOptions.active = false
    m.transport.active = false
    hideBanner()
    m.bannerTimer.control = "stop"
    ' Opaque graphics alone do not suppress every device's hardware video plane.
    ' Visibility/caption suppression changes rendering, not the playback session.
    m.hiddenCaptionMode = m.video.suppressCaptions
    m.video.suppressCaptions = true
    m.video.alwaysShowVideoPlanes = false
    m.video.visible = false
    m.pictureCover.visible = true
    m.pictureHint.visible = true
    m.pictureHintTimer.control = "stop"
    m.pictureHintTimer.control = "start"
    focusPlaybackInput()
end sub

sub hidePictureHint()
    m.pictureHint.visible = false
end sub

sub restorePicture()
    m.pictureWakeKey = ""
    m.pictureHintTimer.control = "stop"
    wasHidden = m.pictureCover.visible
    if m.pictureCover.visible
        m.video.suppressCaptions = m.hiddenCaptionMode
        if m.playingChannel <> invalid then m.video.visible = true
    end if
    m.pictureCover.visible = false
    if wasHidden and m.page = "player" and m.playingChannel <> invalid then focusPlaybackInput()
end sub

sub onNativeVideoOptions(event as object)
    if not event.getData() or m.page <> "guide" then return
    if m.top.dialog <> invalid
        if not m.top.dialog.wasClosed then return
    end if
    m.guide.callFunc("handleOptionsShortcut")
end sub

sub onDecoderStats()
    if not m.streamReady then return
    stats = m.video.decoderStats
    if type(stats) <> "roAssociativeArray" then return
    if stats.count() = 0 then return
    m.decoderSnapshot = stats
    if m.decoderKeysReported then return
    ' Schema discovery only: no URLs, headers, or arbitrary native values logged.
    print "[decoder] available keys="; FormatJson(stats.keys())
    m.decoderKeysReported = true
end sub

sub onVideoState()
    if m.playingChannel = invalid then return
    if m.liveSession <> invalid then mediaObserve(m.liveSession, m.video.state, m.video.position, m.video.duration, invalid)
    if m.video.state = "playing" or m.video.state = "paused" then updateLivePresentation()
    if m.video.state <> "buffering" then m.liveBufferWatch = invalid
    if m.video.state = "playing" or m.video.state = "paused" then completeStartupWatch()
    if m.video.state = "playing" then m.streamReady = true
    m.transport.paused = m.video.state = "paused"
    print "[playback] state="; m.video.state
    recordDiagnostic("playback", 0, m.video.state)
    if m.pendingChannel = invalid then m.banner.playbackState = m.video.state
    if m.video.state = "error"
        code = m.video.errorCode
        ' Collect diagnostics before stop/content reset. Do not log media URLs.
        detail = m.video.errorStr
        if detail = "" then detail = m.video.errorMsg
        detail = sanitizePlaybackDiagnostic(detail, m.apiKey)
        print "[playback] code="; code; " detail="; detail
        recordDiagnostic("playback", code, detail)
        if m.pendingChannel <> invalid or m.heldZap <> "" then return
        if handleStartupFailure(code, detail) then return
        if retryInterruptedLive("error", code, detail) then return
        if m.startupWatch <> invalid and m.startupRetryCount > 0 then detail += chr(10) + "One startup retry was already attempted."
        failLivePlayback(code, detail)
    else if m.video.state = "finished"
        if m.pendingChannel <> invalid or m.heldZap <> "" then return
        if retryInterruptedLive("finished", 0, "") then return
        failLivePlayback(-1, "The live stream ended unexpectedly. Automatic recovery is unavailable or already used.")
    else if m.video.state = "buffering" or m.video.state = "paused"
        if m.pendingChannel = invalid and m.playingChannel <> invalid
            showChannelBanner(m.playingChannel, playerInfoHint())
            m.bannerTimer.control = "stop"
        end if
    else if m.video.state = "playing"
        if m.recoveryTask <> invalid and m.recoveryIssued then m.recoveryTask.release = true
        if m.recoveryPausePending
            m.recoveryPausePending = false
            m.video.control = "pause"
        end if
        m.audioCheck.control = "start"
        if m.playingChannel <> invalid
            if m.recordedChannel <> m.playingChannel.uuid
                m.accountPreferences = recordWatched(m.accountPreferences, m.playingChannel.uuid)
                m.guide.recentIds = m.accountPreferences.recent
                m.recordedChannel = m.playingChannel.uuid
                persistAccountPreferences()
            end if
        end if
        if m.banner.visible
            m.bannerTimer.control = "stop"
            if not m.transport.active and not m.userInfoOpen then m.bannerTimer.control = "start"
        end if
        if m.startMiniAfterPlayback
            m.startMiniAfterPlayback = false
            minimizePlayback()
        end if
    end if
end sub

sub checkSourceVideo()
    if m.sourceWatchState = invalid or m.playingChannel = invalid
        m.sourceWatch.control = "stop"
        return
    end if
    state = m.sourceWatchState
    if not state.content.isSameNode(m.video.content)
        m.sourceWatch.control = "stop"
        m.sourceWatchState = invalid
        return
    end if
    state.ticks++
    if m.video.state = "playing" and not m.pictureCover.visible
        if sourceVideoStalled(state.previous, m.video.positionInfo) then state.stalls++ else state.stalls = 0
    else
        state.stalls = 0
    end if
    state.previous = m.video.positionInfo
    if state.stalls >= 2
        m.sourceWatch.control = "stop"
        m.sourceWatchState = invalid
        recoverFrozenPicture()
    else if state.ticks >= 10
        m.sourceWatch.control = "stop"
        m.sourceWatchState = invalid
    end if
end sub

sub recoverFrozenPicture()
    if m.playingChannel = invalid or m.video.content = invalid or m.recoveryTask <> invalid then return
    m.sourceWatch.control = "stop"
    m.sourceWatchState = invalid
    m.recoveryContent = m.video.content
    m.recoveryPaused = m.video.state = "paused"
    m.recoveryIssued = false
    m.recoveryTask = CreateObject("roSGNode", "PlaybackBridgeTask")
    m.recoveryTask.url = m.video.content.url
    m.recoveryTask.baseUrl = m.baseUrl
    m.recoveryTask.channelUuid = m.playingChannel.uuid
    m.recoveryTask.apiKey = m.apiKey
    m.recoveryTask.observeField("ready", "onRecoveryReady")
    m.recoveryTask.observeField("result", "onRecoveryFinished")
    m.recoveryTask.control = "RUN"
    showNotice("Recovering this player's picture while retaining the shared source...")
end sub

sub onRecoveryReady(event as object)
    if not isCurrentTaskEvent(event, m.recoveryTask) then return
    if not event.getData() or not m.recoveryTask.ready or m.recoveryIssued then return
    if m.playingChannel = invalid then return
    if not m.recoveryContent.isSameNode(m.video.content) then return
    replacement = m.video.content.clone(false)
    m.recoveryIssued = true
    m.recoveryPausePending = m.recoveryPaused
    m.video.control = "stop"
    m.streamReady = false
    m.decoderSnapshot = {}
    m.video.content = replacement
    m.video.control = "play"
    print "[picture-recovery] local decoder restarted"
end sub

sub onRecoveryFinished(event as object)
    if not isCurrentTaskEvent(event, m.recoveryTask) then return
    result = event.getData()
    m.recoveryTask.unobserveField("ready")
    m.recoveryTask.unobserveField("result")
    m.recoveryTask = invalid
    m.recoveryContent = invalid
    if m.recoveryIssued
        print "[picture-recovery] source="; result.source; " clients="; result.beforeCount; "->"; result.afterCount
        message = "This player's decoder was restarted. No shared-source change was requested."
        if result.source = "same" then message = "This player's decoder restarted; the server reports the same upstream source."
        if result.source = "changed" then message = "Decoder restarted, but the server source changed. Refresh the source list."
        showNotice(message)
    else
        print "[picture-recovery] unavailable: "; result.message
        showNotice("Could not safely restart the decoder. " + result.message)
    end if
end sub

sub checkPlaybackAudio()
    if m.playingChannel = invalid or m.video.state <> "playing" then return
    if m.page = "setup" then return
    if m.activeAudioProfile <> ""
        if m.video.audioFormat <> "none" and m.video.audioFormat <> ""
            if m.devicePreferences.audioMode = "auto"
                known = false
                for each id in m.accountPreferences.aacChannels
                    if id = m.playingChannel.uuid then known = true
                end for
                if not known
                    m.accountPreferences.aacChannels.unshift(m.playingChannel.uuid)
                    m.accountPreferences.aacChannels = compactIds(m.accountPreferences.aacChannels, 100)
                    persistAccountPreferences()
                end if
            end if
        end if
        return
    end if
    if m.aacProfile = invalid then return
    if m.devicePreferences.audioMode <> "auto" and m.devicePreferences.audioMode <> "aac" then return
    if m.video.audioFormat = "none" or m.devicePreferences.audioMode = "aac"
        busy = m.playerOptions.active or m.browser.active or m.transport.active or m.pendingChannel <> invalid or m.heldZap <> ""
        if m.top.dialog <> invalid
            if not m.top.dialog.wasClosed then busy = true
        end if
        if busy
            m.audioCheck.control = "start"
            return
        end if
        wasMini = m.mini
        wasHidden = m.pictureCover.visible
        wasInfo = m.userInfoOpen
        channel = m.playingChannel
        showNotice("No native audio detected. Retrying this channel with AAC compatibility.")
        startPlayback(channel, true, true, true)
        if wasMini then minimizePlayback()
        if wasHidden then hidePicture()
        if wasInfo then togglePlayerInfo()
    end if
end sub

sub refreshChannelLineup()
    cancelAacWait()
    if m.refreshTask <> invalid then return
    showNotice("Refreshing authorized channels; current playback continues.")
    m.refreshTask = CreateObject("roSGNode", "DispatcharrTask")
    m.refreshTask.cacheEpoch = m.global.cacheEpoch
    m.refreshTask.baseUrl = m.baseUrl
    m.refreshTask.apiKey = m.apiKey
    m.refreshTask.observeField("result", "onLineupRefresh")
    m.refreshTask.control = "RUN"
end sub

sub onLineupRefresh(event as object)
    if not isCurrentTaskEvent(event, m.refreshTask) then return
    result = event.getData()
    m.refreshTask.unobserveField("result")
    m.refreshTask = invalid
    if not result.ok
        showNotice("Channel refresh failed: " + result.message)
        return
    end if
    if result.accountId <> m.serverAccountId
        showNotice("Account changed. Reconnect to load the new account.")
        return
    end if
    cancelPlaybackFailure()
    m.accountPreferences = reconcileWatchHistory(m.accountPreferences, result.channels)
    removedPlaying = false
    if m.playingChannel <> invalid
        current = invalid
        for each channel in result.channels
            if channel.uuid = m.playingChannel.uuid then current = channel
        end for
        if current = invalid
            removedPlaying = true
            stopPlayback()
        else
            m.playingChannel = current
            m.guide.playbackChannel = current
            m.banner.channel = current
            m.miniCaption.text = current.name
        end if
    end if
    result.preferences = m.accountPreferences
    m.guide.callFunc("applyRefreshedLineup", result)
    m.browser.callFunc("invalidateLogos")
    m.guide.recentIds = m.accountPreferences.recent
    persistAccountPreferences()
    showNotice("Channel lineup refreshed.")
    if removedPlaying then showNotice("The playing channel is no longer in the authorized lineup; playback stopped.")
end sub

sub checkReminders()
    if m.accountIdentity = "" then return
    result = reminderTick(m.accountPreferences.reminders, uiNow())
    if FormatJson(result.items) <> FormatJson(m.accountPreferences.reminders)
        m.accountPreferences.reminders = result.items
        m.guide.reminderState = result.items
        persistAccountPreferences()
    end if
    message = ""
    for each reminder in result.alerts
        if message <> "" then message += " | "
        message += reminder.title + " at " + uiTime(reminder.startsAt)
    end for
    if message <> "" then showNotice("Reminder: " + message)
end sub

sub closeMessage(event as object)
    event.getRoSGNode().close = true
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if key = "home" then return false
    if m.page = "archiveLoading" and key = "back" and press
        cancelArchiveLoad()
        releaseArchive()
        hideNotice()
        m.page = "guide"
        m.guide.active = true
        return true
    end if
    if key = m.heldZap and not press
        cancelHeldZap()
        m.channelTuneTimer.control = "stop"
        m.channelTuneTimer.control = "start"
        return true
    end if
    if press and m.heldZap <> ""
        if key = m.heldZap then return true
        cancelHeldZap()
        m.channelTuneTimer.control = "stop"
        m.pendingChannel = invalid
    end if
    ' A held wake key must not turn into a channel change after uncovering video.
    if m.pictureWakeKey <> "" and key = m.pictureWakeKey
        if not press then m.pictureWakeKey = ""
        return true
    end if
    if m.top.dialog <> invalid
        if not m.top.dialog.wasClosed then return false
    end if
    if handlePlayerOkKey(key, press) then return true
    if m.page = "player"
        if key = "back" and press and m.pendingAacTune <> invalid
            cancelAacWait()
            showNotice("Pending channel tune cancelled.")
            return true
        end if
    end if
    if not press then return false
    if m.page = "player"
        if key = "options" then return false
        if m.pictureCover.visible
            if key = "play"
                togglePause()
            else if key = "playonly"
                if m.video.state = "paused" then m.video.control = "resume"
            else
                restorePicture()
                m.pictureWakeKey = key
            end if
            return true
        end if
        if m.playerOptions.active or m.browser.active then return false
        if m.transport.active
            ' A key reaching the Scene instead of active controls means focus
            ' was displaced. Repair it and dispatch to the intended owner.
            enterPlayerControls()
            return m.transport.callFunc("handlePlayerKey", key, press)
        end if
        if key = "back"
            if m.userInfoOpen then hideBanner() else minimizePlayback()
            return true
        end if
        if key = "play"
            return handlePlayerMappedKey(key)
        else if key = "playonly"
            if m.video.state = "paused" then m.video.control = "resume"
            return true
        end if
        if key = "rewind"
            return handlePlayerMappedKey(key)
        end if
        if m.userInfoOpen
            if key = "down" or key = "up"
                enterPlayerControls()
            end if
            return true
        end if
        return handlePlayerMappedKey(key)
    end if
    if m.page <> "setup" then return false
    if m.busy
        if key = "back"
            failConnection("Connection cancelled.")
        end if
        return true
    end if
    if key = "up"
        if m.setupIndex > 0 then m.setupIndex--
    else if key = "down"
        if m.setupIndex < m.setupRows.count() - 1 then m.setupIndex++
    else if key = "left" or key = "right"
        if m.setupIndex < m.setupRows.count() - 2 then return false
        if key = "left" then m.setupIndex = m.setupRows.count() - 2 else m.setupIndex = m.setupRows.count() - 1
    else if key = "OK"
        editSetupField()
        return true
    else
        return false
    end if
    drawSetup()
    return true
end function

sub cancelHeldZap()
    m.heldZap = ""
    m.heldZapTimer.control = "stop"
end sub

sub cancelSleepTimer()
    m.sleepDeadline = 0
    m.guide.sleepActive = false
    showNotice("Sleep timer cancelled.")
end sub

sub repeatHeldZap()
    if m.page <> "player" or m.userInfoOpen or m.playerOptions.active or m.browser.active
        cancelHeldZap()
        return
    end if
    if m.heldZap = "" then return
    if m.heldZapClock.totalMilliseconds() >= 10000
        cancelHeldZap()
        commitChannelSwitch()
        return
    end if
    m.heldZapTimer.duration = 0.15
    queueChannelSwitch(m.heldZapDirection)
end sub

sub applyClockFormat()
    mode = m.devicePreferences.clockFormat
    if mode = "system"
        mode = "24"
        if CreateObject("roDeviceInfo").getClockFormat() = "12h" then mode = "12"
    end if
    m.global.clockFormat = mode
    m.global.clockPreference = m.devicePreferences.clockFormat
end sub

sub applyDevicePreferences()
    m.global.networkTimeoutMs = m.devicePreferences.networkTimeoutSeconds * 1000
    if m.capabilityClock <> invalid then m.capabilityClock.duration = m.devicePreferences.refreshSeconds
    if m.guide <> invalid then m.guide.remotePreferences = m.devicePreferences
    if m.banner <> invalid then m.banner.preferences = m.devicePreferences
end sub

sub onDevicePreference(event as object)
    change = event.getData()
    if change.tmdbKey <> invalid
        written = true
        if change.tmdbKey = ""
            if m.registry.read("tmdbApiKey") <> "" then written = m.registry.delete("tmdbApiKey")
        else
            written = m.registry.write("tmdbApiKey", change.tmdbKey)
        end if
        flushed = m.registry.flush()
        if not written or not flushed then showNotice("Could not persist the optional TMDB key.")
    end if
    if change.clockFormat <> invalid
        m.devicePreferences.clockFormat = change.clockFormat
        applyClockFormat()
        m.guide.callFunc("refreshPresentation")
        persistPreferences()
    end if
end sub
