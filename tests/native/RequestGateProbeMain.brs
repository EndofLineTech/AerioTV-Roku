sub Main()
    port = CreateObject("roMessagePort")
    screen = CreateObject("roSGScreen")
    screen.setMessagePort(port)
    scene = screen.createScene("RequestGateProbe")
    input = CreateObject("roInput")
    input.setMessagePort(port)
    screen.show()
    while true
        event = wait(0, port)
        if type(event) = "roInputEvent"
            info = event.getInfo()
            if info["gateFixtureBase"] <> invalid then scene.fixtureBase = info["gateFixtureBase"]
            if info["gateProbeCommand"] <> invalid then scene.command = info["gateProbeCommand"]
        else if type(event) = "roSGScreenEvent"
            if event.isScreenClosed() then return
        end if
    end while
end sub
