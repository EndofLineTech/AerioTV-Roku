sub Main()
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.setMessagePort(port)
    scene = screen.createScene("SetupApplyProbe")
    input = CreateObject("roInput")
    input.setMessagePort(port)
    screen.show()
    while true
        event = wait(0, port)
        if type(event) = "roSGScreenEvent"
            if event.isScreenClosed() then return
        else if type(event) = "roInputEvent"
            fields = event.getInfo()
            if fields["setupApplyCase"] <> invalid then scene.fixtureCase = fields["setupApplyCase"]
        end if
    end while
end sub
