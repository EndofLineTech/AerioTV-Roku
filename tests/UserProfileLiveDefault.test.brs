sub main()
    entry = normalizeConnectionEntry({id: "slot-a", name: "Synthetic", provider: "dispatcharr", url: "https://old.test", remember: false})
    a = userProfileFromVerified(entry.id, "00000000-0000-4000-8000-000000000001", {id: 7, username: "Alice", user_level: 1}, 1)
    b = userProfileFromVerified(entry.id, "00000000-0000-4000-8000-000000000002", {id: 8, username: "Bob", user_level: 1}, 1)
    b.isDefault = false
    c = userProfileFromVerified(entry.id, "00000000-0000-4000-8000-000000000003", {id: 9, username: "Charlie", user_level: 1}, 1)
    c.isDefault = false
    store = defaultUserProfileStore(entry.id)
    store.profiles = [a, b, c]
    store.active = a.id
    recorded = userProfileRecordDefaultIdentity(store, false)
    held = userProfileAddressChangePlan(entry, recorded.store, "https://new.test")
    newEntry = setCanonicalPreference(entry, "url", "https://new.test")
    replacement = userProfileFromVerified(entry.id, a.id, {id: 70, username: "NewAlice", user_level: 1}, 100)
    replaced = userProfileEnsureDefault(held.store, replacement, true)
    proof = {ok: true, verifiedBaseUrl: newEntry.url, verifiedUser: {id: 70, username: "NewAlice"}}
    live = userProfileDefaultAddressCheck(newEntry, replaced, proof)
    check(live.ok and live.store.doesExist("verifiedDefaultAtAddress") and live.store["knownDefault"]["userId"] = 7 and live.store.profiles[1].addressHeld, "a different live default answer is retained separately without rewriting the frozen comparison identity or lifting holds")
    actual = userProfileLiveDefaultAt(newEntry, live.store)
    check(actual <> invalid and actual.id = 70 and actual.username = "NewAlice", "own recovery uses the default answer from this address, not the frozen old user")
    anotherAddress = setCanonicalPreference(newEntry, "url", "https://third.test")
    check(userProfileLiveDefaultAt(anotherAddress, live.store) = invalid, "an answer from another address cannot tag a new own sign-in")
    for each corruptProof in [{url: "not-a-url", identity: {userId: 70, username: "NewAlice"}}, {url: newEntry.url, identity: {userId: "70", username: "NewAlice"}}, {url: newEntry.url, identity: {userId: 70, username: "NewAlice"}, extra: true}]
        corrupt = setCanonicalPreference(live.store, "verifiedDefaultAtAddress", corruptProof)
        check(normalizeUserProfileStore(corrupt, entry.id).readOnly, "malformed or untyped current-address default evidence fences the roster")
    end for
    changedAgain = userProfileAddressChangePlan(newEntry, live.store, anotherAddress.url)
    check(changedAgain.ok and not changedAgain.store.doesExist("verifiedDefaultAtAddress"), "every actual URL edit retires the live-default answer while keeping the recorded baseline")
    signedIn = {ok: true, apiKey: "synthetic-own-b", verifiedBaseUrl: newEntry.url, verifiedUser: {id: 88, username: "BOB", user_level: 1}}
    own = userProfileOwnSignInPlan(newEntry, live.store, b.id, signedIn, 101)
    check(own.ok and not own.target.addressHeld and own.target.userId = 88 and own.target["defaultIdentityTag"]["userId"] = 70 and own.store.profiles[2].addressHeld, "inactive held own sign-in lifts only that holder and tags the live new default while preserving other holds")
    check(own.store.doesExist("addressChangeSnapshot") and own.store["knownDefault"]["userId"] = 7, "other held holders keep the old snapshot and record frozen")
    unknown = copyJson(live.store)
    unknown.delete("verifiedDefaultAtAddress")
    own = userProfileOwnSignInPlan(newEntry, unknown, b.id, signedIn, 101)
    check(own.ok and own.target.doesExist("defaultIdentityTag") and own.target["defaultIdentityTag"] = invalid, "a missing current-address default answer means explicitly unknown, never the frozen record")
    alone = copyJson(live.store)
    alone.profiles.pop()
    own = userProfileOwnSignInPlan(newEntry, alone, b.id, signedIn, 101)
    check(own.ok and not own.store.doesExist("addressChangeSnapshot") and own.store["knownDefault"]["userId"] = 7, "last-holder own sign-in settles the change but does not rewrite its old baseline from that same request")
    wrong = copyJson(signedIn)
    wrong.verifiedUser.username = "AnotherUser"
    check(not userProfileOwnSignInPlan(newEntry, live.store, b.id, wrong, 101).ok, "a different own username cannot alter a held key, tag or data anchor")
    wrong = copyJson(signedIn)
    wrong.verifiedBaseUrl = entry.url
    check(not userProfileOwnSignInPlan(newEntry, live.store, b.id, wrong, 101).ok, "held recovery refuses a successful own answer captured at an old address")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
