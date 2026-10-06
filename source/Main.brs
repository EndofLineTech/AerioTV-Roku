sub Main(args as dynamic)
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.setMessagePort(port)
    scene = screen.createScene("AerioScene")
    if type(args) = "roAssociativeArray" then scene.launchRequest = args
    input = CreateObject("roInput")
    input.setMessagePort(port)
    memoryMonitor = CreateObject("roAppMemoryMonitor")
    deviceInfo = CreateObject("roDeviceInfo")
    memoryEventsEnabled = false
    if memoryMonitor <> invalid
        memoryMonitor.setMessagePort(port)
        limits = memoryMonitor.GetChannelMemoryLimit()
        if type(limits) = "roAssociativeArray" then print "[memory] foreground limit KB="; limits.maxForegroundMemory
        memoryEventsEnabled = memoryMonitor.EnableMemoryWarningEvent(true)
    end if
    if not memoryEventsEnabled
        deviceInfo.setMessagePort(port)
        deviceInfo.EnableLowGeneralMemoryEvent(true)
    end if
    screen.show()
    while true
        event = wait(0, port)
        if type(event) = "roSGScreenEvent"
            if event.isScreenClosed() then return
        else if type(event) = "roAppMemoryNotificationEvent"
            info = event.getInfo()
            if type(info) = "roAssociativeArray" and info.MemoryUsagePercent <> invalid
                if info.MemoryUsagePercent >= 80 then scene.memoryPressure = "low"
            end if
        else if type(event) = "roDeviceInfoEvent"
            info = event.getInfo()
            if type(info) = "roAssociativeArray"
                if info.generalMemoryLevel = "low" or info.generalMemoryLevel = "critical" then scene.memoryPressure = info.generalMemoryLevel
            end if
        else if type(event) = "roInputEvent"
            if event.isInput()
                request = event.getInfo()
                if type(request) = "roAssociativeArray" then scene.launchRequest = request
            end if
        end if
    end while
end sub
