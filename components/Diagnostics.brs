sub recordDiagnostic(stage as string, code as integer, message as string, elapsedMs = 0 as integer)
    if m.diagnosticLog = invalid then m.diagnosticLog = []
    m.diagnosticLog.push({stage: stage, code: code, message: message, time: uiNow(), elapsedMs: elapsedMs})
    m.diagnosticLog = diagnosticEvents(m.diagnosticLog, uiNow(), m.apiKey)
end sub

sub showDiagnostics()
    m.diagnosticLog = diagnosticEvents(m.diagnosticLog, uiNow(), m.apiKey)
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
    dialog.buttons = ["Older", "Newer", "Clear", "Export to Roku console", "Close"]
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
        events = diagnosticEvents(m.diagnosticLog, uiNow(), m.apiKey)
        print "[diagnostic-export] "; FormatJson({schema: 1, events: events})
        showNotice("Exported sanitized JSON to this Roku's developer console (TCP port 8085).")
    end if
    if choice <> 4 then showDiagnostics()
end sub

sub onDiagnosticClosed(event as object)
    if not isCurrentTaskEvent(event, m.diagnosticDialog) then return
    m.diagnosticDialog = invalid
    onDialogClosed()
end sub
