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
    print "ALL TESTS PASSED"
end sub
