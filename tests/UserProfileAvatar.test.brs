sub main()
    for each pair in [["alice", "slate"], ["sam", "blue"], ["Alice ", "slate"], [chr(9) + "sam" + chr(10), "blue"]]
        check(userProfileAvatarColor(pair[0]) = pair[1], "shared username color vector")
    end for
    check(userProfileAvatarUnitColor([55358, 56713]) = "sea", "supplementary codepoint hashes as two UTF16 units")
    check(userProfileAvatarUnitColor([106, 111, 115, 233]) = "purple", "accented username uses UTF16 units, not UTF8 bytes")
    for each raw in [invalid, {}, {icon: "future", color: "future"}, {icon: "initial", color: ""}]
        check(formatJson(userProfileNormalizeAvatar(raw)) = "{}", "default/unknown avatar normalizes to no override")
    end for
    avatar = userProfileNormalizeAvatar({icon: "paw", color: "teal", future: true})
    check(avatar.icon = "paw" and avatar.color = "teal" and avatar.future = invalid, "known interoperable avatar retained, unknown properties ignored")
    check(userProfileNormalizeAvatar({icon: 7, color: true}).count() = 0, "malformed avatar members cannot throw or grant metadata")
    check(userProfileAvatarInk("teal") = "0B1220" and userProfileAvatarInk("orange") = "0B1220" and userProfileAvatarInk("slate") = "0B1220" and userProfileAvatarInk("green") = "0B1220", "light backgrounds use shared dark ink")
    check(userProfileAvatarInk("blue") = "FFFFFF" and userProfileAvatarInk("ember") = "FFFFFF" and userProfileAvatarInk("sea") = "FFFFFF" and userProfileAvatarInk("purple") = "FFFFFF", "dark backgrounds use white ink")
    check(userProfileAvatarInitial("  alice", "other") = "A", "initial uses trimmed display name")
    check(userProfileAvatarInitial(" " + chr(9), "sam") = "S", "blank name falls back to username")
    check(userProfileAvatarInitial("", "") = "?", "blank names use question mark")
    check(userProfileAvatarIcons().count() = 13 and userProfileAvatarIcons()[0] = "initial" and userProfileAvatarIcons()[12] = "movie", "interoperable icon catalog order")
    print "ALL TESTS PASSED"
end sub

sub testProfileNativeAvatar()
    check(userProfileAvatarColor("🦉") = "sea", "native supplementary UTF16 color vector")
    check(userProfileAvatarColor("José") = "purple", "native accented UTF16 color vector")
    check(userProfileAvatarInitial(" 🦉 house", "other") = "🦉", "native initial is a complete supplementary codepoint")
    check(userProfileAvatarInitial("éclair", "other") = "É", "native initial uppercases accented letter")
end sub

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
