sub main()
    hash = string(64, "a")
    salt = string(32, "b")
    raw = {rows: [[7, "Alice", "Alice custom", "directions", hash, salt, "child", 100, {icon: "paw", color: "orange"}, 2, {FutureCase: true}], [8, "Bob"]], removed: [["LEE", 150, 9], ["lee", 200], ["", 100], ["bad", "100"], "bad", ["idbad", 200, "10"]], FutureData: true}
    before = FormatJson(raw)
    decoded = dispatcharrSyncRosterDecode(raw)
    check(decoded.ok and decoded.rows.count() = 2 and decoded.removed.count() = 2, "roster rows and valid deduplicated tombstones decoded")
    first = decoded.rows[0]
    check(first.userId = 7 and first.username = "Alice" and first.role = "child" and first.updatedAt = 100 and first.order = 2, "typed identity role stamp and order decoded")
    check(first.pinAction = "replace" and first.pinType = "directions" and first.pinHash = hash and first.pinSalt = salt, "valid imported v2 PIN replaces only when merge policy permits")
    check(first.avatarPresent and first.avatar.icon = "paw" and first.raw[10].FutureCase, "avatar presence and future row tails retained")
    check(decoded.rows[1].updatedAt = 0 and decoded.rows[1].role = "" and decoded.rows[1].order = -1 and not decoded.rows[1].avatarPresent, "older sparse rows keep local role/avatar/order and zero stamp")
    check(decoded.removed[0].username = "lee" and decoded.removed[0].removedAt = 200 and not decoded.removed[0].doesExist("userId"), "newest tombstone wins without inventing user ID")
    check(not decoded.removed[1].doesExist("userId"), "malformed optional tombstone user ID dropped alone")
    check(FormatJson(raw) = before, "decode never mutates unknown categories/members/tails")
    for each invalidData in [invalid, [], {}, {rows: "bad"}, {rows: ["bad"]}, {rows: [["7", "Alice"]]}, {rows: [[7]]}, {rows: [[7, 9]]}, {rows: [[2147483648&, "Alice"]]}, {rows: [], removed: "bad"}]
        check(not dispatcharrSyncRosterDecode(invalidData).ok, "malformed required row/category fails the entire roster")
    end for
    for each pin in [["numbers", "short", salt, "keep"], ["directions", hash, "short", "keep"], ["unknown", hash, salt, "clear"], ["none", hash, salt, "clear"]]
        row = dispatcharrSyncRosterDecode({rows: [[7, "Alice", "", pin[0], pin[1], pin[2], "unknown", "100", invalid, -2]]}).rows[0]
        check(row.pinAction = pin[3] and row.role = "" and row.updatedAt = 0 and row.order = -1 and not row.avatarPresent, "malformed newer PIN preserves existing PIN; unknown type follows none")
    end for
    row = dispatcharrSyncRosterDecode({rows: [[7, "Alice", invalid, "none", "", "", "user", 1, "bad", 0]]}).rows[0]
    check(row.avatarPresent and row.avatar.count() = 0 and row.displayName = "", "present nonobject avatar explicitly restores default")
    rows = [[7, "old", "", "none", "", "", "user", 10], [7, "new", "", "none", "", "", "user", 20]]
    check(dispatcharrSyncRosterDecode({rows: rows}).rows.count() = 1, "rows deduplicate by user ID")
    check(dispatcharrSyncRosterDecode({rows: rows}).rows[0].username = "new", "newest duplicate row wins deterministically")
    many = []
    for i = 1 to 30
        many.push([i, "user" + i.toStr()])
    end for
    check(dispatcharrSyncRosterDecode({rows: many}).rows.count() = 25, "wire roster bounded independently of four-profile local cap")
    many.push(["invalid", "after-cap"])
    check(not dispatcharrSyncRosterDecode({rows: many}).ok, "cap cannot hide malformed trailing rows")
    for each role in ["admin", "user"]
        gate = dispatcharrSyncRosterGate(role, true, [{addressHeld: false}, {addressHeld: false}])
        check(gate.apply and gate.suggestions, "full-access enabled roster can reach later merge policy")
    end for
    for each role in ["child", "unknown", invalid]
        gate = dispatcharrSyncRosterGate(role, true, [{addressHeld: false}])
        check(not gate.apply and not gate.suggestions, "Child/unknown role neither applies roster nor exposes other names")
    end for
    check(not dispatcharrSyncRosterGate("user", false, [{addressHeld: false}]).apply, "Profiles-Off disables application")
    check(not dispatcharrSyncRosterGate("user", "true", [{addressHeld: false}]).apply, "untyped enabled flag cannot grant application")
    profiles = [{addressHeld: false}, {addressHeld: true}]
    before = FormatJson(profiles)
    gate = dispatcharrSyncRosterGate("admin", true, profiles)
    check(not gate.apply and not gate.suggestions and gate.reason = "address-held", "any held profile pauses roster including keyless nondefault")
    check(FormatJson(profiles) = before, "pause check never clears holds or pending local data")
    check(not dispatcharrSyncRosterGate("user", true, [{}]).apply, "malformed local hold authority fails closed")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
