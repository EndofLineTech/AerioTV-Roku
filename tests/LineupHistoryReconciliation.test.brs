sub main()
    raw = ParseJson("{}")
    raw["favoriteIds"] = ["8"]
    raw["recent"] = ["8"]
    raw["aacChannels"] = ["8"]
    raw["lastWatched"] = "8"
    raw["profileSettings"] = {themePreset: "forest"}
    raw["foreign"] = ParseJson("{" + chr(34) + "wide" + chr(34) + ":12345}")
    before = strictJsonEncode(raw).text
    plan = lineupHistoryReconciliationPlan(raw, [{uuid: "8"}])
    check(not plan.changed and strictJsonEncode(plan.preferences).text = before, "unchanged lineup never adopts normalization aliases or expands sparse settings")
    plan = lineupHistoryReconciliationPlan(raw, [{uuid: "80"}])
    check(plan.changed and plan.preferences.recent.count() = 0 and plan.preferences.aacChannels.count() = 0 and plan.preferences.lastWatched = "", "removed channels prune only supported watch-history fields")
    check(strictJsonEncode(plan.preferences["favoriteIds"]).text = strictJsonEncode(raw["favoriteIds"]).text and plan.preferences["profileSettings"].count() = 1, "history refresh cannot rewrite favorites or expand profile settings")
    check(strictJsonEncode(plan.preferences["foreign"]).text = strictJsonEncode(raw["foreign"]).text and strictJsonEncode(raw).text = before, "untouched typed extensions and caller data remain exact")
    raw["reminders"] = [{channelUuid: "8", privateExtension: {keep: true}}, {futureShape: "retain"}]
    plan = lineupHistoryReconciliationPlan(raw, [{uuid: "8"}])
    check(not plan.changed, "unchanged history never normalizes or drops unknown reminder fields")
    plan = lineupHistoryReconciliationPlan(raw, [{uuid: "80"}])
    check(plan.preferences["reminders"].count() = 1 and plan.preferences["reminders"][0].futureShape = "retain", "history pruning preserves future entries rather than interpreting them as corrupt reminders")
    raw["aacchannels"] = ["80"]
    before = strictJsonEncode(raw).text
    plan = lineupHistoryReconciliationPlan(raw, [{uuid: "80"}])
    aliases = 0
    for each field in raw.keys()
        if lcase(field) = "aacchannels" then aliases++
    end for
    if aliases > 1
        check(not plan.ok and not plan.changed and strictJsonEncode(plan.preferences).text = before, "native conflicting case aliases fail retained without guessing or partially applying a prune")
    else
        check(plan.ok and strictJsonEncode(raw).text = before, "host case-insensitive maps still keep the caller immutable")
    end if
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
