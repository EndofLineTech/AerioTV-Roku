sub Main()
    port = CreateObject("roMessagePort")
    input = CreateObject("roInput")
    input.setMessagePort(port)
    screen = CreateObject("roSGScreen")
    screen.setMessagePort(port)
    scene = screen.createScene("UserProfileDialogProbe")
    scene.observeField("exitRequested", port)
    screen.show()
    scene.command = "numbers"
    while true
        event = wait(100, port)
        if scene.exitRequested = true
            screen.close()
            print "[profile-dialog] complete"
            return
        end if
        if type(event) = "roInputEvent"
            info = event.getInfo()
            if info.profileProbeMode <> invalid then scene.command = info.profileProbeMode
        else if type(event) = "roSGNodeEvent"
            if lcase(event.getField()) = "exitrequested" and scene.exitRequested = true
                screen.close()
                print "[profile-dialog] complete"
                return
            end if
        else if type(event) = "roSGScreenEvent"
            if event.isScreenClosed() then return
        end if
    end while
end sub
