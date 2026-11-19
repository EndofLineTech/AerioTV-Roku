sub main()
    m.subtitle = {text: "S2E7 old episode", visible: true}
    m.description = {translation: [96, 233], height: 29, wrap: false, maxLines: 1}
    clearGuideProgramSummary()
    if m.subtitle.visible or m.subtitle.text <> "" then stop
    if m.description.translation[1] <> 205 or m.description.height <> 57 or not m.description.wrap or m.description.maxLines <> 2 then stop
    testGuideCellScaleRedraw()
    print "ALL TESTS PASSED"
end sub

sub testGuideCellScaleRedraw()
    m.global = {appearance: {textSize: 120, subtextSize: 120}, clockFormat: "12"}
    m.settings = normalizeGuideSettings({guideDensity: "preview", showSubtitles: true})
    m.top = {active: false}
    m.ready = true
    m.details = {active: false}
    m.primaryNavigation = {active: false}
    m.navigator = {active: false}
    m.searchView = {active: false}
    m.initialProgramReported = true
    m.viewStart = 43200
    m.span = 7200
    m.anchor = m.viewStart
    m.failures = {}
    m.cache = {entries: {}}
    m.reminders = []
    label = {font: {size: 20}, localBoundingRect: function() as object
        return {width: len(m.text) * m.font.size * 0.6}
    end function}
    badge = {root: {}, surface: {}, label: {font: {size: 16}}}
    tile = {root: {}, border: {}, fill: {}, title: {font: {size: 25}}, subtitle: {font: {size: 21}}, time: label, badges: [badge], corners: []}
    row = {uuid: "fixture", tiles: [tile]}
    program = {id: "1", startsAt: 43200, endsAt: 86400, title: "Test airing", subtitle: "Episode subtitle", is_live: true}
    cell = {startsAt: 43200, endsAt: 43200 + 1320, program: program}
    geometry = currentGuideGeometry()
    renderCells(row, [cell], true, geometry, 1.0)
    if tile.time.visible or not badge.root.visible or instr(1, tile.time.text, "M - ") = 0 then stop
    cell.endsAt = 43200 + 4200
    renderCells(row, [cell], true, geometry, 1.0)
    if not tile.time.visible or tile.title.font.size <> 27 or tile.time.font.size <> 20 then stop
    if tile.subtitle.font.size <> 24 or badge.label.font.size <> 17 then stop
    if tile.root.translation[0] <> 240 or tile.root.clippingRect[3] <> 111 then stop
    program.subtitle = ""
    renderCells(row, [cell], true, geometry, 1.0)
    if tile.subtitle.visible or tile.title.font.size <> 30 or tile.time.font.size <> 22 then stop
    program.subtitle = "Episode subtitle"
    applyHubGuideSetting("guideDisplayScale", 120)
    geometry = currentGuideGeometry()
    cell.endsAt = 43200 + 1320
    renderCells(row, [cell], true, geometry, 1.2)
    if tile.time.visible or not badge.root.visible then stop
    cell.endsAt = 43200 + 4200
    renderCells(row, [cell], true, geometry, 1.2)
    if tile.root.translation[0] <> 240 or tile.root.clippingRect[3] <> 133 then stop
    if not tile.time.visible or tile.title.font.size <= 27 or tile.time.font.size <= 20 then stop
    if tile.time.translation[0] <= badge.root.translation[0] + badge.surface.width then stop
    if tile.time.translation[0] + tile.time.width > tile.root.clippingRect[2] then stop
    measured = tile.timeMeasuredWidth
    ' Keep the subtitle lane and font, but reduce room after the badge.
    cell.endsAt = 43200 + 1740
    renderCells(row, [cell], true, geometry, 1.2)
    if tile.time.visible or tile.timeMeasuredWidth <> measured or not badge.root.visible then stop
    cell.endsAt = 43200 + 4200
    applyHubGuideSetting("guideDisplayScale", 100)
    renderCells(row, [cell], true, currentGuideGeometry(), 1.0)
    if tile.title.font.size <> 27 or tile.time.font.size <> 20 or tile.root.clippingRect[3] <> 111 then stop
end sub
