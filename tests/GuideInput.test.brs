sub main()
    m.top = {active: true, miniActive: false, removeChild: sub(child as object)
    end sub, setFocus: sub(focused as boolean)
    end sub}
    m.ready = false
    m.picker = invalid
    m.pickerWakeKey = ""
    m.navigator = {active: false}
    m.searchView = {active: false}
    m.details = {active: false}
    m.holdTimer = {control: "stop"}
    m.saveDelay = {control: "stop"}
    m.loadDelay = {control: "stop"}
    m.holdKey = ""
    m.settings = normalizeGuideSettings({groupLayout: "sidebar"})
    m.selected = 1
    m.filtered = []
    for i = 0 to 19
        m.filtered.push({uuid: i.toStr()})
    end for
    m.picker = {}
    m.pickerList = {isSameNode: function(node as object) as boolean
        return true
    end function}
    m.pickerItems = [{value: "pills"}]
    m.pickerKind = "settingValue"
    onPickerSelected({getData: function() as integer
        return 0
    end function, getRoSGNode: function() as object
        return {}
    end function})
    if m.picker <> invalid or m.selectedLayout <> "pills" then stop
    if not onKeyEvent("OK", true) then stop
    if m.top.watchChannel <> invalid then stop
    onKeyEvent("OK", false)
    if m.pickerWakeKey <> "" then stop
    onKeyEvent("down", true)
    if m.selected <> 2 then stop
    onKeyEvent("down", true)
    if m.selected <> 2 then stop
    m.holdClock = {totalMilliseconds: function() as integer
        return 1600
    end function}
    repeatGuideHold()
    if m.selected <> 5 then stop
    onKeyEvent("down", false)
    repeatGuideHold()
    if m.selected <> 5 or m.holdTimer.control <> "stop" then stop
    m.anchor = 123
    onKeyEvent("left", true)
    if m.anchor <> 123 then stop
    repeatGuideHold()
    if not m.navigator.active or m.anchor <> 123 then stop
    if m.holdKey <> "" then stop
    onKeyEvent("left", false)
    m.picker = invalid
    m.settings.groupLayout = "modal"
    m.navigator.active = false
    m.primaryNavigation = {active: false}
    m.selected = 0
    onKeyEvent("up", true)
    if not m.primaryNavigation.active then stop
    m.primaryNavigation.active = false
    m.navigator.active = false
    m.settings.groupLayout = "pills"
    onKeyEvent("left", true)
    if m.anchor <> 123 then stop
    repeatGuideHold()
    if not m.navigator.active or m.anchor <> 123 then stop
    onKeyEvent("left", false)
    m.navigator.active = false
    onKeyEvent("down", true)
    m.picker = {}
    repeatGuideHold()
    if m.holdKey <> "" then stop
    print "ALL TESTS PASSED"
end sub

function handleGuideSetting(kind as string, item as object) as boolean
    m.selectedLayout = item.value
    return true
end function
