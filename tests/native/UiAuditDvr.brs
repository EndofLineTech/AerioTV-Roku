' Uses production config/active/read callbacks, PosterGrid and action dialogs.
sub seedUiAuditDvr(scenario as string)
    permission = "manage"
    if scenario = "dvr-view" then permission = "view"
    m.top.config = {baseUrl: "https://example.invalid", apiKey: "", accountId: "fixture", scope: "ui-audit", permission: permission
        channels: [{id: "1", number: "1", name: "Synthetic Channel", logoId: ""}]}
    m.top.active = true
end sub

function uiAuditLibraryState() as object
    identity = ""
    index = m.list.itemFocused
    if index >= 0 and index < m.focusRows.count() then identity = dvrRowIdentity(m.focusRows[index])
    state = {focused: index, identity: identity, loaded: m.focusRows.count(), status: m.status.text, shelf: m.shelfLabel.text, loading: m.task <> invalid
        dialog: "", buttons: [], closed: m.top.closed, playRequested: m.top.playRequested <> invalid}
    if m.dialog <> invalid
        state.dialog = m.dialog.subtype()
        state.buttons = m.dialog.buttons
        state.dialogFocused = m.dialog.buttonFocused
    end if
    return state
end function
