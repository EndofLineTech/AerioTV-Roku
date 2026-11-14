sub main()
    m.groups = [{id: "all"}]
    m.groupIndex = 0
    m.serverGroups = []
    m.collections = []
    m.channels = []
    m.settings = normalizeGuideSettings(invalid)
    m.fixtureWrites = 0
    rebuildGuideGroups(false)
    check(m.fixtureWrites = 0, "internal lineup rebinding does not publish a synthetic user preference edit")
    rebuildGuideGroups()
    check(m.fixtureWrites = 1, "explicit guide edits still persist through ordinary rebuilds")
    print "ALL TESTS PASSED"
end sub

sub filterLineup()
end sub

sub savePreferences()
    m.fixtureWrites++
end sub

sub drawGuide()
end sub

sub scheduleLoad()
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
