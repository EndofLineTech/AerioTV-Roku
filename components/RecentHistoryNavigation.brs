' Scene-owned history edits; neither menu nor persistence retunes playback.
sub onRecentHistoryRequested(event as object)
    if m.accountIdentity = "" then return
    request = event.getData()
    if type(request) <> "roAssociativeArray" then return
    if request.account <> m.accountIdentity then return
    origin = ""
    if m.guide.isSameNode(event.getRoSGNode()) and m.guide.active then origin = "guide"
    if m.browser.isSameNode(event.getRoSGNode()) and m.browser.active then origin = "browser"
    if origin = "" then return
    if m.top.dialog <> invalid
        if m.top.dialog.wasClosed <> true then return
    end if
    closeRecentHistoryDialog()
    uuid = textValue(request.uuid)
    buttons = ["Cancel"]
    actions = ["cancel"]
    for each id in m.accountPreferences.recent
        if id = uuid
            buttons.push("Remove selected channel from history")
            actions.push("remove")
            exit for
        end if
    end for
    if m.accountPreferences.recent.count() > 0
        buttons.push("Clear all live Recently Watched")
        actions.push("clear")
    end if
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = "Manage Recently Watched"
    dialog.message = "Changes affect this account's live channel history and previous-channel recall. Playback and favorites are kept. Watching a channel again adds it back."
    if actions.count() = 1 then dialog.message = "There are no recently watched live channels in this account."
    dialog.buttons = buttons
    dialog.observeField("buttonSelected", "onRecentHistoryChoice")
    dialog.observeField("wasClosed", "onRecentHistoryClosed")
    m.historyContext = {account: m.accountIdentity, uuid: uuid, actions: actions, origin: origin}
    m.historyDialog = dialog
    m.top.dialog = dialog
end sub

sub onRecentHistoryChoice(event as object)
    if m.historyDialog = invalid or m.historyContext = invalid then return
    if not m.historyDialog.isSameNode(event.getRoSGNode()) then return
    context = m.historyContext
    index = event.getData()
    if index < 0 or index >= context.actions.count() then return
    action = context.actions[index]
    closeRecentHistoryDialog()
    if context.account <> m.accountIdentity or m.accountIdentity = "" then return
    if action <> "remove" and action <> "clear" then return
    m.accountPreferences = changeRecentHistory(m.accountPreferences, action, context.uuid)
    ' Standard persistence reports a session-only change when storage fails.
    persistAccountPreferences()
    m.guide.recentIds = m.accountPreferences.recent
    m.browser.recentIds = m.accountPreferences.recent
end sub

sub onRecentHistoryClosed(event as object)
    if event.getData() <> true or m.historyDialog = invalid then return
    if m.historyDialog.isSameNode(event.getRoSGNode()) then closeRecentHistoryDialog()
end sub

sub closeRecentHistoryDialog()
    if m.historyDialog = invalid then return
    context = m.historyContext
    m.historyDialog.unobserveField("buttonSelected")
    m.historyDialog.unobserveField("wasClosed")
    m.historyDialog.close = true
    m.historyDialog = invalid
    m.historyContext = invalid
    if context = invalid then return
    if context.account <> m.accountIdentity then return
    if context.origin = "browser" and m.browser.active = true then m.browser.setFocus(true)
    if context.origin = "guide" and m.guide.active = true then m.guide.setFocus(true)
end sub
