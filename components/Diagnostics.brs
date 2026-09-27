sub recordDiagnostic(stage as string, code as integer, message as string, elapsedMs = 0 as integer)
    if m.diagnosticLog = invalid then m.diagnosticLog = []
    scope = textValue(m.accountIdentity)
    if m.diagnosticShareDialog <> invalid and m.diagnosticShareScope <> scope then cancelDiagnosticShare()
    m.diagnosticLog.push({stage: stage, code: code, message: message, time: uiNow(), elapsedMs: elapsedMs, scope: scope})
    m.diagnosticLog = diagnosticEvents(m.diagnosticLog, uiNow(), m.apiKey, scope)
end sub

sub showDiagnostics()
    m.diagnosticLog = diagnosticEvents(m.diagnosticLog, uiNow(), m.apiKey, textValue(m.accountIdentity))
    if m.diagnosticOffset = invalid then m.diagnosticOffset = 0
    if m.diagnosticOffset >= m.diagnosticLog.count() then m.diagnosticOffset = 0
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = "Diagnostics — this app session (last hour)"
    message = "No current events. Older events expire; logs are not retained across app exit."
    if m.diagnosticLog.count() > 0
        message = ""
        last = m.diagnosticLog.count() - 1 - m.diagnosticOffset
        for i = last to last - 5 step -1
            if i < 0 then exit for
            event = m.diagnosticLog[i]
            message += uiTime(event.time) + " " + event.stage + " [" + event.code.toStr() + "] " + event.elapsedMs.toStr() + "ms " + left(event.message, 100) + chr(10)
        end for
    end if
    dialog.message = message
    dialog.buttons = ["Older", "Newer", "Clear", "Show support code", "Export to Roku console", "Close"]
    dialog.observeField("buttonSelected", "onDiagnosticAction")
    dialog.observeField("wasClosed", "onDiagnosticClosed")
    m.diagnosticDialog = dialog
    m.top.dialog = dialog
end sub

sub onDiagnosticAction(event as object)
    if not isCurrentTaskEvent(event, m.diagnosticDialog) then return
    choice = event.getData()
    m.diagnosticDialog.close = true
    if choice = 0 then m.diagnosticOffset += 6
    if choice = 1 then m.diagnosticOffset -= 6
    if m.diagnosticOffset < 0 then m.diagnosticOffset = 0
    if choice = 2
        m.diagnosticLog = []
        m.diagnosticOffset = 0
    end if
    if choice = 3
        m.diagnosticDialog = invalid
        showDiagnosticSupportCode()
        return
    end if
    if choice = 4
        events = diagnosticEvents(m.diagnosticLog, uiNow(), m.apiKey, textValue(m.accountIdentity))
        print "[diagnostic-export] "; FormatJson({schema: 1, events: diagnosticConsoleEvents(events)})
        showNotice("Exported sanitized JSON to this Roku's developer console (TCP port 8085).")
    end if
    if choice <> 5 then showDiagnostics()
end sub

sub onDiagnosticClosed(event as object)
    if not isCurrentTaskEvent(event, m.diagnosticDialog) then return
    m.diagnosticDialog = invalid
    onDialogClosed()
end sub

sub showDiagnosticSupportCode()
    scope = textValue(m.accountIdentity)
    code = diagnosticSupportCode(m.diagnosticLog, uiNow(), m.apiKey, scope)
    if code = ""
        showNotice("No recent events for this account. Nothing to share yet.")
        showDiagnostics()
        return
    end if
    cancelDiagnosticShare()
    m.diagnosticShareScope = scope
    m.diagnosticShareCode = code
    if m.diagnosticPrivacyCover = invalid
        m.diagnosticPrivacyCover = m.top.createChild("Rectangle")
        m.diagnosticPrivacyCover.width = 1920
        m.diagnosticPrivacyCover.height = 1080
        m.diagnosticPrivacyCover.color = "0x0A1628FF"
    end if
    m.diagnosticPrivacyCover.visible = true
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = "Support code — shown for 90 seconds"
    dialog.message = code + chr(10) + chr(10) + "Photograph or dictate this code to support. It has event types, error numbers and coarse timing only — no account, program, URL or message text. Back clears this screen; a saved photo remains readable."
    dialog.buttons = ["Close code"]
    dialog.observeField("buttonSelected", "onDiagnosticShareChoice")
    dialog.observeField("wasClosed", "onDiagnosticShareClosed")
    m.diagnosticShareDialog = dialog
    m.top.dialog = dialog
    if m.diagnosticShareTimer = invalid
        m.diagnosticShareTimer = m.top.createChild("Timer")
        m.diagnosticShareTimer.duration = 90
        m.diagnosticShareTimer.observeField("fire", "expireDiagnosticShare")
    end if
    m.diagnosticShareTimer.control = "stop"
    m.diagnosticShareTimer.control = "start"
end sub

sub cancelDiagnosticShare()
    if m.diagnosticShareTimer <> invalid then m.diagnosticShareTimer.control = "stop"
    if m.diagnosticPrivacyCover <> invalid then m.diagnosticPrivacyCover.visible = false
    dialog = m.diagnosticShareDialog
    m.diagnosticShareDialog = invalid
    m.diagnosticShareScope = ""
    m.diagnosticShareCode = ""
    if dialog <> invalid
        dialog.unobserveField("buttonSelected")
        dialog.unobserveField("wasClosed")
        dialog.close = true
    end if
end sub

sub onDiagnosticShareChoice(event as object)
    if not isCurrentTaskEvent(event, m.diagnosticShareDialog) then return
    cancelDiagnosticShare()
    showDiagnostics()
end sub

sub onDiagnosticShareClosed(event as object)
    if not isCurrentTaskEvent(event, m.diagnosticShareDialog) then return
    cancelDiagnosticShare()
    showDiagnostics()
end sub

sub expireDiagnosticShare()
    if m.diagnosticShareDialog = invalid then return
    cancelDiagnosticShare()
    showDiagnostics()
    showNotice("Support code expired. Create a new one if needed.")
end sub
