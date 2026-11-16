sub main()
    store = pickerStore()
    scope = {playlistId: store.playlistId, profileId: store.active, accountId: "2", sessionId: "00000000-0000-4000-8000-000000000090"}
    chrome = userProfileSwitcherDescriptor(store, scope, "dispatcharr", true)
    check(chrome.id = "profiles" and chrome.avatarInitial = "B" and chrome.sessionId = scope.sessionId and chrome.username = invalid, "top-bar avatar is bound to the adopted holder without exposing the roster")
    check(userProfileSwitcherDescriptor(store, scope, "dispatcharr", false) = invalid, "normal builds keep profile chrome gated")
    plan = userProfilePickerPlan(store, "launch", "dispatcharr", false)
    check(plan.ok and plan.show and plan.focus = 1 and plan.back = "exit", "launch focuses restored holder and Back exits")
    check(plan.tiles.count() = 3 and plan.tiles[0].id = store.profiles[0].id and plan.tiles[1].id = store.active, "profile order followed by Add, without launch Manage")
    check(plan.tiles[1].locked and plan.tiles[1].current and plan.tiles[1].name = "Bob", "name/current/lock are explicit tile metadata")
    check(plan.tiles[1].avatar.count() = 0, "missing avatar retains shared initial/color fallback representation")
    check(userProfilePickerChoice(plan, 1) = "pin", "current protected launch holder still needs launch PIN")
    check(userProfilePickerChoice(plan, 0) = "select", "another launch holder uses startup selection, not outgoing switch")
    check(userProfilePickerChoice(plan, 2) = "add", "Add is an admission request, not a grant")
    moved = copyJson(store)
    moved.profiles[1] = setCanonicalPreference(moved.profiles[1], "order", 0)
    ordered = userProfilePickerPlan(moved, "launch", "dispatcharr", false)
    check(ordered.tiles[0].id = store.active and ordered.focus = 0, "imported moved order dominates default-first storage order and focus follows holder")
    reversed = copyJson(store)
    reversed.profiles = [reversed.profiles[1], reversed.profiles[0]]
    ordered = userProfilePickerPlan(reversed, "switcher", "dispatcharr", false)
    check(ordered.tiles[0].id = store.profiles[0].id and ordered.focus = 1, "never-moved roster uses shared default-first stable ordering")
    tied = copyJson(moved)
    tied.profiles[0] = setCanonicalPreference(tied.profiles[0], "order", 0)
    ordered = userProfilePickerPlan(tied, "launch", "dispatcharr", false)
    check(ordered.tiles[0].id = store.profiles[0].id and ordered.focus = 1, "equal moved positions use shared default-first tie break")
    third = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000003", {id: 3, username: "Chris", user_level: 1}, 50)
    third = setCanonicalPreference(third, "isDefault", false)
    three = copyJson(store)
    three.profiles.push(third)
    ordered = userProfilePickerPlan(three, "launch", "dispatcharr", false)
    check(ordered.tiles[1].id = third.id and ordered.focus = 2, "never-moved nondefault holders sort by creation time, not array order")
    third = setCanonicalPreference(third, "createdAt", 100)
    three.profiles = [three.profiles[0], third, three.profiles[1]]
    ordered = userProfilePickerPlan(three, "launch", "dispatcharr", false)
    check(ordered.tiles[1].id = third.id and ordered.focus = 2, "equal creation times keep stable insertion order")
    switcher = userProfilePickerPlan(store, "switcher", "dispatcharr", false)
    check(switcher.show and switcher.back = "close" and switcher.tiles.count() = 4, "switcher includes Add and Manage with closing Back")
    check(userProfilePickerChoice(switcher, 1) = "close", "choosing current switcher holder never prompts again")
    check(userProfilePickerChoice(switcher, 0) = "switch", "different switcher holder uses authenticated switching")
    check(userProfilePickerChoice(switcher, 3) = "manage", "Manage routes separately from selection")
    check(userProfilePickerChoice(plan, -1) = "" and userProfilePickerChoice(plan, 99) = "", "invalid indices confer no action")
    check(userProfilePickerChoice(plan, 1.5) = "" and userProfilePickerChoice(plan, "1") = "", "indices are integer-only")
    check(not userProfilePickerPlan(store, "launch", "dispatcharr", true).show, "deep link suppresses launch picker before PIN")
    check(not userProfilePickerPlan(store, "launch", "xtream", false).show, "other providers never get this picker")
    check(not userProfilePickerPlan(store, "bogus", "dispatcharr", false).ok, "unknown purpose fails closed")
    off = copyJson(store)
    off = setCanonicalPreference(off, "askAtLaunch", false)
    check(not userProfilePickerPlan(off, "launch", "dispatcharr", false).show, "explicit Ask Off remains respected")
    check(userProfilePickerPlan(off, "switcher", "dispatcharr", false).show, "Ask Off does not disable explicit switcher")
    child = copyJson(store)
    child.profiles[1] = setCanonicalPreference(child.profiles[1], "role", "child")
    check(userProfileSwitcherDescriptor(child, scope, "dispatcharr", true) = invalid, "Child receives no profile switcher descriptor")
    for each mode in ["launch", "switcher"]
        denied = userProfilePickerPlan(child, mode, "dispatcharr", false)
        check(denied.ok and not denied.show and denied.tiles.count() = 0, "Child never receives other profile identities")
    end for
    single = copyJson(store)
    single.profiles = [single.profiles[0]]
    single.active = single.profiles[0].id
    check(not userProfilePickerPlan(single, "launch", "dispatcharr", false).show, "one holder skips launch picker")
    check(not userProfilePickerPlan(single, "switcher", "dispatcharr", false).show, "one holder has no switcher")
    check(not userProfilePickerPlan(userProfileStoreRecovery("slot-a"), "launch", "dispatcharr", false).ok, "unreadable roster is recovery, never picker")
    invalidStore = copyJson(store)
    invalidStore.active = "00000000-0000-4000-8000-000000000099"
    check(not userProfilePickerPlan(invalidStore, "launch", "dispatcharr", false).ok, "missing restored actor cannot reveal a roster")
    original = FormatJson(store)
    plan.tiles[0].name = "Changed"
    check(FormatJson(store) = original, "presentation mutation cannot edit persisted profile metadata")
    state = {focus: 1, count: 6, armed: false, held: false}
    state = userProfilePickerInput(state, "OK", true)
    check(state.armed and state.action = "", "OK down never switches before long-press decision")
    state = userProfilePickerInput(state, "hold", true)
    check(state.action = "reorder" and state.held, "hold emits reorder intent")
    state = userProfilePickerInput(state, "OK", false)
    check(state.action = "" and not state.armed, "release after hold cannot accidentally select")
    state = userProfilePickerInput(state, "OK", false)
    check(state.action = "", "orphan release cannot select")
    state = userProfilePickerInput(state, "OK", true)
    state = userProfilePickerInput(state, "OK", false)
    check(state.action = "choose", "short OK emits exactly one selection on release")
    state = userProfilePickerInput(state, "right", true)
    check(state.focus = 2, "right moves focus")
    state = userProfilePickerInput(state, "down", true)
    check(state.focus = 5, "down clamps to final tile in short last row")
    state = userProfilePickerInput(state, "up", true)
    check(state.focus = 1, "up keeps column")
    state = userProfilePickerInput(state, "OK", true)
    state = userProfilePickerInput(state, "back", true)
    state = userProfilePickerInput(state, "OK", false)
    check(state.action = "", "Back disarms pending OK")
    print "ALL TESTS PASSED"
end sub

function pickerStore() as object
    store = defaultUserProfileStore("slot-a")
    a = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 1, username: "Alice", user_level: 1}, 100)
    b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 2, username: "Bob", user_level: 1}, 100)
    a = setCanonicalPreference(a, "isDefault", true)
    b = setCanonicalPreference(b, "isDefault", false)
    b = setCanonicalPreference(b, "pinType", "numbers")
    b = setCanonicalPreference(b, "pinSalt", string(32, "b"))
    b = setCanonicalPreference(b, "pinHash", string(64, "a"))
    store.profiles = [a, b]
    store.active = b.id
    store = setCanonicalPreference(store, "askAtLaunch", true)
    return normalizeUserProfileStore(store, "slot-a")
end function

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
