sub main()
    payload = {playlist: {credential: {apiKey: "fixture-key"}}, profiles: []}
    credential = phoneSetupEffectiveCredential(payload)
    check(credential.apiKey = "fixture-key" and credential.username = "", "API-key-only default needs no username")
    payload.profiles = [{isDefault: true, credential: {username: "Other", password: "fixture"}}]
    check(phoneSetupEffectiveCredential(payload).apiKey = "fixture-key", "playlist credential takes precedence over profiles")
    payload.playlist.delete("credential")
    payload.profiles.push({isDefault: false, credential: {apiKey: "ignored"}})
    check(phoneSetupEffectiveCredential(payload).username = "Other", "explicit default profile fallback")
    payload.profiles[0].isDefault = false
    check(phoneSetupEffectiveCredential(payload) = invalid, "multiple non-default profiles cannot silently select an account")
    payload.profiles.pop()
    payload.profiles[0].credential.password = "  literal password  "
    check(phoneSetupEffectiveCredential(payload).password = "  literal password  ", "single-profile fallback preserves credential bytes")
    payload.profiles.push({isDefault: true, credential: {username: "Second"}})
    payload.profiles[0].isDefault = true
    check(phoneSetupEffectiveCredential(payload) = invalid, "ambiguous defaults require user resolution")

    check(phoneSetupServerIdentity("HTTPS://EXAMPLE.TEST:443/base/") = "https://example.test/base", "scheme/authority/default port canonicalized")
    check(phoneSetupServerIdentity("https://example.test/Base") <> phoneSetupServerIdentity("https://example.test/base"), "case-sensitive server path preserved")
    check(phoneSetupServerIdentity("https://user:secret@example.test") = "", "userinfo never becomes a duplicate identity")
    store = {entries: [
        {id: "one", provider: "dispatcharr", url: "HTTPS://EXAMPLE.TEST:443/base/", accountId: "7", accountUsername: "Viewer"}
        {id: "two", provider: "dispatcharr", url: "https://example.test/base", accountId: "8", accountUsername: "viewer"}
        {id: "three", provider: "dispatcharr", url: "https://elsewhere.test/base", accountId: "7", accountUsername: "Viewer"}
    ]}
    candidate = {provider: "dispatcharr", url: "https://example.test/base", accountId: "7", accountUsername: "Viewer"}
    matches = phoneSetupDuplicateIds(store, candidate)
    check(matches.count() = 1 and matches[0] = "one", "verified account identity plus normalized server, not display name or key")
    candidate.accountId = "9"
    check(phoneSetupDuplicateIds(store, candidate).count() = 0, "different verified IDs never fall back to matching usernames")
    candidate.accountId = ""
    check(phoneSetupDuplicateIds(store, candidate).count() = 1, "exact verified username fallback for older metadata")
    candidate.provider = "xtream"
    check(phoneSetupDuplicateIds(store, candidate).count() = 0, "provider families never collide")
    store.entries = [{id: "query", provider: "m3u", url: "", sourceDigest: string(64, "a"), sessionUrl: true}]
    candidate = {provider: "m3u", url: "", sourceDigest: string(64, "a"), sessionUrl: true}
    check(phoneSetupDuplicateIds(store, candidate).count() = 1, "session-only M3U can match by digest without persisting tokens")
    candidate.sourceDigest = string(64, "b")
    check(phoneSetupDuplicateIds(store, candidate).count() = 0, "empty metadata URLs do not merge distinct query feeds")

    store = defaultConnectionStore()
    for i = 1 to 4
        store.entries.push(normalizeConnectionEntry({id: "slot" + i.toStr(), name: "Saved " + i.toStr(), provider: "dispatcharr", url: "https://example.test/base", accountId: i.toStr()}))
    end for
    store.selected = "slot1"
    candidate = normalizeConnectionEntry({id: "incoming", name: "Received", provider: "dispatcharr", url: "https://EXAMPLE.TEST:443/base/", accountId: "2"})
    original = formatJson(store)
    check(phoneSetupStageVerifiedConnection(store, candidate, "cancel", "slot2") = invalid, "Cancel stages no write")
    check(phoneSetupStageVerifiedConnection(store, candidate, "addAnyway", "") = invalid, "four occupied slots cannot Add Anyway")
    check(phoneSetupStageVerifiedConnection(store, candidate, "replace", "slot1") = invalid, "replacement cannot target an unrelated slot")
    replaced = phoneSetupStageVerifiedConnection(store, candidate, "replace", "slot2")
    check(replaced.entries.count() = 4 and replaced.entries[1].id = "slot2", "Replace retains matched slot identity and position at capacity")
    check(replaced.entries[1].name = "Received" and replaced.selected = "slot2", "verified replacement selected in staged copy")
    check(replaced.entries[0].name = "Saved 1" and replaced.entries[2].name = "Saved 3", "unrelated slots untouched")
    check(formatJson(store) = original, "staging never mutates saved/current store")
    store.entries.pop()
    check(phoneSetupStageVerifiedConnection(store, candidate, "add", "") = invalid, "duplicates require explicit Add Anyway or Replace")
    added = phoneSetupStageVerifiedConnection(store, candidate, "addAnyway", "")
    check(added.entries.count() = 4 and added.selected = "incoming", "explicit Add Anyway uses a fresh slot when available")
    store.readOnly = true
    check(phoneSetupStageVerifiedConnection(store, candidate, "replace", "slot2") = invalid, "read-only registry recovery cannot be overwritten")
    print "ALL TESTS PASSED"
end sub

sub check(condition as boolean, message as string)
    if not condition
        print "FAIL: "; message
        stop
    end if
end sub
