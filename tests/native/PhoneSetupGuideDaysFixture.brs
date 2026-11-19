' Private driver: the real GuideView owns the setting, clamp, drawing, and Tasks.
function probeImportedGuideWindow(days as integer) as object
    if not m.ready or not m.top.active or m.mappingState = "loading" then return {state: "waiting"}
    if m.settings.futureDays <> days or m.settings.historyDays <> days then return {state: "guide-setting-mismatch"}
    if m.guideDaysProbeWindow = invalid
        if m.task <> invalid then return {state: "waiting"}
        now = uiNow()
        jumpTo(now - 31 * 86400)
        if abs(m.anchor - now + days * 86400) > 2 then return {state: "history-anchor-mismatch"}
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
    if m.guideDaysProbeHistoryCount = invalid
        m.guideDaysProbeHistoryCount = programCount
        m.guideDaysProbeHistoryWindow = m.guideDaysProbeWindow
        now = uiNow()
        jumpTo(now + 31 * 86400)
        if abs(m.anchor - now - (days * 86400 - 1)) > 2 then return {state: "future-anchor-mismatch"}
        m.guideDaysProbeWindow = guideWindowStart(m.anchor)
        m.guideDaysProbeSource = ""
        m.forceGuideFetch = true
        return {state: "waiting"}
    end if
    jumpTo(uiNow())
    return {state: "loaded", window: m.guideDaysProbeWindow, programs: programCount, historyWindow: m.guideDaysProbeHistoryWindow, historyPrograms: m.guideDaysProbeHistoryCount}
end function
