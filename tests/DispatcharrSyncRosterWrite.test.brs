sub main()
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
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
