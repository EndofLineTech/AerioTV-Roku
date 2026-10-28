sub main()
    original = normalizeAccountPreferences({recent: ["c", "b", "a"], lastWatched: "c", previous: "b", lastChannel: "c", favoriteIds: ["1"]})
    removed = changeRecentHistory(original, "remove", "b")
    check(formatJson(removed.recent) = formatJson(["c", "a"]), "remove preserves recency order")
    check(removed.previous = "" and removed.lastWatched = "c", "removed previous target cannot be recalled")
    check(original.recent.count() = 3 and original.previous = "b", "does not mutate original account")
    check(changeRecentHistory(original, "remove", "c").lastWatched = "", "removed last watched target cleared")
    cleared = changeRecentHistory(original, "clear", "")
    check(cleared.recent.count() = 0 and cleared.previous = "" and cleared.lastWatched = "", "clear all recall history")
    check(cleared.lastChannel = "c" and cleared.favoriteIds.count() = 1, "browse position and favorites retained")
    check(changeRecentHistory(original, "unknown", "b").recent.count() = 3, "unknown action ignored")
    check(changeRecentHistory(original, "remove", "unknown").recent.count() = 3, "missing id no-op")
    check(recordWatched(cleared, "a").recent.count() = 1, "new deliberate tune records history again")
    store = defaultPreferenceStore()
    store.accounts[preferenceScope("account-a")] = cleared
    store.accounts[preferenceScope("account-b")] = original
    restored = normalizePreferenceStore(parseJson(formatJson(store)))
    check(accountPreferences(restored, "account-a").recent.count() = 0, "cleared history survives stored JSON round trip")
    check(accountPreferences(restored, "account-b").recent.count() = 3, "other account history survives unchanged")

    m.accountIdentity = "account-a"
    m.accountPreferences = original
    m.guide = {recentIds: []}
    m.browser = {recentIds: []}
    m.playingChannel = {uuid: "c"}
    m.recordedChannel = "c"
    m.video = {control: "play"}
    m.saveCount = 0
    m.saveSucceeds = true
    m.historyDialog = fakeDialog("current")
    m.historyContext = {account: "account-a", uuid: "b", actions: ["cancel", "remove", "clear"], origin: "guide"}
    onRecentHistoryChoice(fakeEvent(fakeDialog("stale"), 1))
    check(m.saveCount = 0, "stale dialog event rejected")
    m.historyContext.account = "other-account"
    onRecentHistoryChoice(fakeEvent(m.historyDialog, 1))
    check(m.saveCount = 0 and m.accountPreferences.recent.count() = 3, "account switch rejects stale edit")
    m.historyDialog = fakeDialog("current")
    m.historyContext = {account: "account-a", uuid: "b", actions: ["cancel", "remove", "clear"], origin: "guide"}
    onRecentHistoryChoice(fakeEvent(m.historyDialog, 0))
    check(m.saveCount = 0, "cancel does not persist")
    m.historyDialog = fakeDialog("current")
    m.historyContext = {account: "account-a", uuid: "b", actions: ["cancel", "remove", "clear"], origin: "guide"}
    onRecentHistoryChoice(fakeEvent(m.historyDialog, 99))
    check(m.saveCount = 0, "out of range selection ignored")
    onRecentHistoryChoice(fakeEvent(m.historyDialog, 1))
    check(m.saveCount = 1 and m.saved.recent.count() = 2, "controller persists removal")
    check(m.guide.recentIds.count() = 2 and m.browser.recentIds.count() = 2, "both surfaces updated")
    check(m.video.control = "play" and m.recordedChannel = "c", "playing and recorded tune not disturbed")
    m.historyDialog = fakeDialog("current")
    m.historyContext = {account: "account-a", uuid: "c", actions: ["cancel", "remove", "clear"], origin: "guide"}
    m.saveSucceeds = false
    onRecentHistoryChoice(fakeEvent(m.historyDialog, 2))
    check(m.accountPreferences.recent.count() = 0 and m.saveCount = 2, "storage failure retains session change via standard persistence policy")
    check(m.video.control = "play", "clear does not stop stream")
    print "ALL TESTS PASSED"
end sub

function fakeDialog(id as string) as object
    return {id: id, isSameNode: function(node as object) as boolean
        return m.id = node.id
    end function, unobserveField: sub(field as string)
    end sub}
end function

function fakeEvent(node as object, index as integer) as object
    return {node: node, index: index, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as integer
        return m.index
    end function}
end function

function persistAccountPreferences() as boolean
    m.saveCount++
    m.saved = copyJson(m.accountPreferences)
    return m.saveSucceeds
end function

sub check(condition as boolean, label as string)
    if not condition
        print "FAIL: "; label
        stop
    end if
end sub
