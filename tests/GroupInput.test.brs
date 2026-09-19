sub main()
    m.top = {active: true, optionsRequested: false}
    m.delay = {control: "start"}
    if not onKeyEvent("options", true) then stop
    if m.top.active or not m.top.optionsRequested then stop
    if m.delay.control <> "stop" then stop
    print "ALL TESTS PASSED"
end sub
