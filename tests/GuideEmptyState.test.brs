sub main()
    m.subtitle = {text: "S2E7 old episode", visible: true}
    m.description = {translation: [96, 233], height: 29, wrap: false, maxLines: 1}
    clearGuideProgramSummary()
    if m.subtitle.visible or m.subtitle.text <> "" then stop
    if m.description.translation[1] <> 205 or m.description.height <> 57 or not m.description.wrap or m.description.maxLines <> 2 then stop
    print "ALL TESTS PASSED"
end sub
