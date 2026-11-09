sub init()
    m.view = m.top.findNode("receiver")
    m.view.observeField("sessionInfo", "fixtureInfo")
    m.view.observeField("payload", "fixtureAccepted")
    m.view.observeField("closed", "fixtureClosed")
    m.view.active = true
    m.view.setFocus(true)
end sub

sub resetReceiver()
    m.view.active = false
    m.view.active = true
    m.view.setFocus(true)
end sub

sub fixtureInfo(event as object)
    info = event.getData()
    if type(info) <> "roAssociativeArray" then return
    if info.kind = "ready"
        fields = info.link.split("&")
        port = fields[2].split("=")[1].toInt()
        print "[setup-receiver] "; formatJson({kind: "ready", port: port, fingerprint: info.fingerprint})
    else
        print "[setup-receiver] "; formatJson({kind: info.kind})
    end if
end sub

sub fixtureAccepted(event as object)
    if type(event.getData()) <> "roAssociativeArray" then return
    m.view.payload = invalid
    m.view.phase = "Synthetic setup accepted — no provider contacted"
    print "[setup-receiver] "; formatJson({kind: "payload"})
end sub

sub fixtureClosed()
    print "[setup-receiver] "; formatJson({kind: "cancelled"})
end sub
