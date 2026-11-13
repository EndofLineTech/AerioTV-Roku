' Synthetic only: no application initialization, registry, provider credentials
' or persisted settings. Main thread may use roUrlTransfer without rendering.
sub Main()
    port = CreateObject("roMessagePort")
    screen = CreateObject("roSGScreen")
    screen.setMessagePort(port)
    scene = screen.createScene("PhoneSetupProbe")
    screen.show()
    scene.findNode("results").text = "Profile primitive probe — synthetic data only"
    m.profileFailures = 0
    m.key = "synthetic-profile-probe"
    config = ParseJson(ReadAsciiFile("pkg:/profile-probe-config.json"))
    original = ReadAsciiFile("pkg:/profile-wire-fixture.json")
    value = ParseJson(original, "d")
    profileAssert(value <> invalid, "parse-double-mode")
    profileAssert(value.doesExist("schemaVersion") and not value.doesExist("schemaversion"), "exact-json-case")
    profileAssert(GetInterface(value.schemaVersion, "ifInt") <> invalid, "integer-literal")
    profileAssert(profileIsFloating(value.categories.settings.data.mobile.textScale), "floating-literal")
    profileAssert(value.categories.syncProviders.data.updatedAt = 1761700000000, "millisecond-exact")
    encoded = strictJsonEncode(value)
    profileAssert(encoded.ok, "strict-encode")
    profileAssert(strictJsonEncode({boxedInteger: 1}).ok, "strict-json-native-boxed-integer")
    raw = encoded.text
    again = ParseJson(raw, "d")
    profileAssert(again.categories.profiles.data.rows[0][2] = "Alice 🦉", "emoji-roundtrip")
    profileAssert(again.categories.settings.data.doesExist("FutureNull") and again.categories.settings.data.FutureNull = invalid, "null-preserved")
    profileAssert(again.categories.profiles.data.rows[0][10].FutureCase = true, "row-tail-preserved")
    profileAssert(profileIsFloating(again.categories.settings.data.mobile.textScale), "floating-roundtrip")
    profileAssert(again.categories.syncProviders.data.updatedAt = 1761700000000, "millisecond-roundtrip")
    date = CreateObject("roDateTime")
    date.fromISO8601String("2026-11-11T18:00:00Z")
    profileAssert(date.asSeconds() = 1794420000, "iso-z-read")
    profileAssert(left(date.toISOString(), 19) + "Z" = "2026-11-11T18:00:00Z", "iso-z-write")
    refusal = httpTransferOnce(config.baseUrl + "/refused", invalid, "", 5000, 4096)
    print "[profile-probe] refusal-status="; refusal.status; " error="; refusal.error; " bytes="; refusal.bytes; " chars="; len(refusal.body)
    profileAssert(refusal.status = 401 and instr(1, refusal.body, "Invalid API key") > 0, "get-401-retained-before-delete")
    for each method in ["PUT", "PATCH"]
        ' The raw string is already decoded/round-tripped above. The server
        ' checks exact JSON types/case and the UTF-8 Content-Length on the wire.
        response = httpTransferOnce(config.baseUrl + "/wire", invalid, "", 5000, 4096, method, original)
        result = invalid
        if response.body <> "" then result = ParseJson(response.body)
        ok = false
        if result <> invalid then ok = result.ok = true
        profileAssert(response.status = 200 and ok, lcase(method) + "-checked-json-wire")
    end for
    response = httpTransferOnce(config.baseUrl + "/roundtrip", invalid, "", 5000, 4096, "PUT", raw)
    result = invalid
    if response.body <> "" then result = ParseJson(response.body)
    ok = false
    if result <> invalid then ok = result.ok = true
    profileAssert(response.status = 200 and ok, "strict-roundtrip-peer-types")
    response = httpTransferOnce(config.baseUrl + "/oversized", invalid, "", 5000, 64, "PUT", original)
    profileAssert(response.status = 200 and response.error = "too-large" and response.bytes > 64, "utf8-response-byte-budget")
    profileAssert(profilePinVector("000102030405060708090a0b0c0d0e0f", "482913", "1e9d1c5f6cb5e79f17f4e38816915772a54116ba66a05f9521d262c5718db5c1"), "pin-v2-numbers")
    profileAssert(profilePinVector("00000000000000000000000000000000", "1234", "e4ae0c82639990744974cc3495a82432d8c5366e5e5f1796b2f9a36ad12664b5"), "pin-v2-zero-salt-fixture")
    profileAssert(profilePinVector("b81e4c2a9d07f3e1a5c6d8e90f1b2c3d", "UULR", "3ea9be0818449911ef5780edfe9d3a36b030efa593f1116922e88e687f04915f"), "pin-v2-directions4")
    profileAssert(profilePinVector("b81e4c2a9d07f3e1a5c6d8e90f1b2c3d", "UDLRUD", "1743a521f797b639615d35a3ec1f317b23e2c8a1b7c212a6d2ad70699555c1ea"), "pin-v2-directions6")
    if config.registry = true then profileProbeRegistry()
    if config.modelStore = true
        runUserProfileModelChecks()
        testProfileNativeNames()
        runUserProfileStoreChecks()
        testProfileNativeStoreNames()
        runUserProfileAvatarChecks()
        testProfileNativeAvatar()
        runUserProfileLifecycleChecks()
        runUserProfileForgetChecks()
        runUserProfileNavigationChecks()
        runUserProfileRemovalChecks()
        runUserProfileScopeChecks()
        runUserProfileScopeStoreChecks()
        profileProbeStoreRegistry()
    end if
    print "[profile-probe] complete failed="; m.profileFailures
    while true
        event = wait(0, port)
        if type(event) = "roSGScreenEvent"
            if event.isScreenClosed() then exit while
        end if
    end while
end sub

function profileIsFloating(value as dynamic) as boolean
    return type(value) = "Double" or type(value) = "roDouble" or type(value) = "Float" or type(value) = "roFloat"
end function

sub profileAssert(passed as boolean, label as string)
    status = "PASS"
    if not passed
        status = "FAIL"
        m.profileFailures++
    end if
    print "[profile-probe] "; status; " "; label
end sub

function profilePinVector(saltHex as string, pin as string, expected as string) as boolean
    actual = userProfilePinHash(saltHex, pin)
    if actual = invalid then return false
    return userProfilePinDigestMatches(actual, expected) and not userProfilePinDigestMatches(actual, string(64, "f"))
end function
