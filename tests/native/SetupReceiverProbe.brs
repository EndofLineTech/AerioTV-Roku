sub Main()
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.setMessagePort(port)
    scene = screen.createScene("SetupReceiverProbe")
    input = CreateObject("roInput")
    input.setMessagePort(port)
    screen.show()
    while true
        event = wait(0, port)
        if type(event) = "roSGScreenEvent"
            if event.isScreenClosed() then return
        else if type(event) = "roInputEvent"
            if event.isInput()
                fields = event.getInfo()
                if fields["setupProbeReset"] <> invalid then scene.reset = fields["setupProbeReset"]
            end if
        end if
    end while
end sub
