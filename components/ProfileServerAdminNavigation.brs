' Server administration has its own immutable session/root/UI lifetime.
function profileServerAdminHint() as boolean
    if m.profileBaselineReady <> true or m.activeUserScope = invalid then return false
    if not userProfileFullAccess(currentUserSettingsRole()) then return false
    store = loadUserProfileStore(m.registry, m.selectedConnectionId)
    if store.readOnly = true then return false
    base = false
    actor = false
    for each profile in store.profiles
        if profile.isDefault then base = profile.userLevel >= 10 and not profile.addressHeld
        if profile.id = store.active then actor = profile.userLevel >= 10 and profile.userId.toStr() = m.activeUserScope.accountId
    end for
    return base and actor
end function

function profileServerAdminCurrent() as boolean
    context = m.profileServerAdminContext
    if type(context) <> "roAssociativeArray" then return false
    if not profileServerAdminHint() or userProfileGateClosed() then return false
    if not userProfileSameSession(context.scope, m.activeUserScope) then return false
    if currentUserSessionId() <> context.scope.sessionId or context.page <> m.page then return false
    if context.connectionRoot <> m.registry.read("connectionsV1") then return false
    if context.storeRoot <> m.registry.read(userProfileStoreKey(m.selectedConnectionId)) then return false
    if context.adding
        if not profileOwnSignInContextCurrent() then return false
        if context.ownNonce <> m.profileOwnSignInNonce then return false
    end if
    return true
end function

sub beginProfileServerAdmin(targetId = "" as string)
    if not profileServerAdminHint() then return
    adding = targetId = ""
    if adding
        if not profileOwnSignInContextCurrent() then return
        if m.profileOwnSignInContext.adding <> true then return
        closeProfileOwnSignInDialog()
    end if
    retireProfileServerAdmin()
    entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    store = loadUserProfileStore(m.registry, m.selectedConnectionId)
    m.profileServerAdminContext = {nonce: CreateObject("roDeviceInfo").getRandomUUID(), scope: m.activeUserScope, page: m.page, connection: entry, store: store, connectionRoot: m.registry.read("connectionsV1"), storeRoot: m.registry.read(userProfileStoreKey(entry.id)), adding: adding, ownNonce: m.profileOwnSignInNonce, targetId: targetId, minted: {}, offset: 0, channelIds: []}
    operation = "list"
    if not adding
        for each profile in store.profiles
            if profile.id = targetId then m.profileServerAdminContext.target = {id: profile.userId, username: profile.username}
        end for
        operation = "choices"
    end if
    startProfileServerAdminTask(operation)
end sub

sub startProfileServerAdminTask(operation as string, confirmed = false as boolean)
    if not profileServerAdminCurrent() or m.profileServerAdminTask <> invalid then return
    context = m.profileServerAdminContext
    entry = context.connection
    base = invalid
    actor = invalid
    for each profile in context.store.profiles
        if profile.isDefault then base = profile
        if profile.id = context.store.active then actor = profile
    end for
    if base = invalid or actor = invalid then return
    selected = copyJson(context.store)
    selected.active = base.id
    memory = {}
    bucket = preferenceScope(entry.url + "|" + entry.id + "|" + base.id)
    if type(m.profileSessionKeys) = "roAssociativeArray"
        if m.profileSessionKeys.doesExist(bucket) then memory[connectionRegistryKey(entry.id)] = m.profileSessionKeys[bucket]
    end if
    if base.id = actor.id then memory[connectionRegistryKey(entry.id)] = m.apiKey
    credential = userProfileCredential(m.registry, entry, selected, memory)
    if not credential.ok then finishProfileServerAdminUi("Sign in to the base account before managing server users.") : return
    task = CreateObject("roSGNode", "ProfileServerAdminTask")
    tagTaskForCurrentUser(task)
    task.baseUrl = entry.url
    task.apiKey = m.apiKey
    task.baseKey = credential.key
    task.accountId = actor.userId.toStr()
    task.username = actor.username
    task.baseAccountId = base.userId.toStr()
    task.baseUsername = base.username
    task.role = currentUserSettingsRole()
    task.operation = operation
    task.confirmed = confirmed
    task.channelIds = context.channelIds
    if context.target <> invalid
        task.targetId = context.target.id.toStr()
        task.targetUsername = context.target.username
        if context.minted.doesExist(task.targetId) then task.minted = context.minted[task.targetId]
    end if
    task.observeField("result", "onProfileServerAdminResult")
    m.profileServerAdminTask = task
    context.operation = operation
    showProfileServerAdminDialog("Dispatcharr", "Checking current server permissions...", [{title: "Cancel", action: "cancel"}])
    task.control = "RUN"
end sub

sub onProfileServerAdminResult(event as object)
    if not isCurrentTaskEvent(event, m.profileServerAdminTask) then return
    result = event.getData()
    closeProfileServerAdminTask()
    if not profileServerAdminCurrent() then retireProfileServerAdmin() : return
    context = m.profileServerAdminContext
    if type(result) <> "roAssociativeArray" then finishProfileServerAdminUi("Could not read server users.") : return
    if result.ok <> true then finishProfileServerAdminUi(textValue(result.reason)) : return
    if context.operation = "list"
        suggestions = m.profileRosterSuggestions
        if type(suggestions) <> "roArray" then suggestions = []
        context.users = userProfileServerAdminCandidates(result.users, context.store.profiles, suggestions)
        showProfileServerAdminUsers()
    else if context.operation = "choices"
        context.target = result.target
        context.channelChoices = result.choices
        context.channelIds = []
        if type(result.target.channel_profiles) = "roArray" then context.channelIds = result.target.channel_profiles
        showProfileServerAdminChannels()
    else if context.operation = "generate"
        context.target.api_key = result.key
        context.minted[result.id.toStr()] = {id: result.id, username: result.username, key: result.key}
        showProfileServerAdminUser()
    else if context.operation = "revoke"
        context.target.api_key = ""
        context.minted.delete(result.id.toStr())
        showProfileServerAdminUser()
    else if context.operation = "channels"
        active = context.target.id.toStr() = context.scope.accountId
        retireProfileServerAdmin()
        if active
            m.suppressNextMiniAutoStart = true
            resetConnectionRuntime()
            connectServer(true)
        else
            showProfileManagementEditor(m.profileManagementTarget)
        end if
    end if
end sub

sub showProfileServerAdminUsers()
    context = m.profileServerAdminContext
    choices = []
    last = context.offset + 5
    if last >= context.users.count() then last = context.users.count() - 1
    for i = context.offset to last
        choices.push({title: context.users[i].username, action: "user", index: i})
    end for
    if last < context.users.count() - 1 then choices.push({title: "Next", action: "next"})
    if context.offset > 0 then choices.push({title: "Previous", action: "previous"})
    choices.push({title: "Enter details instead", action: "cancel"})
    showProfileServerAdminDialog("Add from Dispatcharr", "Choose an existing server user.", choices)
end sub

sub showProfileServerAdminUser()
    context = m.profileServerAdminContext
    target = context.target
    choices = []
    if not target.doesExist("api_key")
        choices.push({title: "Enter details instead", action: "cancel"})
    else if textValue(target.api_key) = ""
        choices.push({title: "Enable API access", action: "generate"})
    else
        choices.push({title: "Add Profile", action: "add"})
        if context.minted.doesExist(target.id.toStr()) then choices.push({title: "Revoke API access", action: "revoke-confirm"})
    end if
    choices.push({title: "Back", action: "users"})
    showProfileServerAdminDialog(target.username, "API access lets this user sign in with its own key.", choices)
end sub

sub showProfileServerAdminChannels()
    context = m.profileServerAdminContext
    allTitle = "All"
    if context.channelIds.count() = 0 then allTitle = "[x] All"
    choices = [{title: allTitle, action: "all"}]
    last = context.offset + 3
    if last >= context.channelChoices.count() then last = context.channelChoices.count() - 1
    for i = context.offset to last
        row = context.channelChoices[i]
        if userProfileUserId(row.id) <> invalid
            title = textValue(row.name)
            for each id in context.channelIds
                if id = row.id then title = "[x] " + title
            end for
            choices.push({title: title, action: "channel", id: row.id})
        end if
    end for
    if last < context.channelChoices.count() - 1 then choices.push({title: "Next", action: "channel-next"})
    if context.offset > 0 then choices.push({title: "Previous", action: "channel-previous"})
    choices.push({title: "Save", action: "channels"})
    choices.push({title: "Cancel", action: "cancel"})
    showProfileServerAdminDialog("Channel Profiles", "All means no server-side Channel Profile restriction.", choices)
end sub

sub showProfileServerAdminDialog(title as string, message as string, choices as object)
    closeProfileServerAdminDialog()
    dialog = CreateObject("roSGNode", "AerioDialog")
    dialog.title = title
    dialog.message = message
    buttons = []
    for each choice in choices
        buttons.push(choice.title)
    end for
    dialog.buttons = buttons
    dialog.observeField("buttonSelected", "onProfileServerAdminChoice")
    dialog.observeField("wasClosed", "onProfileServerAdminClosed")
    m.profileServerAdminDialog = dialog
    m.profileServerAdminChoices = choices
    m.top.dialog = dialog
    dialog.setFocus(true)
end sub

sub onProfileServerAdminChoice(event as object)
    if m.profileServerAdminDialog = invalid then return
    if not m.profileServerAdminDialog.isSameNode(event.getRoSGNode()) then return
    if not profileServerAdminCurrent() then retireProfileServerAdmin() : return
    index = event.getData()
    if not userProfileInteger(index) then return
    if index < 0 or index >= m.profileServerAdminChoices.count() then return
    choice = m.profileServerAdminChoices[index]
    closeProfileServerAdminDialog()
    context = m.profileServerAdminContext
    if choice.action = "cancel" then finishProfileServerAdminUi("") : return
    if m.profileServerAdminTask <> invalid then return
    if choice.action = "next"
        context.offset += 6
        showProfileServerAdminUsers()
    else if choice.action = "previous"
        context.offset -= 6
        showProfileServerAdminUsers()
    else if choice.action = "user"
        context.target = context.users[choice.index]
        showProfileServerAdminUser()
    else if choice.action = "users"
        showProfileServerAdminUsers()
    else if choice.action = "generate"
        startProfileServerAdminTask("generate")
    else if choice.action = "revoke-confirm"
        showProfileServerAdminDialog("Revoke API access?", context.target.username + " will be signed out on every device that uses this key.", [{title: "Revoke", action: "revoke"}, {title: "Cancel", action: "user-return"}])
    else if choice.action = "revoke"
        startProfileServerAdminTask("revoke", true)
    else if choice.action = "user-return"
        showProfileServerAdminUser()
    else if choice.action = "all"
        context.channelIds = []
        showProfileServerAdminChannels()
    else if choice.action = "channel-next"
        context.offset += 4
        showProfileServerAdminChannels()
    else if choice.action = "channel-previous"
        context.offset -= 4
        showProfileServerAdminChannels()
    else if choice.action = "channel"
        nextIds = []
        found = false
        for each id in context.channelIds
            if id = choice.id then found = true else nextIds.push(id)
        end for
        if not found then nextIds.push(choice.id)
        context.channelIds = nextIds
        showProfileServerAdminChannels()
    else if choice.action = "channels"
        startProfileServerAdminTask("channels", true)
    else if choice.action = "add"
        target = {id: context.target.id, username: context.target.username, api_key: context.target.api_key}
        retireProfileServerAdmin()
        if not profileOwnSignInContextCurrent() then return
        m.profileOwnSignInContext.username = target.username
        task = CreateObject("roSGNode", "DispatcharrTask")
        tagTaskForCurrentUser(task)
        task.baseUrl = m.profileOwnSignInContext.connection.url
        task.apiKey = target.api_key
        task.verifyOnly = true
        task.expectedUserId = target.id.toStr()
        task.expectedUsername = target.username
        task.observeField("result", "onProfileOwnSignInResult")
        task.observeField("state", "onProfileOwnSignInState")
        m.profileOwnSignInTask = task
        showProfileOwnSignInForm("Verifying this user's own access...")
        task.control = "RUN"
    end if
end sub

sub finishProfileServerAdminUi(message as string)
    context = m.profileServerAdminContext
    retireProfileServerAdmin()
    if context = invalid then return
    if context.adding
        if profileOwnSignInContextCurrent() then showProfileOwnSignInForm(message)
    else
        showProfileManagementEditor(context.targetId)
        if message <> "" then showNotice(message)
    end if
end sub

sub onProfileServerAdminClosed(event as object)
    if m.profileServerAdminDialog = invalid then return
    if not m.profileServerAdminDialog.isSameNode(event.getRoSGNode()) then return
    finishProfileServerAdminUi("")
end sub

sub closeProfileServerAdminDialog()
    dialog = m.profileServerAdminDialog
    m.profileServerAdminDialog = invalid
    if dialog = invalid then return
    dialog.unobserveField("buttonSelected")
    dialog.unobserveField("wasClosed")
    dialog.close = true
    if m.top.dialog <> invalid
        if m.top.dialog.isSameNode(dialog) then m.top.dialog = invalid
    end if
end sub

sub closeProfileServerAdminTask()
    task = m.profileServerAdminTask
    m.profileServerAdminTask = invalid
    if task = invalid then return
    task.unobserveField("result")
    task.apiKey = ""
    task.baseKey = ""
    task.minted = invalid
    task.result = invalid
    cancelNetworkTask(task)
end sub

sub retireProfileServerAdmin()
    closeProfileServerAdminDialog()
    closeProfileServerAdminTask()
    context = m.profileServerAdminContext
    if type(context) = "roAssociativeArray"
        if type(context.users) = "roArray"
            for each user in context.users
                if type(user) = "roAssociativeArray" then user.api_key = ""
            end for
        end if
        if type(context.target) = "roAssociativeArray" then context.target.api_key = ""
        if type(context.minted) = "roAssociativeArray"
            for each id in context.minted
                context.minted[id].key = ""
            end for
        end if
    end if
    m.profileServerAdminContext = invalid
    m.profileServerAdminChoices = []
end sub
