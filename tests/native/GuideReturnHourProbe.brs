' Disposable read-only guide test. A stale anchor simulates an hour spent off
' the guide; toggling active exercises the real onActive re-entry handler.
function seedGuideReturnHour(followNow as boolean) as object
    if not m.ready or not m.top.active or m.filtered.count() = 0 then return {ready: false}
    now = uiNow()
    if followNow
        ' The authorized account has no mapped EPG. Seed only this disposable
        ' in-memory guide cache; the real server and registry are untouched.
        m.cache = guideNewCache()
        index = guideDictionary()
        index[m.filtered[m.selected].uuid] = [
            normalizeProgram({id: "fixture-past", title: "Prior fictional programme", start_time: now - 3900, end_time: now - 3000})
            normalizeProgram({id: "fixture-now", title: "Current fictional programme", start_time: now - 600, end_time: now + 600})
        ]
        guideCachePut(m.cache, guideWindowStart(now), index, now)
    end if
    m.anchor = now - 3600
    m.viewStart = (m.anchor \ 1800) * 1800
    m.followNow = followNow
    return {ready: true}
end function

function readGuideReturnHour() as object
    cell = selectedCell()
    title = ""
    if cell <> invalid and cell.program <> invalid then title = cell.program.title
    return {offsetSeconds: m.anchor - uiNow(), following: m.followNow, title: title}
end function

sub resetGuideReturnHour()
    jumpTo(uiNow())
end sub
