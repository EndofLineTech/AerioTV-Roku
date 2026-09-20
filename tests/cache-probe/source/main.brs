sub Main()
    port = CreateObject("roMessagePort")
    screen = CreateObject("roSGScreen")
    screen.setMessagePort(port)
    memory = CreateObject("roAppMemoryMonitor")
    memory.setMessagePort(port)
    memory.enableMemoryWarningEvent(true)
    scene = screen.createScene("CacheProbeScene")
    screen.show()
    peak = 0
    leastAvailable = 2147483647
    while true
        event = wait(100, port)
        percent = memory.getMemoryLimitPercent()
        available = memory.getChannelAvailableMemory()
        if percent > peak then peak = percent
        if available < leastAvailable then leastAvailable = available
        if scene.done
            print "[cache-probe-main] "; FormatJson({peakPercent: peak, minimumAvailableKB: leastAvailable})
            screen.close()
            return
        end if
        if type(event) = "roSGScreenEvent"
            if event.isScreenClosed() then return
        end if
    end while
end sub
