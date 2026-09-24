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
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
