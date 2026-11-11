sub Main()
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.setMessagePort(port)
    scene = screen.createScene("AerioScene")
    input = CreateObject("roInput")
    input.setMessagePort(port)
    screen.show()
    while true
        event = wait(0, port)
        if type(event) = "roSGScreenEvent"
            if event.isScreenClosed() then return
        else if type(event) = "roInputEvent"
            fields = event.getInfo()
            if fields["uiAuditScreen"] <> invalid then scene.auditScreen = fields["uiAuditScreen"]
            if fields["uiAuditCheck"] <> invalid then scene.auditCheck = fields["uiAuditCheck"]
        end if
    end while
end sub
