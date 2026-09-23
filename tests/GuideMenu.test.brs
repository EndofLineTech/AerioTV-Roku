sub main()
    m.settings = normalizeGuideSettings(invalid)
    m.groups = [{id: "all", name: "All Channels"}]
    m.groupIndex = 0
    m.serverGroups = [{id: "1", name: "Sports"}]
    m.collections = []
    m.anchor = uiNow()
    m.navigator = {active: true, callFunc: sub(name as string, model as object)
        m.appliedLayout = model.layout
    end sub}
    handleGuideSetting("guideSettings", {field: "groupLayout"})
    assertEqual(m.pickedKind, "settingValue", "normal settings path exposes layout choice")
    assertEqual(m.pickedItems[1].value, "pills", "pills selectable through actual handler")
    handleGuideSetting(m.pickedKind, m.pickedItems[1])
    assertEqual(m.settings.groupLayout, "pills", "selection changes live state")
    assertEqual(m.navigator.active, false, "layout change clears old navigator focus")
    assertEqual(m.navigator.appliedLayout, "pills", "layout selection synchronously applies presentation")
    assertEqual(m.saved.groupLayout, "pills", "selection survives preference normalization")
    openNavigationLayout()
    handleGuideSetting(m.pickedKind, m.pickedItems[2])
    assertEqual(m.saved.groupLayout, "sidebar", "direct layout route saves sidebar")
    assertEqual(m.renderedLayout, "sidebar", "renderer receives the selected layout")
    assertEqual(m.navigator.appliedLayout, "sidebar", "sidebar also applies without relaunch")
    m.ready = true
    m.channels = []
    for each change in [{key: "guideDensity", value: "basic"}, {key: "showLogos", value: false}, {key: "showNumbers", value: false}, {key: "showNames", value: false}, {key: "showSubtitles", value: false}]
        if applyHubGuideSetting(change.key, change.value) = invalid then stop
        assertEqual(m.saved[lcase(change.key)], change.value, "new Live TV setting applies and saves")
    end for
    print "ALL TESTS PASSED"
end sub

sub openPicker(title as string, items as object, kind as string)
    m.pickedItems = items
    m.pickedKind = kind
end sub

sub filterLineup()
end sub

sub savePreferences()
    m.saved = normalizeGuideSettings(m.settings)
end sub

sub drawGuide()
    m.renderedLayout = m.settings.groupLayout
end sub

sub scheduleLoad()
end sub

sub keepAnchorVisible()
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
