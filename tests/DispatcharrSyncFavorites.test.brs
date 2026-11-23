' Pure favorites adapter (e3e.7): server integer channel PKs <-> local UUIDs
' through the current authorized lineup, matching Android DsyncFavorites/DsyncGate.
sub main()
    channels = [{uuid: "u-a", id: "11"}, {uuid: "u-b", id: 12}, {uuid: "u-c", id: "13"}, {uuid: "u-d", id: 14}]

    category = ParseJson("{""updatedAt"":""2026-11-20T10:00:00Z"",""deviceId"":""peer"",""data"":{""ids"":[13,99,11,13],""futureMember"":[1]}}")
    read = dispatcharrSyncFavoritesRead(category)
    check(read.ok and FormatJson(read.ids) = "[13,99,11]", "read keeps server order, drops a duplicate id")
    check(not dispatcharrSyncFavoritesRead(ParseJson("{""deviceId"":""peer"",""data"":{""ids"":[1]}}")).ok, "a category without updatedAt is ignored")
    check(not dispatcharrSyncFavoritesRead(ParseJson("{""updatedAt"":""2026-11-20T10:00:00Z"",""deviceId"":""p"",""data"":{""ids"":[1,""2""]}}")).ok, "string ids are malformed, not coerced")
    check(not dispatcharrSyncFavoritesRead(ParseJson("{""updatedAt"":""2026-11-20T10:00:00Z"",""deviceId"":""p"",""data"":{""ids"":[0]}}")).ok, "non-positive ids are malformed")

    ' Apply with no unsent local change: take the server list, in server order.
    plan = dispatcharrSyncFavoritesApply(read.ids, ["u-b", "u-gone", "u-a"], channels)
    check(FormatJson(plan.uuids) = "[""u-c"",""u-a"",""u-gone""]", "server order applied; a favorite outside this lineup is kept")
    check(FormatJson(plan.dropped) = "[""u-b""]", "only lineup channels the server list dropped are removed")

    ' Unsent local change and a newer server copy: union, local order first.
    check(dispatcharrSyncFavoritesOnNewerPull(false) = "take-remote", "clean local state takes the server list")
    check(dispatcharrSyncFavoritesOnNewerPull(true) = "merge", "dirty favorites merge rows, never a blind overwrite")
    merged = dispatcharrSyncFavoritesMerge(["u-d", "u-a"], read.ids, channels)
    check(FormatJson(merged.uuids) = "[""u-d"",""u-a"",""u-c""]", "union keeps local order then server channels this device lacks")
    check(FormatJson(merged.carried) = "[99]", "an untranslatable server id is carried, not lost")

    ' Write: local favorites as server ids, carried server ids appended, cap 1000.
    wire = dispatcharrSyncFavoritesWireIds(["u-c", "u-gone", "u-a"], channels, read.ids)
    check(FormatJson(wire.ids) = "[13,11,99]", "local order translated; untranslatable server ids kept on the wire")
    check(not wire.complete and FormatJson(wire.unresolved) = "[""u-gone""]", "a local favorite outside the lineup stays local and is reported")
    many = []
    for i = 1 to 1200
        many.push(i)
    end for
    lineup = []
    local = []
    for i = 1 to 1200
        lineup.push({uuid: "c" + i.toStr(), id: i})
        local.push("c" + i.toStr())
    end for
    check(dispatcharrSyncFavoritesWireIds(local, lineup, []).ids.count() = 1000, "writes are capped at the 1000-id wire cap")

    ' Encode round-trips unknown data members and stamps the category.
    encoded = dispatcharrSyncFavoritesCategory(category, [13, 11], "2026-11-23T01:02:03Z", "roku-device")
    check(encoded.updatedAt = "2026-11-23T01:02:03Z" and encoded.deviceId = "roku-device", "category carries this write's stamp and device")
    check(FormatJson(encoded.data.ids) = "[13,11]" and encoded.data.doesExist("futureMember"), "only ids are replaced; unknown data members round-trip")
    check(category.data.ids.count() = 4, "the pulled category is not mutated")
    ' Local carrier: favoriteIds hold lineup channel ids; off-lineup ids survive.
    entries = dispatcharrSyncFavoritesLocalEntries(["13", "500", "11"], channels)
    check(FormatJson(entries) = "[""u-c"",""#500"",""u-a""]", "local ids map to lineup UUIDs; an off-lineup id is kept as an opaque entry")
    check(FormatJson(dispatcharrSyncFavoritesLocalIds(entries, channels)) = "[""13"",""500"",""11""]", "entries map back to the exact stored id text")

    ' Profile-owned dirty/acknowledged state stays inside the account preferences.
    prefs = {favoriteIds: ["11", "500"], other: "keep"}
    state = dispatcharrSyncFavoritesState(prefs)
    check(not state.known and not state.pending and state.acknowledgedAt = 0, "missing sync record is unknown, clean and unacknowledged")
    marked = dispatcharrSyncFavoritesWithState(prefs, true, 7)
    state = dispatcharrSyncFavoritesState(marked)
    check(state.known and state.pending and state.acknowledgedAt = 7 and marked.other = "keep" and prefs.doesExist("dispatcharrSyncFavorites") = false, "state update keeps other preferences and does not mutate the input")
    check(dispatcharrSyncFavoritesState({dispatcharrSyncFavorites: {pending: "yes", acknowledgedAt: 1.5}}).pending = false, "malformed state never invents pending intent")

    ' Pulls: newer clean server list wins; never deletes untranslatable ids.
    newer = ParseJson("{""updatedAt"":""2026-11-20T10:00:00Z"",""deviceId"":""peer"",""data"":{""ids"":[13,99,11]}}")
    stamp = dispatcharrSyncIsoEpoch(newer.updatedAt)
    clean = dispatcharrSyncFavoritesWithState({favoriteIds: ["12", "500", "11"]}, false, 1)
    plan = dispatcharrSyncFavoritesPullPlan(clean, newer, channels)
    check(plan.applied and plan.changed and FormatJson(plan.preferences.favoriteIds) = "[""13"",""11"",""500""]", "clean newer pull applies server order, drops a removed lineup channel and keeps an off-lineup favorite")
    check(not dispatcharrSyncFavoritesState(plan.preferences).pending and dispatcharrSyncFavoritesState(plan.preferences).acknowledgedAt = stamp, "clean pull records the applied server stamp without pending intent")
    again = dispatcharrSyncFavoritesPullPlan(plan.preferences, newer, channels)
    check(not again.applied and not again.changed, "an already applied stamp is not reapplied")
    dirty = dispatcharrSyncFavoritesWithState({favoriteIds: ["14", "11"]}, true, 1)
    plan = dispatcharrSyncFavoritesPullPlan(dirty, newer, channels)
    check(plan.applied and FormatJson(plan.preferences.favoriteIds) = "[""14"",""11"",""13""]" and dispatcharrSyncFavoritesState(plan.preferences).pending, "dirty newer pull unions local first and keeps the unsent change pending")
    first = dispatcharrSyncFavoritesPullPlan({favoriteIds: ["14"]}, newer, channels)
    check(first.applied and FormatJson(first.preferences.favoriteIds) = "[""14"",""13"",""11""]" and dispatcharrSyncFavoritesState(first.preferences).pending, "first sync of existing local favorites merges instead of replacing them")
    empty = dispatcharrSyncFavoritesPullPlan({favoriteIds: []}, newer, channels)
    check(empty.applied and FormatJson(empty.preferences.favoriteIds) = "[""13"",""11""]" and not dispatcharrSyncFavoritesState(empty.preferences).pending, "first sync with no local favorites takes the server list")
    bad = ParseJson("{""updatedAt"":""2026-11-20T10:00:00Z"",""data"":{""ids"":[1.5]}}")
    check(not dispatcharrSyncFavoritesPullPlan(clean, bad, channels).applied, "a malformed pulled category is ignored, never applied")
    check(not dispatcharrSyncFavoritesPullPlan(clean, invalid, channels).applied, "an absent category changes nothing")
    check(not dispatcharrSyncFavoritesPullPlan(clean, newer, []).applied, "without a current lineup nothing is applied or acknowledged")

    ' Acknowledgement clears pending only for the exact written intent.
    pending = dispatcharrSyncFavoritesWithState({favoriteIds: ["11"]}, true, 5)
    intent = dispatcharrSyncFavoritesIntent(pending)
    acked = dispatcharrSyncFavoritesAcknowledge(pending, intent, 9)
    check(not dispatcharrSyncFavoritesState(acked).pending and dispatcharrSyncFavoritesState(acked).acknowledgedAt = 9, "matching acknowledgement clears pending and records the written stamp")
    edited = mergeAccountPreferences(pending, {favoriteIds: ["11", "12"]})
    acked = dispatcharrSyncFavoritesAcknowledge(edited, intent, 9)
    check(dispatcharrSyncFavoritesState(acked).pending and dispatcharrSyncFavoritesState(acked).acknowledgedAt = 9, "an edit made during the write keeps pending intent")
    check(dispatcharrSyncFavoritesState(dispatcharrSyncFavoritesAcknowledge(dispatcharrSyncFavoritesWithState(pending, true, 20), intent, 9)).acknowledgedAt = 20, "acknowledged stamp never regresses")
    check(dispatcharrSyncFavoritesIntent({favoriteIds: ["11"]}) <> dispatcharrSyncFavoritesIntent({favoriteIds: ["12"]}), "intent follows the ordered favorites")
    print "ALL TESTS PASSED"
end sub

sub check(condition as boolean, label as string)
    if not condition
        print "FAIL: "; label
        stop
    end if
end sub
