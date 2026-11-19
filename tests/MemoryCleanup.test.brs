sub main()
    m.guide = {callFunc: sub(name as string)
        if name <> "trimTransientGuideMemory" then stop
        trimTransientGuideMemory()
    end sub}
    m.browser = {active: true, logoInvalidations: 0, callFunc: sub(name as string)
        if name <> "invalidateLogos" then stop
        m.logoInvalidations++
    end sub}
    m.cache = guideNewCache()
    nowWindow = guideWindowStart(uiNow())
    selectedWindow = nowWindow + 10800
    otherWindow = selectedWindow + 10800
    guideCachePut(m.cache, nowWindow, {station: [{id: "current", startsAt: nowWindow, endsAt: nowWindow + 1800}]}, uiNow())
    guideCachePut(m.cache, selectedWindow, {station: [{id: "selected", startsAt: selectedWindow, endsAt: selectedWindow + 1800}]}, uiNow())
    guideCachePut(m.cache, otherWindow, {}, uiNow())
    m.viewStart = selectedWindow + 600
    m.detailCache = {program: true}
    m.detailOrder = ["program"]
    m.detailFailures = {program: true}
    m.video = {state: "playing", control: "play"}

    ' Invoke the production Scene handler directly; this isn't a Roku event.
    onMemoryPressure()
    check(m.cache.entries.count() = 2 and m.cache.order.count() = 2, "only two windows remain")
    check(guideCachePrograms(m.cache, "station", nowWindow, nowWindow + 1800)[0].id = "current", "current window data retained")
    check(guideCachePrograms(m.cache, "station", selectedWindow, selectedWindow + 1800)[0].id = "selected", "selected window data retained")
    check(m.detailCache.count() = 0 and m.detailOrder.count() = 0 and m.detailFailures.count() = 0, "detail state cleared")
    check(m.browser.logoInvalidations = 0, "active browser logos not invalidated")
    check(m.viewStart = selectedWindow + 600 and m.video.state = "playing" and m.video.control = "play", "handler leaves selection and player control alone")

    m.browser.active = false
    onMemoryPressure()
    check(m.browser.logoInvalidations = 1, "inactive browser logos invalidated")
    check(m.cache.entries.count() = 2 and m.cache.order.count() = 2, "repeated cleanup retains the same windows")

    m.cache = invalid
    onMemoryPressure()
    check(m.browser.logoInvalidations = 2, "inactive logos still invalidate when guide cache is absent")

    m.guide = invalid
    m.browser = invalid
    onMemoryPressure()
    print "ALL TESTS PASSED"
end sub

function uiNow() as integer
    return 1000000
end function

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
