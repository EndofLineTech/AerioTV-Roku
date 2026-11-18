sub main()
    resetPhoneVerifyTask()
    verifyPhoneSetupProfiles()
    result = m.top.result
    check(result.ok and result.proofs.count() = 3 and m.calls.count() = 5, "selected batch verifies default then adult then Child with one key/password fallback")
    check(result.proofs.bob.apiKey = "bob-key" and result.proofs.kid.verifiedUser.username = "Kid", "each proof retains only its matching own key and account facts")
    check(m.calls[0].key = "alice-key" and m.calls[1].key = "wrong-bob-key" and m.calls[2].key = "" and m.calls[3].key = "" and m.calls[3].bearer = "bob-token" and m.calls[4].key = "kid-key", "API-key and password/bearer phases never mix headers or borrow the source/default key")
    check(m.top.defaultCredential = invalid and m.top.profiles.count() = 0 and m.key = "", "verification clears Task credential inputs before publishing")
    for each row in result.rows
        check(row.credential = invalid, "returned metadata has no passwords or credentials")
    end for
    check(instr(1, FormatJson(result), "bob-password") = 0 and instr(1, FormatJson(result), "bob-token") = 0, "no password or bearer response enters the result")
    resetPhoneVerifyTask()
    m.top.defaultOnly = true
    verifyPhoneSetupProfiles()
    first = m.top.result
    check(first.ok and first.proofs.count() = 1 and m.calls.count() = 1, "default-only phase returns before other profile sign-ins so the slot can commit first")
    resetPhoneVerifyTask()
    m.top.defaultOnly = true
    m.top.verifiedDefault = {}
    verifyPhoneSetupProfiles()
    check(m.top.result.ok and m.calls.count() = 1 and m.calls[0].key = "alice-key", "empty native optional proof field still requires fresh own default authentication")
    resetPhoneVerifyTask()
    m.top.verifiedDefault = {ok: false}
    verifyPhoneSetupProfiles()
    check(not m.top.result.ok and m.calls.count() = 0, "nonempty invalid default proof fails closed without credential fallback")
    resetPhoneVerifyTask()
    m.top.verifiedDefault = first.proofs.alice
    verifyPhoneSetupProfiles()
    check(m.top.result.ok and m.calls.count() = 4 and m.calls[0].key = "wrong-bob-key", "remaining phase reuses only the already verified default proof without a second default request")
    resetPhoneVerifyTask()
    m.fixtureParkBob = true
    verifyPhoneSetupProfiles()
    check(m.top.result.ok and m.top.result.rateLimited and m.top.result.proofs.count() = 1 and m.calls.count() = 2, "429 preserves prior success and stops every remaining user/password request")
    resetPhoneVerifyTask()
    m.top.cancelRequested = true
    verifyPhoneSetupProfiles()
    check(not m.top.result.ok and m.calls.count() = 0 and m.top.defaultCredential = invalid and m.top.profiles.count() = 0, "cancelled batch sends nothing and scrubs credentials")
    print "ALL TESTS PASSED"
end sub

sub resetPhoneVerifyTask()
    m.fixtureParkBob = false
    m.calls = []
    m.top = {baseUrl: "https://example.test", authMode: "x-api-key", captureNonce: "00000000-0000-4000-8000-000000000090", defaultCredential: {apiKey: "alice-key"}, cancelRequested: false, profiles: [
        {username: "Kid", displayName: "Kids", role: "child", credential: {apiKey: "kid-key"}},
        {username: "Alice", displayName: "Home", isDefault: true},
        {username: "Bob", displayName: "Living Room", credential: {apiKey: "wrong-bob-key", password: "bob-password"}}
    ]}
end sub

function requestJson(url as string, body = invalid as dynamic, bearer = "" as string, method = "GET" as string) as dynamic
    m.calls.push({key: m.key, bearer: bearer})
    m.httpFailure = invalid
    if right(url, 7) = "/token/"
        if body.username = "Bob" and body.password = "bob-password" and m.key = "" then return {access: "bob-token"}
        return invalid
    end if
    if bearer = "bob-token" then return {id: 2, username: "Bob", user_level: 1, api_key: "bob-key"}
    if m.key = "alice-key" then return {id: 1, username: "Alice", user_level: 1}
    if m.key = "kid-key" then return {id: 3, username: "Kid", user_level: 1}
    if m.key = "wrong-bob-key"
        if m.fixtureParkBob
            m.httpFailure = {status: 429}
        else
            m.httpFailure = {status: 401, keyRejected: true}
        end if
    end if
    return invalid
end function

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
