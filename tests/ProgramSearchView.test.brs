sub main()
    m.top = {active: true, model: {hasNext: true, page: 1}, selection: invalid}
    if not onKeyEvent("fastforward", true) then stop
    if m.top.selection.action <> "next" then stop
    m.top.selection = invalid
    if not onKeyEvent("rewind", true) or m.top.selection <> invalid then stop
    m.top.model.page = 2
    if not onKeyEvent("rewind", true) then stop
    if m.top.selection.action <> "previous" then stop
    m.top.selection = invalid
    m.top.model.hasNext = false
    if not onKeyEvent("fastforward", true) or m.top.selection <> invalid then stop
    m.top.active = false
    if onKeyEvent("rewind", true) then stop
    print "ALL TESTS PASSED"
end sub
