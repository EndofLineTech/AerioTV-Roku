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
    print "ALL TESTS PASSED"
end sub

function syncWriteBodyFixture() as object
    return ParseJson("{""schemaVersion"":3,""deviceId"":""roku-device"",""platform"":""roku"",""appVersion"":""1"",""updatedAt"":""2026-11-14T17:00:00Z"",""categories"":{""profiles"":{""updatedAt"":""2026-11-14T17:00:00Z"",""data"":{""rows"":[[7,""Alice"",""Alice"",""none"","""","""",""user"",1794675600]]}},""FutureCategory"":{""updatedAt"":""2026-11-14T16:00:00+00:00"",""data"":{""FutureCase"":[true,null,1794675600000]}}},""FutureEnvelope"":true}")
end function

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
