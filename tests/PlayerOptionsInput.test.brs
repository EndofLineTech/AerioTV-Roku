sub main()
    m.top = {active: true, consumeSelectRelease: true, closed: false, menu: {items: [{action: "stop"}]}}
    m.list = {focused: false, setFocus: sub(value as boolean)
        m.focused = value
    end sub}
    event = {getData: function() as integer
        return 0
    end function}
    if not onKeyEvent("OK", true) then stop
    onSelected(event)
    if m.top.selection <> invalid then stop
    if not onKeyEvent("OK", false) then stop
    if m.top.consumeSelectRelease or not m.list.focused then stop
    if m.top.selection <> invalid then stop
    onSelected(event)
    if m.top.selection.action <> "stop" then stop
    if onKeyEvent("options", true) then stop
    if not m.top.active then stop
    print "ALL TESTS PASSED"
end sub
