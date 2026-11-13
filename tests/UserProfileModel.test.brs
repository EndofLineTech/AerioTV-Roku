sub main()
    testProfileIdentity()
    testProfileRoles()
    testProfileOrder()
    print "ALL TESTS PASSED"
end sub

sub testProfileIdentity()
    id = "ABCDEF01-2345-4678-9ABC-0123456789AB"
    check(userProfileLocalId(id) = lcase(id), "imported UUID canonicalizes without changing identity")
    for each bad in ["", "../escape", "short", id + "x", " " + id]
        check(userProfileLocalId(bad) = "", "unsafe/malformed profile ID refused before registry use")
    end for
    check(userProfileKeyName(id) = "profKey_" + lcase(id), "non-default key names canonicalize")
    check(userProfileKeyName("../escape") = "", "invalid ID never forms a key name")
    check(userProfileUserId("2147483648") = 2147483648&, "verified string ID does not overflow 32 bits")
    check(userProfileUserId(7) = 7, "integer server ID accepted")
    for each bad in ["0", "-1", "01", "1.0", "1e2", " 7", "9007199254740992", 7.0, true, invalid]
        check(userProfileUserId(bad) = invalid, "identity requires exact positive integer, not coercion")
    end for
    user = {id: "2147483648", username: "Alice", user_level: 1}
    profile = userProfileFromVerified("slot-a", id, user, 100)
    check(profile <> invalid, "verified default constructor accepts native boxed integers")
    if profile = invalid then return
    check(profile.id = lcase(id) and profile.playlistId = "slot-a" and profile.userId = 2147483648&, "default gets stable injected ID and verified account")
    check(profile.username = "Alice" and profile.displayName = "Alice", "API key default uses verified username")
    check(profile.isDefault and profile.order = -1 and profile.updatedAt = 0 and profile.createdAt = 100, "creation is unstamped and never moved")
    check(profile.role = "user" and profile.pinType = "none", "default begins with server-derived role and no invented PIN")
    check(userProfileDisplayName(string(41, "a")) = string(40, "a"), "display names limited to forty UTF8 bytes")
    check(userProfileUtf8Boundary([97, 240, 159, 166, 137], 4) = 1, "partial four-byte codepoint excluded")
    check(userProfileUtf8Boundary([97, 240, 159, 166, 137, 98], 5) = 5, "complete four-byte codepoint fits")
    user.delete("user_level")
    check(userProfileFromVerified("slot-a", id, user, 100) = invalid, "missing authority does not create admin or unrestricted migration")
end sub

' Native-only byte-array API, not provided by the off-device brs interpreter.
sub testProfileNativeNames()
    check(userProfileUtf8ByteCount(string(36, "a") + "🦉") = 40, "native name budget counts UTF8 bytes, not code units")
    check(userProfileDisplayName(string(37, "a") + "🦉") = string(37, "a"), "never split a four-byte codepoint at name boundary")
    check(userProfileDisplayName(string(36, "a") + "🦉") = string(36, "a") + "🦉", "exact UTF8 byte boundary includes complete codepoint")
end sub

sub testProfileRoles()
    for each user in [{user_level: 10}, {user_level: 11}, {user_level: 0, is_staff: true}, {user_level: 1, is_superuser: true}]
        check(userProfileVerifiedLevel(user) >= 10, "verified admin flags/level fold into admin level")
    end for
    for each user in [{}, {user_level: "10"}, {user_level: true}, {user_level: -1}, {user_level: 10.0}]
        check(userProfileVerifiedLevel(user) = invalid, "unverified authority refused")
    end for
    check(userProfileVerifiedLevel({user_level: 1, is_staff: "true"}) = 1, "malformed optional admin flag never grants admin")
    check(userProfileResolveRole(10, "child") = "admin", "server promotion overrides Child")
    check(userProfileResolveRole(1, "admin") = "user", "wire admin never promotes server non-admin")
    check(userProfileResolveRole(0, "child") = "child", "explicit Child preserved for streamer")
    check(userProfileResolveRole(1, "future") = "user", "unknown role follows verified server default")
    check(userProfileResolveRole(invalid, "admin") = invalid, "unknown authority fails closed")
    check(userProfileFullAccess("admin") and userProfileFullAccess("user"), "Admin and Standard have equal local access")
    check(not userProfileFullAccess("child") and not userProfileFullAccess("future"), "Child/unknown not full access")
end sub

sub testProfileOrder()
    rows = [
        {id: "third", isDefault: false, createdAt: 30, order: -1, updatedAt: 0}
        {id: "default", isDefault: true, createdAt: 40, order: -1, updatedAt: 0}
        {id: "second", isDefault: false, createdAt: 20, order: -1, updatedAt: 0}
        {id: "first", isDefault: false, createdAt: 10, order: 0, updatedAt: 50}
    ]
    before = formatJson(rows)
    sorted = userProfileSorted(rows)
    check(sorted[0].id = "first" and sorted[1].id = "default" and sorted[2].id = "second" and sorted[3].id = "third", "moved order dominates default/creation stable base order")
    moved = userProfileMove(rows, "third", 0, 200)
    check(moved[0].id = "third" and moved[1].id = "first" and moved[3].id = "second", "move applies to displayed order")
    for i = 0 to 3
        check(moved[i].order = i and moved[i].updatedAt = 200, "first move stamps every changed stored position")
    end for
    same = userProfileMove(moved, "third", 0, 300)
    check(formatJson(same) = formatJson(moved), "no-op does not manufacture stamps")
    check(formatJson(rows) = before, "sort/move do not mutate caller state")
    check(userProfileMove(rows, "missing", 0, 200) = invalid, "missing target refused")
    check(userProfileMove(rows, "first", 4, 200) = invalid, "out of range move refused")
    movedBack = userProfileMove(moved, "third", 3, 400)
    check(movedBack[3].id = "third" and movedBack[0].id = "first", "moving right shifts only the intervening rows")
    ties = [{id: "a", isDefault: false, createdAt: 1, order: 0}, {id: "b", isDefault: true, createdAt: 2, order: 0}, {id: "c", isDefault: false, createdAt: 1, order: 0}]
    sorted = userProfileSorted(ties)
    check(sorted[0].id = "b" and sorted[1].id = "a" and sorted[2].id = "c", "tied explicit positions preserve default/creation/insertion order")
end sub

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
