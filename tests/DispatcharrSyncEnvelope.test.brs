sub main()
    value = ParseJson("{""schemaVersion"":3,""deviceId"":""device"",""platform"":""android"",""appVersion"":""1"",""updatedAt"":""2026-11-11T18:00:00Z"",""categories"":{""profiles"":{""updatedAt"":""2026-11-11T18:00:00Z"",""data"":{""rows"":[[7,""Alice""]]}},""FutureCategory"":{""updatedAt"":""2026-11-11T17:00:00+00:00"",""data"":{""FutureCase"":[1,true,null]},""extra"":{""FutureExtra"":true}}},""FutureEnvelope"":true}")
    before = FormatJson(value)
    read = dispatcharrSyncEnvelopeRead(value)
    check(read.ok and read.profilesState = "ready" and read.profiles.rows[0].username = "Alice", "complete envelope exposes validated roster candidate")
    check(read.updatedAt = 1794420000 and read.malformedCategories.count() = 0 and not read.allowWrite, "ISO metadata validated without enabling writes")
    check(FormatJson(value) = before and FormatJson(read.raw) = before, "unknown envelope/category data remains untouched")
    for each field in ["deviceId", "platform", "appVersion", "updatedAt", "categories", "schemaVersion"]
        broken = copyJson(value)
        broken.delete(field)
        check(not dispatcharrSyncEnvelopeRead(broken).ok, "missing required envelope member rejects key")
    end for
    for each stamp in ["invalid", "2026-02-30T18:00:00Z", "2026-11-11T25:00:00Z", 1794420000]
        broken = copyJson(value)
        broken = setCanonicalPreference(broken, "updatedAt", stamp)
        check(not dispatcharrSyncEnvelopeRead(broken).ok, "malformed or numeric envelope timestamp rejected")
    end for
    broken = copyJson(value)
    broken.categories.profiles.data = {rows: [["7", "Alice"]]}
    read = dispatcharrSyncEnvelopeRead(broken)
    check(read.ok and read.profilesState = "invalid" and read.malformedCategories.count() = 1 and read.profiles = invalid, "bad profiles category cannot apply but does not erase other categories")
    broken = copyJson(value)
    broken.categories.profiles.extra = []
    check(dispatcharrSyncEnvelopeRead(broken).profilesState = "invalid", "nonobject category extra is malformed")
    broken = copyJson(value)
    broken.categories.delete("profiles")
    check(dispatcharrSyncEnvelopeRead(broken).profilesState = "absent", "missing profiles is explicitly distinct from malformed")
    broken = setCanonicalPreference(value, "schemaVersion", 4)
    check(dispatcharrSyncEnvelopeRead(broken).state = "newer", "future envelope never downgraded")
    broken = setCanonicalPreference(value, "schemaVersion", 2)
    check(not dispatcharrSyncEnvelopeRead(broken).ok, "legacy schema under canonical key never treated as empty v3")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
