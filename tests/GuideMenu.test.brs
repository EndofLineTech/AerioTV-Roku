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
    openGuideSetting("guideSettings")
    for each option in m.pickedItems
        if option.action = "colors" then stop
    end for
    assertEqual(applyHubGuideSetting("categoryColors", true), invalid, "old category-color setting is rejected")
    for each change in [{key: "guideDensity", value: "basic"}, {key: "showLogos", value: false}, {key: "showNumbers", value: false}, {key: "showNames", value: false}, {key: "showSubtitles", value: false}]
        if applyHubGuideSetting(change.key, change.value) = invalid then stop
        assertEqual(m.saved[lcase(change.key)], change.value, "new Live TV setting applies and saves")
    end for
    applyHubGuideSetting("guideDensity", "preview")
    assertEqual(guidePresentationGeometry(m.saved.guideDensity, m.saved.showSubtitles).rowCount, 7, "saved Off restores compact Preview")
    applyHubGuideSetting("showSubtitles", true)
    assertEqual(guidePresentationGeometry(m.saved.guideDensity, m.saved.showSubtitles).rowCount, 6, "saved On restores subtitle-rich Preview")
    m.userRole = "child"
    m.pickedKind = "unchanged"
    before = FormatJson(m.settings)
    openGuideSetting("manageGroups")
    assertEqual(m.pickedKind, "unchanged", "Child cannot open Manage Groups through a direct handler")
    handleGuideSetting("manageGroups", {id: "1"})
    assertEqual(FormatJson(m.settings), before, "Child stale group-management selection cannot change group filters")
    for each action in ["groups", "groupList", "manageGroups", "settings", "toggleVod", "diagnostics", "clock"]
        assertEqual(guideProfileActionAllowed("child", action), false, "Child guide shortcut cannot bypass hidden settings or group restrictions")
    end for
    assertEqual(guideProfileActionAllowed("child", "settingsHub"), true, "Child retains the restricted Settings entry")
    assertEqual(guideProfileActionAllowed("child", "favorite"), true, "Child keeps its own favorite action")
    assertEqual(guideProfileActionAllowed("user", "manageGroups"), true, "Standard retains existing group controls")
    m.groups.push({id: "1", name: "Other group"})
    onGroupPreview({getData: function() as string
        return "1"
    end function})
    assertEqual(m.groupIndex, 0, "Child direct navigator callbacks cannot change group filters")
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
