sub main()
    m.rosterWriteHostInterpreter = true
    data = {rows: [[7, "Alice"], [8, "Bob", "Bob Name", "none", "", "", "user", 100, {}, 2, {future: [true, invalid]}], [8, "Bob", "Newest", "none", "", "", "user", 200, {}, 1, {future: "new"}]], removed: [["OLD", 10], ["gone", 300, 9], ["bad", "invalid"]]}
    snapshot = strictJsonEncode(data).text
    result = dispatcharrSyncRosterWriteBase(data, [["GONE", 400], ["local", 250]], 500)
    check(result.ok and not result.allowWrite and result.rows.count() = 2 and result.removed.count() = 3, "remote write base deduplicates newest rows and unions local/remote tombstones without authorizing a PUT")
    check(result.rows[0][2] = "" and result.rows[0][6] = "user" and result.rows[0][7] = 0 and result.rows[0][9] = 0, "remote users absent locally retain their rows with typed default role/avatar/order/stamp")
    check(result.rows[1][2] = "Newest" and result.rows[1][10].future = "new", "newest duplicate user row retains its exact future tail")
    check(result.removed[1][0] = "gone" and result.removed[1][1] = 400 and result.removed[1][2] = 9, "newer local tombstone keeps a known server optional ID without inventing one")
    check(strictJsonEncode(data).text = snapshot, "remote write planning never mutates freshly read rows or tombstones")
    result = dispatcharrSyncRosterWriteBase({rows: [[8, "Bob", "", "none", "", "", "user", 100]], removed: [["bob", 100]]}, [], 500)
    check(result.ok and result.rows.count() = 0 and result.removed.count() = 1, "equal or newer tombstones suppress server rows before writing")
    result = dispatcharrSyncRosterWriteBase({rows: [[8, "Bob", "", "none", "", "", "user", 101]], removed: [["bob", 100]]}, [["bob", 99]], 500)
    check(result.ok and result.rows.count() = 1 and result.removed.count() = 0, "intentional newer re-add clears older local and remote tombstones")
    result = dispatcharrSyncRosterWriteBase({rows: [], removed: [["expired", 1]]}, [["recent", 7776002]], 7776002)
    check(result.ok and result.removed.count() = 1 and result.removed[0][0] = "recent", "tombstones expire after ninety days without deleting recent local intent")
    result = dispatcharrSyncRosterWriteBase({rows: [[8, "Bob", "", "numbers", "malformed", "bad", "user", 100]]}, [], 500)
    check(not result.ok, "unpreservable malformed remote PIN blocks rebuilding rather than clearing another user's protection")
    check(not dispatcharrSyncRosterWriteBase({rows: [["8", "Bob"]]}, [], 500).ok, "malformed remote category is never treated as empty")
    check(not dispatcharrSyncRosterWriteBase({rows: []}, [["local", 1.5]], 500).ok, "malformed local removal intent cannot be silently dropped")
    result = dispatcharrSyncRosterWriteBase({rows: [[8, "Bob", string(60, "x")]]}, [], 500)
    check(len(result.rows[0][2]) = 40, "rebuilt remote display names obey the forty-byte wire limit")
    store = rosterWriteLocalFixture()
    remote = {rows: [[7, "Alice", "Remote Alice", "none", "", "", "user", 200, {}, 0, {future: "retain"}], [9, "Carol", "Carol", "none", "", "", "user", 250]]}
    result = dispatcharrSyncProfilesWritePlan(store, remote, true, 500, 0, 400)
    check(result.ok and not result.allowWrite and result.data.rows.count() = 3 and result.localPlan.store.profiles[0].updatedAt = 200, "writer plans through existing newer-row merge while retaining remote-only users and their own stamps")
    check(result.data.rows[0][2] = "Remote Alice" and result.data.rows[0][7] = 200 and result.data.rows[0][10].future = "retain", "local merged row carries server stamp and future same-ID tail rather than restamping to now")
    result = dispatcharrSyncProfilesWritePlan(store, remote, true, 500, 200, 400)
    check(result.ok and result.data.rows.count() = 2 and result.localPlan.store.profiles.count() = 2, "acknowledged old local user missing from a nonempty newer server roster stays local but is not resurrected remotely")
    store.profiles[1] = setCanonicalPreference(store.profiles[1], "updatedAt", 450)
    result = dispatcharrSyncProfilesWritePlan(store, remote, true, 500, 200, 400)
    check(result.ok and result.data.rows.count() = 3 and result.data.rows[2][7] = 450, "genuine unsent newer local edit survives stale-device suppression without replacing its stored timestamp")
    store = rosterWriteLocalFixture()
    result = dispatcharrSyncProfilesWritePlan(store, {rows: [], removed: [["bob", 300]]}, true, 500, 0, 400)
    check(not result.ok and result.reason = "cleanup-required" and result.localPlan.removed.count() = 1, "writer cannot emit a tombstoned local holder until real local runtime/key/blob cleanup is committed")
    store.profiles[1] = setCanonicalPreference(store.profiles[1], "updatedAt", 450)
    result = dispatcharrSyncProfilesWritePlan(store, {rows: [], removed: [["bob", 300]]}, true, 500, 0, 400)
    check(result.ok and result.data.rows.count() = 2 and result.data.removed.count() = 0, "a newer intentional local re-add clears the old server tombstone before emitting its own row")
    store = rosterWriteLocalFixture()
    result = dispatcharrSyncProfilesWritePlan(store, {rows: [], removed: [["alice", 300]]}, true, 500, 0, 400)
    check(result.ok and result.localPlan.store.profiles.count() = 2 and result.data.rows.count() = 1 and result.data.rows[0][1] = "Bob", "covered default stays local but is not blindly re-sent as an unstamped intentional re-add")
    check(not dispatcharrSyncProfilesWritePlan(store, remote, false, 500, 0, 400).ok, "Profiles-Off never rebuilds the roster")
    store.active = store.profiles[1].id
    store.profiles[1] = setCanonicalPreference(store.profiles[1], "role", "child")
    check(not dispatcharrSyncProfilesWritePlan(store, remote, true, 500, 0, 400).ok, "Child never rebuilds profiles even when a pending local edit exists")
    store = rosterWriteLocalFixture()
    remote = {rows: [[7, "Alice", "Remote Alice", "none", "", "", "user", 200, {futureAvatar: {keep: true}}, 0]]}
    result = dispatcharrSyncProfilesWritePlan(store, remote, true, 500, 0, 400)
    check(result.ok and result.data.rows[0][8].futureAvatar.keep, "unclaimed local avatar retains the exact future server avatar descriptor rather than normalizer-stripped data")
    store = rosterWriteLocalFixture()
    store.profiles[0] = setCanonicalPreference(store.profiles[0], "order", 2)
    store.profiles[1] = setCanonicalPreference(store.profiles[1], "order", 0)
    result = dispatcharrSyncProfilesWritePlan(store, {rows: []}, true, 500, 0, 0)
    check(result.ok and result.data.rows[0][1] = "Bob" and result.data.rows[0][9] = 0 and result.data.rows[1][1] = "Alice" and result.data.rows[1][9] = 1, "writer uses the actual sorted visible list index rather than backing-array insertion order")
    store = rosterWriteLocalFixture()
    remote = {rows: [[7, "Alice", "Alice", "none", "", "", "child", 200]]}
    result = dispatcharrSyncProfilesWritePlan(store, remote, true, 500, 0, 400)
    check(not result.ok and result.reason = "protection-changed" and result.localPlan.store.profiles[0].role = "child", "a newly imported active Child role blocks writing and returns the real protection plan for controller settlement")
    if not m.rosterWriteHostInterpreter
        store = rosterWriteLocalFixture()
        original = ParseJson("{""schemaVersion"":3,""deviceId"":""phone"",""platform"":""android"",""appVersion"":""1"",""updatedAt"":""2026-11-14T17:00:00Z"",""categories"":{""profiles"":{""updatedAt"":""2026-11-14T17:00:00Z"",""data"":{""rows"":[[7,""Alice"",""Remote Alice"",""none"","""","""",""user"",200,{},0,{""FutureTail"":1.3}]],""FutureRoster"":{""Case"":1,""case"":2}},""extra"":{""Keep"":true}},""FutureCategory"":{""updatedAt"":""2026-11-14T16:00:00Z"",""data"":{""FutureSetting"":1.0}}},""FutureEnvelope"":1794675600000}", "d")
        before = strictJsonEncode(original).text
        result = dispatcharrSyncPrepareProfilesWrite(original, store, true, 1794676000, 0, "roku-device", "1")
        check(result.ok and result.body <> "" and not result.allowWrite and result.localPlan.store.profiles[0].updatedAt = 200, "native assembly connects typed roster merge to the exact checked body without granting transport/session authority")
        parsed = ParseJson(result.body, "d")
        check(parsed["platform"] = "roku" and parsed["deviceId"] = "roku-device" and parsed["categories"]["profiles"]["deviceId"] = "roku-device", "rebuilt envelope and category carry actual writer device metadata")
        check(dispatcharrSyncWireEqual(parsed["categories"]["FutureCategory"], original["categories"]["FutureCategory"]) and parsed["categories"]["profiles"]["extra"]["Keep"] and dispatcharrSyncWireEqual(parsed["categories"]["profiles"]["data"]["FutureRoster"], original["categories"]["profiles"]["data"]["FutureRoster"]), "native assembly retains unknown envelope/category/data and exact typed future members")
        check(strictJsonEncode(original).text = before, "native assembly never edits the latest provider value in place")
        repeated = dispatcharrSyncPrepareProfilesWrite(parsed, result.localPlan.store, true, 1794676100, result.maximumSentStamp, "roku-device", "1")
        check(repeated.ok and repeated.unchanged and not repeated.needsLocalCommit, "native exact typed unchanged profiles data may acknowledge without rebuilding server timestamps")
    end if
    print "ALL TESTS PASSED"
end sub

function rosterWriteLocalFixture() as object
    store = defaultUserProfileStore("slot-a")
    a = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "Alice", user_level: 1}, 1)
    b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "Bob", user_level: 1}, 1)
    b = setCanonicalPreference(b, "isDefault", false)
    a = setCanonicalPreference(a, "updatedAt", 100)
    b = setCanonicalPreference(b, "updatedAt", 100)
    store.profiles = [a, b]
    store.active = a.id
    return store
end function

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
