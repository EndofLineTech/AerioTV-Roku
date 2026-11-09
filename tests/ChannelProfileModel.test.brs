sub main()
    channels = [{id: 10, uuid: "ten"}, {id: 11, uuid: "eleven"}, {id: 12, uuid: "twelve"}]
    profiles = [{id: 3, name: "Family", channels: [10, 12]}, {id: 4, name: "Empty", channels: []}]
    selected = profileRestrictedLineup(channels, profiles, "3")
    assertEqual(selected.ok, true, "assigned permitted profile loaded")
    assertEqual(selected.channels.count(), 2, "only profile members displayed")
    assertEqual(selected.channels[0].uuid, "ten", "authorized summary ordering retained")
    assertEqual(profileRestrictedLineup(channels, profiles, "4").channels.count(), 0, "empty profile does not fall back to all channels")
    assertEqual(profileRestrictedLineup(channels, profiles, "5").ok, false, "removed or unassigned profile fails closed")
    assertEqual(profileRestrictedLineup(channels, invalid, "3").ok, false, "failed membership load fails closed")
    assertEqual(profileRestrictedLineup(channels, profiles, "").channels.count(), 3, "server-authorized default preserved")
    assertEqual(profileRestrictedLineup(channels, [{id: 3, name: "Wrong", channels: [99]}], "3").channels.count(), 0, "membership cannot add unauthorized channels")
    assertEqual(profileRestrictedLineup(channels, [{id: 3, name: "Broken", channels: "all"}], "3").ok, false, "malformed membership fails closed")
    assertEqual(profileChoiceList(profiles, "3")[1].title, "[Selected] Family", "named permitted choices normalized")
    assertEqual(profileChoiceList(profiles, "3")[1].id, "3", "first profile ID travels with its label")
    assertEqual(profileChoiceList(profiles, "3")[2].id, "4", "second profile ID travels with its label")
    profiles.push({id: 5, name: "Other", channels: [11, 99]})
    union = profileUnionLineup(channels, profiles, [3, 5])
    assertEqual(union.ok, true, "multiple incoming channel profiles")
    assertEqual(union.channels.count(), 3, "profile membership union, never adds unauthorized IDs")
    assertEqual(union.channels[1].uuid, "eleven", "original channel order retained")
    assertEqual(profileUnionLineup(channels, profiles, [3, 7]).ok, false, "one missing profile fails whole request closed")
    assertEqual(profileUnionLineup(channels, profiles, [4]).channels.count(), 0, "empty profile union never grants default channels")
    assertEqual(profileUnionLineup(channels, profiles, [3, 3]).channels.count(), 2, "repeated profile does not duplicate channels")
    assertEqual(profileSelectionIdentity([5, 3, 5], ""), "3,5", "cache identity ignores order and repeated IDs")
    assertEqual(profileSelectionIdentity([], "3"), "3", "legacy cache scope remains stable")
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
