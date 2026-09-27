sub main()
    m.top = {active: true, optionsRequested: false}
    m.delay = {control: "start"}
    if not onKeyEvent("options", true) then stop
    if m.top.active or not m.top.optionsRequested then stop
    if m.delay.control <> "stop" then stop
    m.top = {active: true, topRequested: false}
    m.layout = "pills"
    m.index = 3
    if not onKeyEvent("up", true) or not m.top.topRequested then stop
    m.top = {active: true, topRequested: false}
    m.layout = "sidebar"
    m.index = 8
    if not onKeyEvent("left", true) or not m.top.topRequested then stop
    window = groupPillWindow(35, 0, 5)
    if window.first <> 0 or window.last <> 5 or window.left or not window.right then stop
    window = groupPillWindow(35, 4, 5)
    if window.first <> 0 or not window.right then stop
    window = groupPillWindow(35, 5, 5)
    if window.first <> 1 or window.last <> 6 or not window.left or not window.right then stop
    window = groupPillWindow(35, 34, 5)
    if window.first <> 30 or window.last <> 35 or not window.left or window.right then stop
    window = groupPillWindow(5, 4, 5)
    if window.left or window.right then stop
    window = groupPillWindow(3, 2, 5)
    if window.first <> 0 or window.last <> 3 or window.left or window.right then stop
    print "ALL TESTS PASSED"
end sub
