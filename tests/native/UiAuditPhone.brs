' Probe only: never start the setup receiver or display a real session/code.
sub auditPhoneActive()
end sub

sub seedUiAuditPhone(kind as string)
    m.top.active = true
    m.top.visible = true
    m.index = 0
    m.top.phase = ""
    m.top.warning = "SYNTHETIC VISUAL FIXTURE - NO ACCOUNT OR LIVE PAIRING SESSION"
    m.info = {kind: kind, name: "Synthetic TV", code: "123456", fingerprint: "DEMO", rows: []}
    if kind = "failed"
        m.top.phase = "Could not verify the playlist. Saved connections were not changed."
        m.top.retryAvailable = true
    end if
    drawPhoneSetup()
    m.top.setFocus(true)
end sub
