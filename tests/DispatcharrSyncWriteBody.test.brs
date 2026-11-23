sub main()
    m.syncWriteHostInterpreter = true
    m.syncWriteParser = function(raw as string) as dynamic
        return ParseJson(raw)
    end function
    original = syncWriteBodyFixture()
    candidate = syncWriteBodyFixture()
    recents = "{""updatedAt"":""2026-11-14T17:00:00Z"",""data"":{""rows"":[[101,1794675600],[102,1794675500]]}}"
    original["categories"]["recents"] = ParseJson(recents)
    candidate["categories"]["recents"] = ParseJson(recents)
    candidate["updatedAt"] = "2026-11-14T18:00:00Z"
    candidate["categories"]["profiles"]["updatedAt"] = candidate["updatedAt"]
    candidate["categories"]["profiles"]["deviceId"] = "roku-device"
    candidate["categories"]["profiles"]["data"]["rows"][0][2] = "New name"
    before = strictJsonEncode(original).text
    result = dispatcharrSyncCheckedWriteBody(original, candidate, ["profiles"])
    if m.syncWriteHostInterpreter
        check(not result.ok, "host lowercasing cannot qualify a wire body; native success is required")
    else
        if not result.ok then print "[profile-probe] write-body-stage="; result.reason
        check(result.ok and result.body <> "" and not result.allowWrite, "checked body is structural evidence only, never session/key/migration or merge permission")
    end if
    check(dispatcharrSyncPreservedMembers({kept: [1, true, invalid]}, {kept: [1, true, invalid]}, []), "unchanged typed unsupported data is retained")
    check(not dispatcharrSyncPreservedMembers({kept: 1}, {kept: 2}, []), "changed unsupported data is refused")
    check(dispatcharrSyncPreservedMembers(original["categories"], candidate["categories"], ["profiles"]), "Profiles write preserves shared recents")
    candidate["categories"]["recents"].data.rows = []
    check(not dispatcharrSyncPreservedMembers(original["categories"], candidate["categories"], ["profiles"]), "Profiles write cannot clear shared recents")
    candidate["categories"]["recents"] = ParseJson(recents)
    check(strictJsonEncode(original).text = before, "wire verification never mutates the freshly read original")
    if not m.syncWriteHostInterpreter
        precision = ParseJson("{""MixedCase"":[1.3,1.0,1794675600000,null,""😀""],""case"":1,""Case"":2}", "d")
        original["categories"]["FutureCategory"]["data"] = precision
        candidate["categories"]["FutureCategory"]["data"] = ParseJson(strictJsonEncode(precision).text, "d")
        check(dispatcharrSyncCheckedWriteBody(original, candidate, ["profiles"]).ok, "native checked body preserves binary64, integral doubles, milliseconds, emoji, null and case-distinct future keys")
        changed = ParseJson(strictJsonEncode(candidate).text, "d")
        changed["categories"]["FutureCategory"]["data"]["MixedCase"][1] = 1
        check(not dispatcharrSyncCheckedWriteBody(original, changed, ["profiles"]).ok, "native preservation refuses integral-double to integer coercion in unsupported data")
        changed = ParseJson(strictJsonEncode(candidate).text, "d")
        changed["categories"]["FutureCategory"]["data"].delete("Case")
        check(not dispatcharrSyncCheckedWriteBody(original, changed, ["profiles"]).ok, "native preservation refuses loss of a case-distinct future member")
    end if
    for each change in ["future-envelope", "future-category", "removed-category", "extra-category", "schema", "timestamp", "rebuilt-stamp", "rebuilt-device", "bad-row", "floating-stamp", "floating-order", "bad-tombstone", "floating-removed-id", "unknown-rebuild", "duplicate-rebuild", "empty-rebuild", "malformed-original"]
        original = syncWriteBodyFixture()
        proposed = syncWriteBodyFixture()
        proposed["categories"]["profiles"]["deviceId"] = "roku-device"
        rebuilt = ["profiles"]
        if change = "future-envelope" then proposed["FutureEnvelope"] = false
        if change = "future-category" then proposed["categories"]["FutureCategory"]["data"]["FutureCase"] = "changed"
        if change = "removed-category" then proposed["categories"].delete("FutureCategory")
        if change = "extra-category" then proposed["categories"]["AnotherCategory"] = proposed["categories"]["profiles"]
        if change = "schema" then proposed["schemaVersion"] = 4
        if change = "timestamp" then proposed["updatedAt"] = "2026-11-14T18:00:00+0000"
        if change = "rebuilt-stamp" then proposed["categories"]["profiles"]["updatedAt"] = "2026-11-14T18:00:00+0000"
        if change = "rebuilt-device" then proposed["categories"]["profiles"].delete("deviceId")
        if change = "bad-row" then proposed["categories"]["profiles"]["data"]["rows"] = [["7", "Alice"]]
        if change = "floating-stamp" then proposed["categories"]["profiles"]["data"]["rows"][0][7] = 1.5
        if change = "floating-order" then proposed["categories"]["profiles"]["data"]["rows"][0].append([invalid, 1.5])
        if change = "bad-tombstone" then proposed["categories"]["profiles"]["data"]["removed"] = [["Alice", 1.5]]
        if change = "floating-removed-id" then proposed["categories"]["profiles"]["data"]["removed"] = [["Alice", 1234, 7.5]]
        if change = "unknown-rebuild" then rebuilt = ["FutureCategory"]
        if change = "duplicate-rebuild" then rebuilt = ["profiles", "profiles"]
        if change = "empty-rebuild" then rebuilt = []
        if change = "malformed-original" then original["schemaVersion"] = 4
        check(not dispatcharrSyncCheckedWriteBody(original, proposed, rebuilt).ok, "checked write refuses " + change + " rather than overwriting unowned or unreadable wire data")
    end for
    original = syncWriteBodyFixture()
    proposed = syncWriteBodyFixture()
    original["categories"]["profiles"]["deviceId"] = "roku-device"
    proposed["categories"]["profiles"]["deviceId"] = "roku-device"
    ' Native string() returns "" at this length, so build it by doubling.
    padding = "x"
    while len(padding) < 131072
        padding += padding
    end while
    original["categories"]["FutureCategory"]["data"]["padding"] = padding
    proposed["categories"]["FutureCategory"]["data"]["padding"] = original["categories"]["FutureCategory"]["data"]["padding"]
    result = dispatcharrSyncCheckedWriteBody(original, proposed, ["profiles"])
    check(not result.ok and result.state = "too-large" and result.body = "", "absolute write cap classifies the untouched oversized body before reparse")
    original["categories"]["FutureCategory"]["data"].delete("padding")
    proposed["categories"]["FutureCategory"]["data"].delete("padding")
    m.syncWriteParser = function(raw as string) as dynamic
        return {}
    end function
    check(not dispatcharrSyncCheckedWriteBody(original, proposed, ["profiles"]).ok, "the exact encoded body must independently reparse and revalidate before transport")
    m.syncWriteParser = invalid
    syncWriteFavoritesChecks()
    print "ALL TESTS PASSED"
end sub

sub syncWriteFavoritesChecks()
    channels = [{uuid: "u-a", id: "11"}, {uuid: "u-b", id: "12"}, {uuid: "u-c", id: "13"}]
    original = syncWriteBodyFixture()
    original["categories"]["favorites"] = ParseJson("{""updatedAt"":""2026-11-14T17:00:00Z"",""deviceId"":""peer"",""data"":{""ids"":[13,99],""FutureMember"":1},""extra"":{""keep"":true}}")
    favorites = {ids: ["11", "13", "500"], channels: channels, acknowledgedAt: dispatcharrSyncIsoEpoch("2026-11-14T17:00:00Z")}
    plan = dispatcharrSyncFavoritesWritePlan(original, favorites)
    check(plan.ok and not plan.needsLocalCommit and FormatJson(plan.ids) = "[11,13,99]" and not plan.unchanged, "acknowledged server list: local order translated, untranslatable server id carried, off-lineup local id not invented")
    favorites.acknowledgedAt = 0
    plan = dispatcharrSyncFavoritesWritePlan(original, favorites)
    check(plan.ok and not plan.needsLocalCommit, "a newer server list already contained locally needs no local commit")
    favorites.ids = ["11"]
    plan = dispatcharrSyncFavoritesWritePlan(original, favorites)
    check(plan.ok and plan.needsLocalCommit, "a newer server lineup favorite missing locally is merged locally before any PUT can drop it")
    favorites.acknowledgedAt = dispatcharrSyncIsoEpoch("2026-11-14T17:00:00Z")
    favorites.ids = ["13"]
    plan = dispatcharrSyncFavoritesWritePlan(original, favorites)
    check(plan.ok and FormatJson(plan.ids) = "[13,99]" and plan.unchanged, "identical wire ids acknowledge without a redundant PUT")
    favorites.channels = []
    check(not dispatcharrSyncFavoritesWritePlan(original, favorites).ok, "no current lineup cannot write favorites")
    favorites.channels = channels
    original["categories"]["favorites"]["data"]["ids"] = [1.5]
    check(not dispatcharrSyncFavoritesWritePlan(original, favorites).ok, "a malformed peer favorites category is preserved, never rebuilt")
    original["categories"].delete("favorites")
    plan = dispatcharrSyncFavoritesWritePlan(original, favorites)
    check(plan.ok and plan.previous = invalid and FormatJson(plan.ids) = "[13]" and not plan.unchanged, "absent category is created from local favorites")

    base = syncWriteBodyFixture()
    base["categories"]["favorites"] = ParseJson("{""updatedAt"":""2026-11-14T17:00:00Z"",""deviceId"":""peer"",""data"":{""ids"":[13],""FutureMember"":1},""extra"":{""keep"":true}}")
    for each change in ["duplicate", "floating", "zero", "string", "over-cap", "device", "stamp", "future-data", "extra", "profiles-changed", "both-unknown", "missing-category"]
        proposed = syncWriteBodyFixture()
        proposed["categories"]["favorites"] = dispatcharrSyncFavoritesCategory(base["categories"]["favorites"], [11, 13], "2026-11-14T18:00:00Z", "roku-device")
        rebuilt = ["favorites"]
        if change = "duplicate" then proposed["categories"]["favorites"]["data"]["ids"] = [11, 11]
        if change = "floating" then proposed["categories"]["favorites"]["data"]["ids"] = [11.5]
        if change = "zero" then proposed["categories"]["favorites"]["data"]["ids"] = [0]
        if change = "string" then proposed["categories"]["favorites"]["data"]["ids"] = ["11"]
        if change = "over-cap"
            many = []
            for i = 1 to 1001
                many.push(i)
            end for
            proposed["categories"]["favorites"]["data"]["ids"] = many
        end if
        if change = "device" then proposed["categories"]["favorites"]["deviceId"] = "other"
        if change = "stamp" then proposed["categories"]["favorites"]["updatedAt"] = "2026-11-14T18:00:00+0000"
        if change = "future-data" then proposed["categories"]["favorites"]["data"].delete("FutureMember")
        if change = "extra" then proposed["categories"]["favorites"]["extra"] = {keep: false}
        if change = "profiles-changed" then proposed["categories"]["profiles"]["data"]["rows"][0][2] = "Changed"
        if change = "both-unknown" then rebuilt = ["favorites", "FutureCategory"]
        if change = "missing-category" then proposed["categories"].delete("favorites")
        check(not dispatcharrSyncCheckedWriteBody(base, proposed, rebuilt).ok, "favorites write refuses " + change)
        if change <> "profiles-changed" and change <> "both-unknown" and change <> "missing-category"
            check(not dispatcharrSyncFavoritesCategoryWritable(base["categories"]["favorites"], proposed["categories"]["favorites"], "roku-device"), "favorites category gate refuses " + change)
        end if
    end for
    proposed = syncWriteBodyFixture()
    proposed["categories"]["favorites"] = dispatcharrSyncFavoritesCategory(base["categories"]["favorites"], [11, 13], "2026-11-14T18:00:00Z", "roku-device")
    ' Host keys are lowercased on assignment, so exact-name preservation is
    ' asserted only by the native probe.
    if not m.syncWriteHostInterpreter
        check(dispatcharrSyncFavoritesCategoryWritable(base["categories"]["favorites"], proposed["categories"]["favorites"], "roku-device"), "rebuilt favorites keep unknown data members and extra with unique int32 ids")
        check(dispatcharrSyncCheckedWriteBody(base, proposed, ["favorites"]).ok, "native favorites-only checked body passes with profiles and future data untouched")
    end if
    check(dispatcharrSyncFavoritesCategoryWritable(invalid, dispatcharrSyncFavoritesCategory(invalid, [11], "2026-11-14T18:00:00Z", "roku-device"), "roku-device"), "a new favorites category needs only strict ids, stamp and device")
    check(not dispatcharrSyncCheckedWriteBody(base, proposed, ["favorites", "favorites"]).ok, "a duplicated rebuild claim is refused")
end sub

function syncWriteBodyFixture() as object
    return ParseJson("{""schemaVersion"":3,""deviceId"":""roku-device"",""platform"":""roku"",""appVersion"":""1"",""updatedAt"":""2026-11-14T17:00:00Z"",""categories"":{""profiles"":{""updatedAt"":""2026-11-14T17:00:00Z"",""data"":{""rows"":[[7,""Alice"",""Alice"",""none"","""","""",""user"",1794675600]]}},""FutureCategory"":{""updatedAt"":""2026-11-14T16:00:00+00:00"",""data"":{""FutureCase"":[true,null,1794675600000]}}},""FutureEnvelope"":true}")
end function

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
