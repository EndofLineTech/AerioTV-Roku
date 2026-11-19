' Private driver: the real GuideView owns the setting, clamp, drawing, and Tasks.
function probeImportedGuideWindow(days as integer) as object
    if not m.ready or not m.top.active or m.mappingState = "loading" then return {state: "waiting"}
    if m.settings.futureDays <> days or m.settings.historyDays <> 3 then return {state: "guide-setting-mismatch"}
    if m.guideDaysProbeWindow = invalid
        if m.task <> invalid then return {state: "waiting"}
        now = uiNow()
        jumpTo(now + 31 * 86400)
        delta = m.anchor - now
        if abs(delta - (days * 86400 - 1)) > 2 then return {state: "anchor-mismatch"}
        m.guideDaysProbeWindow = guideWindowStart(m.anchor)
        m.forceGuideFetch = true
        return {state: "waiting"}
    end if
    key = m.guideDaysProbeWindow.toStr()
    if m.failures.doesExist(key) then return {state: "provider-window-failed"}
    if not m.cache.entries.doesExist(key) then return {state: "waiting"}
    if m.guideDaysProbeSource <> "network" then return {state: "not-a-provider-window"}
    index = m.cache.entries[key].index
    programCount = 0
    for each station in index
        programCount += index[station].count()
    end for
    jumpTo(uiNow())
    return {state: "loaded", window: m.guideDaysProbeWindow, programs: programCount}
end function
