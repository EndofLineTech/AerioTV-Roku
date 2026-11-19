sub main()
    oldEntry = normalizeConnectionEntry({id: "phone-slot", name: "Saved", provider: "dispatcharr", url: "https://old.example.test", accountId: "1", accountUsername: "Old"})
    newEntry = normalizeConnectionEntry({id: "phone-slot", name: "Received", provider: "dispatcharr", url: "https://new.example.test", accountId: "9", accountUsername: "New"})
    identified = {schema: 1, selected: oldEntry.id, entries: [oldEntry]}
    check(phoneSetupStageVerifiedConnection(identified, newEntry, "replace", oldEntry.id) = invalid, "ordinary duplicate replacement cannot invent an unrelated account match")
    check(phoneSetupStageVerifiedConnection(identified, newEntry, "replace", oldEntry.id, true).entries[0].accountId = "9", "explicit matched playlist ID updates in place independently of account or URL duplicate matching")
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
    store.entries = [{id: "exact", provider: "m3u", url: "https://example.test/feed", sourceDigest: string(64, "a"), sessionUrl: false}]
    candidate = {provider: "m3u", url: "https://example.test/feed/", sourceDigest: string(64, "b"), sessionUrl: false}
    check(phoneSetupDuplicateIds(store, candidate).count() = 0, "different feed digests are not overridden by a lossy URL comparison")
    store.entries[0].sourceDigest = ""
    check(phoneSetupDuplicateIds(store, candidate).count() = 0, "legacy URL fallback preserves path trailing slash")
    candidate.url = "HTTPS://EXAMPLE.TEST:443/feed"
    check(phoneSetupDuplicateIds(store, candidate).count() = 1, "legacy URL fallback still canonicalizes scheme/host/default port")

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
    payload = {playlist: {type: "m3u", name: "Query feed", url: "https://example.test?token=fixture", guideDays: 7, catchupOffsetMinutes: 0, vodEnabled: false, channelProfileIds: []}, profiles: []}
    prepared = phoneSetupPrepareImport(payload, "received", string(64, "a"))
    check(prepared.ok and prepared.entry.sessionUrl, "query feed prepared as session-only")
    check(prepared.entry.url = "" and instr(1, formatJson(prepared.entry), "token=") = 0, "query token absent from roster")
    check(prepared.url = payload.playlist.url, "exact query retained only in volatile request")
    check(not phoneSetupVerifiedImport(prepared, {ok: false}).ok, "provider rejection cannot become a candidate")
    check(not phoneSetupVerifiedImport(prepared, {ok: true, channels: []}).ok, "empty lineup cannot consume a slot")
    verified = phoneSetupVerifiedImport(prepared, {ok: true, channels: [{id: "one"}], accountId: "feed"})
    check(verified.ok and verified.entry.id = "received", "verified candidate retains its provisional slot identity")
    check(connectionPreferenceIdentity(verified.entry, "feed") <> "", "session-only feed has a non-secret preference identity")
    check(phoneSetupFeedIdentity("HTTPS://EXAMPLE.TEST:443?token=CaseSensitive") = "https://example.test/?token=CaseSensitive", "feed digest input normalizes origin but preserves query bytes")
    payload.playlist.catchupOffsetMinutes = 60
    for days = 0 to 14
        payload.playlist.guideDays = days
        prepared = phoneSetupPrepareImport(payload, "received", string(64, "a"))
        check(prepared.ok and prepared.entry.guideDays = days and prepared.entry.catchupOffsetMinutes = 60, "wire days and unapplied offset retained in connection metadata")
        check(prepared.notes[prepared.notes.count() - 1] = "Catch-up offset retained but not applied by this build.", "catch-up warning remains")
        expected = days
        if days = 0
            expected = 30
            check(prepared.notes.count() = 3 and instr(1, prepared.notes[1], "30") > 0, "All Available limit disclosed before saving")
        else
            check(prepared.notes.count() = 2, "supported day count is not described as unapplied")
        end if
        original = {guide: {futureDays: 14, historyDays: 3, showLogos: false}, vodEnabled: true}
        prefs = phoneSetupImportedPreferences(original, prepared.entry)
        check(prefs.guide.futureDays = expected and prefs.guide.historyDays = expected and not prefs.vodEnabled, "import applies requested horizon in both directions")
        check(not prefs.guide.showLogos and original.guide.futureDays = 14 and original.guide.historyDays = 3, "import preserves other preferences and original input")
    end for
    testInterimProfiles()
    print "ALL TESTS PASSED"
end sub

sub testInterimProfiles()
    notice = "Multiple profiles aren't currently supported on Roku. Stay tuned."
    playlist = {type: "dispatcharr", name: "Home", url: "https://example.test", credential: {apiKey: "default-only"}, guideDays: 7, catchupOffsetMinutes: 0, vodEnabled: true, channelProfileIds: []}
    payload = {playlist: playlist, profiles: [
        {username: "alice", displayName: "Alice", isDefault: true, role: "admin", pinType: "none"}
        {username: "sam", displayName: "Sam", isDefault: false, credential: {apiKey: "must-not-authenticate"}, role: "user", pinType: "numbers", pinHash: string(64, "a"), pinSalt: string(32, "b")}
        {username: "kim", displayName: "Kim", isDefault: false, role: "child", pinType: "none"}
    ]}
    prepared = phoneSetupPrepareImport(payload, "received", "")
    check(prepared.ok and prepared.multipleProfiles, "three-profile payload imports only unrestricted default")
    check(prepared.credential.apiKey = "default-only" and prepared.notes[0] = notice, "exact omission notice and playlist credential")
    serialized = lcase(formatJson(prepared))
    check(instr(1, serialized, "pinhash") = 0 and instr(1, serialized, "pinsalt") = 0 and instr(1, serialized, "must-not-authenticate") = 0, "ignored profiles and secrets never survive preparation")
    payload.profiles = [payload.profiles[0]]
    payload.profiles[0].isDefault = false
    prepared = phoneSetupPrepareImport(payload, "received", "")
    check(prepared.ok and not prepared.multipleProfiles and prepared.notes.count() = 0, "one entry is default regardless of flag and gets no multiple notice")
    for each field in ["role", "pinType"]
        payload.profiles[0][field] = "child"
        if field = "pinType"
            payload.profiles[0].role = "user"
            payload.profiles[0].pinType = "numbers"
            payload.profiles[0].pinHash = string(64, "a")
            payload.profiles[0].pinSalt = string(32, "b")
        end if
        refused = phoneSetupPrepareImport(payload, "received", "")
        check(not refused.ok and refused.credential = invalid and refused.entry = invalid, "protected single default refused before verification/persistence")
        check(phoneSetupPrepareImport(payload, "received", "", true).ok, "only an explicitly admitted private import controller can stage protected metadata")
    end for
    payload.profiles.push({username: "adult", displayName: "Adult", isDefault: true, role: "user", pinType: "none"})
    check(phoneSetupPrepareImport(payload, "received", "").ok, "protected non-default is ignored, not mistaken for selected default")
    payload.profiles[1].role = "child"
    check(not phoneSetupPrepareImport(payload, "received", "").ok, "explicit protected default in multi-profile payload refused")
    payload.playlist.type = "m3u"
    check(phoneSetupPrepareImport(payload, "received", "").ok, "M3U ignores unsupported profile protection")
end sub

sub check(condition as boolean, message as string)
    if not condition
        print "FAIL: "; message
        stop
    end if
end sub
