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
    print "ALL TESTS PASSED"
end sub

sub check(condition as boolean, label as string)
    if not condition
        print "FAIL: "; label
        stop
    end if
end sub
