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
    m.top = {active: true, delegateBack: true}
    if onKeyEvent("back", true) or onKeyEvent("back", false) or not m.top.active then stop
    dismissGroups()
    if m.top.active or not m.top.closed or m.delay.control <> "stop" then stop
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
    checkGroupHoldDefault()
    checkSidebarOverlayVisibility()
    print "ALL TESTS PASSED"
end sub

' e3e.34: a short OK still selects on release; holding OK on a pill asks the
' Guide to make that group the default instead.
sub checkGroupHoldDefault()
    m.groups = [{id: "all", name: "All"}, {id: "news", name: "News"}]
    m.index = 1
    m.layout = "pills"
    m.delay = {control: "stop"}
    m.holdTimer = {control: "stop"}
    m.okDown = false
    m.top = {active: true, preview: "", closed: false, defaultRequested: ""}
    if not onKeyEvent("OK", true) or m.top.closed or m.holdTimer.control <> "start" then stop
    if not onKeyEvent("OK", true) or m.holdTimer.control <> "start" then stop ' native repeats are ignored
    if not onKeyEvent("OK", false) then stop
    if not m.top.closed or m.top.preview <> "news" or m.holdTimer.control <> "stop" then stop
    m.top = {active: true, preview: "", closed: false, defaultRequested: ""}
    onKeyEvent("OK", true)
    onGroupHold()
    if m.top.defaultRequested <> "news" or m.top.closed then stop
    if not onKeyEvent("OK", false) or m.top.closed or m.top.preview <> "" then stop ' release after a hold does not select
    m.layout = "modal"
    m.top = {active: true, preview: "", closed: false, defaultRequested: ""}
    onKeyEvent("OK", true)
    if not m.top.closed then stop ' the modal list keeps immediate OK
    m.layout = "pills"
    m.top = {active: false, defaultRequested: ""}
    m.okDown = true
    onGroupHold()
    if m.top.defaultRequested <> "" then stop ' an inactive navigator never requests
end sub

' e3e.34: an overlay sidebar is visible only while it has focus.
sub checkSidebarOverlayVisibility()
    m.leftArrow = {visible: false}
    m.rightArrow = {visible: false}
    m.caption = invalid
    m.rows = []
    m.groups = [{id: "all", name: "All"}]
    m.index = 0
    m.layout = "sidebar"
    m.overlay = true
    m.top = {active: false, visible: true}
    draw()
    if m.top.visible then stop
    m.top.active = true
    draw()
    if not m.top.visible then stop
    m.overlay = false
    m.top.active = false
    draw()
    if not m.top.visible then stop ' a shifting sidebar stays on screen
end sub
