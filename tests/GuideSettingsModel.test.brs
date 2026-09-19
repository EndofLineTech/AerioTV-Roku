sub main()
    numbered = channelOrderedGroups([{id: "a", name: "Alpha"}, {id: "z", name: "Zulu"}, {id: "e", name: "Empty"}], [{groupId: "a", number: "100"}, {groupId: "z", number: "2.1"}, {groupId: "a", number: "3"}])
    assertEqual(numbered[0].id, "z", "default groups use minimum numeric channel, not name")
    assertEqual(numbered[1].id, "a", "minimum member beats first member")
    assertEqual(numbered[2].id, "e", "empty groups last")
    numbered = channelOrderedGroups([{id: "a", name: "Alpha"}, {id: "z", name: "Zulu"}], [{groupId: "a", number: "N/A"}, {groupId: "z", number: " 02.1 "}])
    assertEqual(numbered[0].id, "z", "invalid channel numbers do not sort ahead of numbered groups")
    numbered = channelOrderedGroups([{id: "z", name: "Zulu"}, {id: "a", name: "Alpha"}], [{groupId: "a", number: "2.10"}, {groupId: "z", number: "2.1"}])
    assertEqual(numbered[0].id, "a", "equal decimal minima use deterministic name tie-break")
    assertEqual(guideHoldStep(0), 1, "single step")
    assertEqual(guideHoldStep(1600), 3, "held guide accelerates")
    assertEqual(guideHoldStep(3200), 7, "long hold pages")
    settings = normalizeGuideSettings(invalid)
    parsed = {}
    parsed.setModeCaseSensitive()
    parsed["grouplayout"] = "modal"
    parsed["groupLayout"] = "pills"
    assertEqual(normalizeGuideSettings(parsed).groupLayout, "pills", "migrate case-sensitive dynamic layout selection")
    server = [{id: "1", name: "Sports"}, {id: "2", name: "News"}]
    settings.hiddenGroups = ["group:1"]
    groups = organizedGroups(server, [], settings)
    assertEqual(groups.count(), 4, "hidden group filtered; recent builtin present")
    settings.hiddenGroups = ["all", "favorites", "recent", "group:1", "group:2"]
    assertEqual(organizedGroups(server, [], settings)[0].id, "all", "all-hidden cannot trap guide")
    settings.groupSort = "manual"
    settings.groupOrder = ["group:2", "deleted", "group:2"]
    settings.hiddenGroups = []
    assertEqual(organizedGroups(server, [], settings)[0].id, "group:2", "manual order reconciles deleted groups")
    channels = [{id: "1", uuid: "a", name: "Zoo", number: "2.1", groupId: "1"}, {id: "2", uuid: "b", name: "Alpha", number: "2.2", groupId: "2"}]
    assertEqual(organizedChannels(channels, "group:1", {}, [], [], settings, "Alpha")[0].uuid, "b", "search across groups")
    assertEqual(organizedChannels(channels, "group:1", {}, [], [], settings, "")[0].uuid, "a", "clear restores group")
    settings.channelSort = "name"
    assertEqual(organizedChannels(channels, "all", {}, [], [], settings, "")[0].uuid, "b", "name sort")
    settings.favoriteOrder = ["b", "gone", "a"]
    assertEqual(organizedChannels(channels, "favorites", {a: true, b: true}, [], [], settings, "")[0].uuid, "b", "manual favorites")
    assertEqual(organizedChannels(channels, "recent", {}, ["a", "b"], [], settings, "")[0].uuid, "a", "recent not resorted")
    collections = normalizeCollections([{id: "c", name: "Mine", channels: ["2", "gone", "1", "1"]}])
    assertEqual(organizedGroups(server, collections, settings)[0].id, "collection:c", "collections first is absolute")
    settings.collectionsPosition = "last"
    allGroups = organizedGroups(server, collections, settings)
    assertEqual(allGroups[allGroups.count() - 1].id, "collection:c", "collections last respects manual group sort")
    assertEqual(organizedChannels(channels, "collection:c", {}, [], collections, settings, "").count(), 2, "collection restricted to current lineup")
    assertEqual(channelNumberIndex(channels, "02.20"), 1, "decimal number equivalence")
    assertEqual(channelNumberIndex(channels, "bad"), -1, "invalid number feedback")
    assertEqual(channelNumberIndex([{number: ""}], "0"), -1, "missing number is not zero")
    assertEqual(channelNumberSortKey("2.10"), channelNumberSortKey("02.1"), "decimal stable numeric identity")
    assertEqual(normalizeGuideSettings({historyDays: "bad"}).historyDays, 3, "malformed depth fallback")
    now = guideEpoch("2026-09-18T12:00:00Z")
    settings.historyDays = 30
    assertEqual(guideTimeClamp(now - 31 * 86400, now, settings), now - 30 * 86400, "bounded all-available horizon")
    p = normalizeProgram({id: 1, title: "Test", start_time: now, end_time: now + 600, is_live: "true", is_new: true, season: 2, episode: 3, categories: ["Kids", "Sports"]})
    assertEqual(p.is_live, invalid, "malformed live flag is unknown")
    assertEqual(programCategory(p), "kids", "source category precedence")
    assertEqual(programBadges(p, settings), "NEW S2E3", "truthful badges and episode")
    enriched = mergeProgramFacts(p, {title: "Enriched", startsAt: now + 60, endsAt: now + 999, key: "wrong"})
    assertEqual(enriched.startsAt, now, "detail metadata cannot move guide focus")
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
