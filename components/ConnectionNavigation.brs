' Named Dispatcharr connections. Only bounded, non-secret metadata is stored
' in connectionsV1; a saved API key has its own registry entry per slot.
function storedConnectionKey(registry as object, entry as object) as string
    if entry.remember <> true then return ""
    key = registry.read(connectionRegistryKey(entry.id))
    if key = "" and entry.id = "legacy" then key = registry.read("apiKey")
    return key
end function

function legacyConnectionPreferencesMatch(registry as object, baseUrl as string, accountId as string) as boolean
    ' The old unscoped preferences value belongs only to its original server
    ' and verified account. Editing the legacy slot's URL must not import it.
    return normalizeBaseUrl(registry.read("serverUrl")) = baseUrl and registry.read("accountIdentity") = baseUrl + "|" + accountId
end function

function deleteStoredConnectionKey(entry as object) as boolean
    keyName = connectionRegistryKey(entry.id)
    if keyName = "" then return false
    removed = true
    if m.registry.read(keyName) <> "" then removed = m.registry.delete(keyName)
    if entry.id = "legacy" and m.registry.read("apiKey") <> "" then removed = m.registry.delete("apiKey") and removed
    return m.registry.flush() and removed
end function

sub applySelectedConnection()
    entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    m.baseUrl = ""
    m.guideUrl = ""
    m.remember = false
    m.apiKey = ""
    if entry <> invalid
        m.baseUrl = entry.url
        m.guideUrl = entry.epgUrl
        m.remember = entry.remember
        m.apiKey = storedConnectionKey(m.registry, entry)
    end if
    m.username = ""
    m.password = ""
    m.authMode = "key"
    m.xcUsername = ""
    m.xcPassword = ""
end sub

sub updateConnectionGuideUrl(url as string)
    entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    if entry = invalid or entry.provider <> "m3u" then return
    if entry.epgUrl = url then return
    updated = connectionStoreUpdate(m.connectionStore, entry.id, {epgUrl: url})
    if updated = invalid or not saveConnectionStore(m.registry, updated)
        m.status = "Could not save this connection's XMLTV URL."
        return
    end if
    resetConnectionRuntime()
    m.connectionStore = updated
    applySelectedConnection()
    m.status = "Guide URL updated. Connect to load this playlist's guide."
end sub

function rememberConnectedAccount(accountId as string) as boolean
    entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    if entry = invalid then return false
    keyName = connectionRegistryKey(entry.id)
    ' A different verified account must never inherit the previous account's
    ' remembered key, even if a later registry write or flush fails.
    if entry.accountId <> "" and entry.accountId <> accountId
        if not deleteStoredConnectionKey(entry) then return false
    end if
    if m.remember
        if not m.registry.write(keyName, m.apiKey) or not m.registry.flush()
            deleteStoredConnectionKey(entry)
            return false
        end if
    else if not deleteStoredConnectionKey(entry)
        return false
    end if
    updated = connectionStoreUpdate(m.connectionStore, entry.id, {accountId: accountId, remember: m.remember})
    if updated = invalid or not saveConnectionStore(m.registry, updated)
        if m.remember then deleteStoredConnectionKey(entry)
        return false
    end if
    m.connectionStore = updated
    if entry.id = "legacy"
        ' Only drop the prior single-slot values after the roster and new key
        ' were safely saved. A failed cleanup remains a same-origin fallback.
        m.registry.delete("serverUrl")
        m.registry.delete("accountIdentity")
        if m.remember then m.registry.delete("apiKey")
        m.registry.flush()
    end if
    return true
end function

sub changeConnectionRemember(remember as boolean)
    entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    if entry = invalid then return
    if not remember and not deleteStoredConnectionKey(entry)
        showNotice("Could not remove this connection's saved key; Remember is unchanged.")
        return
    end if
    updated = connectionStoreUpdate(m.connectionStore, entry.id, {remember: remember})
    if updated = invalid or not saveConnectionStore(m.registry, updated)
        showNotice("Could not save this connection's Remember choice.")
        return
    end if
    m.connectionStore = updated
    m.remember = remember
    if remember and m.apiKey <> "" and entry.accountId = m.serverAccountId and m.serverAccountId <> ""
        if not m.registry.write(connectionRegistryKey(entry.id), m.apiKey) or not m.registry.flush()
            showNotice("Remember is selected, but the verified key could not be saved. Reconnect before exiting.")
        end if
    end if
end sub

sub updateConnectionUrl(base as string)
    entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    if entry = invalid
        candidate = connectionStoreAdd(m.connectionStore, CreateObject("roDeviceInfo").getRandomUUID(), "Main")
        if candidate = invalid or not saveConnectionStore(m.registry, candidate)
            m.status = "Could not add the first connection. Check Roku app storage."
            return
        end if
        m.connectionStore = candidate
        m.selectedConnectionId = candidate.selected
        entry = connectionStoreEntry(candidate, candidate.selected)
    end if
    if entry.url = base
        m.baseUrl = base
        return
    end if
    ' Delete the old key FIRST. A failed metadata write can require re-login,
    ' but must never send that key to a different server after relaunch.
    if not deleteStoredConnectionKey(entry)
        m.status = "Could not remove the old server's key. URL was not changed."
        return
    end if
    updated = connectionStoreUpdate(m.connectionStore, entry.id, {url: base})
    if updated = invalid or not saveConnectionStore(m.registry, updated)
        m.apiKey = ""
        m.status = "Could not save the new URL. Re-enter credentials before connecting."
        return
    end if
    resetConnectionRuntime()
    m.connectionStore = updated
    m.selectedConnectionId = updated.selected
    applySelectedConnection()
    m.status = "Server URL updated; old credentials were removed. Sign in to verify the new server."
    if entry.provider = "m3u" then m.status = "M3U URL updated. Connect to load this playlist."
end sub

sub resetConnectionRuntime()
    cancelRecordFlow()
    cancelDvrPlayback()
    cancelPlaybackFailure()
    cancelCapabilityRefresh()
    m.reminderClock.control = "stop"
    if m.playingChannel <> invalid then stopPlayback()
    resetMediaNavigation()
    m.dvr.active = false
    m.dvr.config = invalid
    m.guide.active = false
    m.guide.callFunc("cancelMetadataLoads")
    m.guide.config = invalid
    for each field in ["archiveRequest", "recordRequest", "metadataEvent", "watchChannel", "exitRequested", "preferences", "playbackInfo", "playerRequest", "devicePreference"]
        m.guide.unobserveField(field)
    end for
    m.top.removeChild(m.guide)
    m.guide = CreateObject("roSGNode", "GuideView")
    m.guide.observeField("archiveRequest", "onArchiveRequested")
    m.guide.observeField("recordRequest", "onRecordRequested")
    m.guide.observeField("metadataEvent", "onMetadataDiagnostic")
    m.guide.observeField("watchChannel", "onWatchChannel")
    m.guide.observeField("exitRequested", "showConnection")
    m.guide.observeField("preferences", "onPreferences")
    m.guide.observeField("playbackInfo", "onPlaybackInfo")
    m.guide.observeField("playerRequest", "onGuidePlayerRequest")
    m.guide.observeField("devicePreference", "onDevicePreference")
    m.guide.visible = false
    m.top.insertChild(m.guide, 1)
    m.browser.callFunc("invalidateLogos")
    m.banner.session = invalid
    m.banner.channel = invalid
    m.banner.info = invalid
    m.global.cacheEpoch = CreateObject("roDeviceInfo").getRandomUUID()
    m.capabilities = normalizeCapabilities(invalid, invalid, invalid, 0)
    m.channelFacts = {}
    m.accountIdentity = ""
    m.serverAccountId = ""
    m.accountPreferences = normalizeAccountPreferences(invalid)
    m.apiKey = ""
    m.guideUrl = ""
    m.password = ""
    m.username = ""
    m.xcUsername = ""
    m.xcPassword = ""
    m.page = "setup"
    m.screen.visible = true
    m.top.setFocus(true)
end sub

sub requireConnectionRelogin(message as string)
    entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    removed = true
    if entry <> invalid then removed = deleteStoredConnectionKey(entry)
    resetConnectionRuntime()
    applySelectedConnection()
    ' A failed registry deletion cannot reauthorize this session via the old
    ' in-memory key, even if the app registry still needs manual cleanup.
    m.apiKey = ""
    m.authMode = "key"
    m.status = message + " Sign in again to verify this connection."
    if not removed then m.status += " The saved key could not be removed; retry Forget before relaunching."
    drawSetup()
end sub

sub completeDirectConnection(result as object, entry as object, xcUsername = "" as string, xcPassword = "" as string)
    if result.channels.count() = 0
        m.status = "This connection contains no supported live channels."
        drawSetup()
        return
    end if
    resetConnectionRuntime()
    applySelectedConnection()
    m.startMiniAfterPlayback = false
    m.xcUsername = xcUsername
    m.xcPassword = xcPassword
    if entry.provider = "xtream" then m.guideUrl = result.guideUrl
    m.accountIdentity = connectionPreferenceIdentity(entry, result.accountId)
    m.accountPreferences = reconcileWatchHistory(accountPreferences(m.preferenceStore, m.accountIdentity), result.channels)
    persistAccountPreferences()
    m.capabilities.movies = "denied"
    m.capabilities.series = "denied"
    m.capabilities.catchup = "denied"
    m.capabilities.dvr = "none"
    m.capabilities.switchStreams = "denied"
    m.guide.config = {
        channels: result.channels, groups: result.groups, warning: result.warning
        baseUrl: urlOrigin(m.baseUrl), apiKey: "", providerType: entry.provider, guideUrl: m.guideUrl
        preferences: m.accountPreferences, tmdbKey: ""
        scope: result.scope, generation: result.generation
    }
    m.guide.catchupPermission = "denied"
    m.guide.dvrPermission = "none"
    m.banner.session = {baseUrl: urlOrigin(m.baseUrl), apiKey: ""}
    m.banner.preferences = m.devicePreferences
    m.guide.remotePreferences = m.devicePreferences
    m.page = "guide"
    m.screen.visible = false
    m.guide.visible = true
    m.guide.active = true
    updateLibraryPermissions()
    m.reminderClock.control = "start"
    recordDiagnostic("connect", 0, "Direct live lineup ready", m.connectionElapsed.totalMilliseconds())
    print "[direct-live] normalized lineup channels="; result.channels.count()
end sub

sub openConnectionPicker()
    if m.busy or m.connectionDialog <> invalid then return
    if m.connectionStore.readOnly = true
        showNotice("Saved connections use an unsupported newer format. Do not overwrite them on this build.")
        return
    end if
    choices = []
    for each entry in m.connectionStore.entries
        title = entry.name
        if entry.id = m.selectedConnectionId then title = "[Selected] " + title
        choices.push({title: title, action: "select", id: entry.id})
    end for
    choices.push({title: "Manage saved connections", action: "manage"})
    choices.push({title: "Back to setup", action: "cancel"})
    openConnectionDialog("Select Dispatcharr connection", "Keys and viewing preferences stay in each connection's account scope.", choices)
end sub

sub openConnectionManager()
    choices = [{title: "Add Dispatcharr connection (session-only)", action: "add"}, {title: "Add direct M3U and XMLTV connection", action: "addM3u"}, {title: "Add Xtream Codes connection (session-only)", action: "addXtream"}]
    if m.selectedConnectionId <> ""
        choices.push({title: "Rename selected connection", action: "rename"})
        choices.push({title: "Move selected up", action: "move", direction: -1})
        choices.push({title: "Move selected down", action: "move", direction: 1})
        choices.push({title: "Forget selected connection", action: "forget"})
    end if
    choices.push({title: "Back", action: "cancel"})
    openConnectionDialog("Manage saved connections", "At most four. Forget affects only the selected connection.", choices)
end sub

sub openConnectionDialog(title as string, message as string, choices as object)
    closeConnectionDialog()
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = title
    dialog.message = message
    labels = []
    for each choice in choices
        labels.push(choice.title)
    end for
    dialog.buttons = labels
    dialog.observeField("buttonSelected", "onConnectionChoice")
    dialog.observeField("wasClosed", "onConnectionDialogClosed")
    m.connectionChoices = choices
    m.connectionDialog = dialog
    m.top.dialog = dialog
end sub

sub closeConnectionDialog()
    if m.connectionDialog = invalid then return
    m.connectionDialog.unobserveField("buttonSelected")
    m.connectionDialog.unobserveField("wasClosed")
    m.connectionDialog.close = true
    m.connectionDialog = invalid
end sub

sub onConnectionDialogClosed(event as object)
    if m.connectionDialog = invalid or not m.connectionDialog.isSameNode(event.getRoSGNode()) then return
    closeConnectionDialog()
    if m.page = "setup" then m.top.setFocus(true)
end sub

sub onConnectionChoice(event as object)
    if m.connectionDialog = invalid or not m.connectionDialog.isSameNode(event.getRoSGNode()) then return
    index = event.getData()
    if index < 0 or index >= m.connectionChoices.count() then return
    choice = m.connectionChoices[index]
    closeConnectionDialog()
    if choice.action = "select"
        switchSavedConnection(choice.id)
    else if choice.action = "manage"
        openConnectionManager()
    else if choice.action = "add"
        addSavedConnection()
    else if choice.action = "addM3u"
        addSavedConnection("m3u")
    else if choice.action = "addXtream"
        addSavedConnection("xtream")
    else if choice.action = "rename"
        openConnectionRename()
    else if choice.action = "move"
        moved = connectionStoreMove(m.connectionStore, m.selectedConnectionId, choice.direction)
        if moved <> invalid and saveConnectionStore(m.registry, moved) then m.connectionStore = moved else showNotice("Could not reorder saved connections.")
        drawSetup()
    else if choice.action = "forget"
        openRemoveConnectionConfirmation()
    else if choice.action = "remove"
        removeSelectedConnection()
    end if
    if m.page = "setup" and m.connectionDialog = invalid then m.top.setFocus(true)
end sub

sub switchSavedConnection(id as string)
    if id = m.selectedConnectionId then return
    updated = connectionStoreSelect(m.connectionStore, id)
    if updated = invalid or not saveConnectionStore(m.registry, updated)
        showNotice("Could not select the saved connection.")
        return
    end if
    resetConnectionRuntime()
    m.connectionStore = updated
    m.selectedConnectionId = id
    applySelectedConnection()
    m.status = "Selected connection: " + connectionStoreEntry(updated, id).name + "."
    drawSetup()
    if m.baseUrl <> "" and m.apiKey <> "" then connectServer()
end sub

sub addSavedConnection(provider = "dispatcharr" as string)
    name = "Connection " + (m.connectionStore.entries.count() + 1).toStr()
    if provider = "m3u" then name = "M3U " + (m.connectionStore.entries.count() + 1).toStr()
    if provider = "xtream" then name = "Xtream " + (m.connectionStore.entries.count() + 1).toStr()
    candidate = connectionStoreAdd(m.connectionStore, CreateObject("roDeviceInfo").getRandomUUID(), name, provider)
    if candidate = invalid or not saveConnectionStore(m.registry, candidate)
        showNotice("At most four connections are supported, or app storage is unavailable.")
        return
    end if
    resetConnectionRuntime()
    m.connectionStore = candidate
    m.selectedConnectionId = candidate.selected
    applySelectedConnection()
    m.status = "New session-only connection. Enter a server URL and sign-in credentials."
    if provider = "m3u" then m.status = "Direct M3U connection. Enter playlist and optional XMLTV URLs."
    if provider = "xtream" then m.status = "Xtream connection. Enter its Dispatcharr URL and session-only credentials."
    drawSetup()
end sub

sub openConnectionRename()
    entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    if entry = invalid then return
    dialog = CreateObject("roSGNode", "KeyboardDialog")
    dialog.title = "Rename connection"
    dialog.text = entry.name
    dialog.buttons = ["Save name", "Cancel"]
    dialog.observeField("buttonSelected", "onConnectionRenamed")
    dialog.observeField("wasClosed", "onConnectionDialogClosed")
    m.connectionDialog = dialog
    m.top.dialog = dialog
end sub

sub onConnectionRenamed(event as object)
    if m.connectionDialog = invalid or not m.connectionDialog.isSameNode(event.getRoSGNode()) then return
    if event.getData() = 0
        renamed = connectionStoreRename(m.connectionStore, m.selectedConnectionId, m.connectionDialog.text)
        if renamed = invalid or not saveConnectionStore(m.registry, renamed)
            showNotice("Invalid name or app storage unavailable; the existing name was retained.")
        else
            m.connectionStore = renamed
        end if
    end if
    closeConnectionDialog()
    drawSetup()
    m.top.setFocus(true)
end sub

sub openRemoveConnectionConfirmation()
    entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    if entry = invalid
        showNotice("No selected connection to remove.")
        return
    end if
    openConnectionDialog("Forget " + entry.name + "?", "This removes this Roku's saved key and account preferences for this connection. Other connections stay saved.", [{title: "Keep connection", action: "cancel"}, {title: "Forget selected connection", action: "remove"}])
end sub

sub removeSelectedConnection()
    entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    if entry = invalid then return
    updated = connectionStoreRemove(m.connectionStore, entry.id)
    if updated = invalid then return
    oldIdentity = connectionPreferenceIdentity(entry, entry.accountId)
    prior = copyJson(m.preferenceStore)
    if oldIdentity <> "" then m.preferenceStore.accounts.delete(preferenceScope(oldIdentity))
    if entry.id = "legacy"
        legacyId = entry.url + "|" + entry.accountId
        if entry.accountId <> "" then m.preferenceStore.accounts.delete(preferenceScope(legacyId))
    end if
    if not persistPreferences()
        m.preferenceStore = prior
        return
    end if
    if not deleteStoredConnectionKey(entry)
        showNotice("Could not confirm saved-key removal. Retry Forget before exiting.")
        return
    end if
    if not saveConnectionStore(m.registry, updated)
        showNotice("Saved key was removed, but the roster could not be updated. Retry Forget before exiting.")
        return
    end if
    if entry.id = "legacy"
        for each key in ["serverUrl", "apiKey", "accountIdentity", "preferences"]
            m.registry.delete(key)
        end for
        m.registry.flush()
    end if
    m.metadataForgetTask = m.guide.callFunc("forgetStoredMetadata")
    resetConnectionRuntime()
    m.connectionStore = updated
    m.selectedConnectionId = updated.selected
    applySelectedConnection()
    m.status = "Selected connection, saved key and its account preferences removed."
    drawSetup()
end sub
