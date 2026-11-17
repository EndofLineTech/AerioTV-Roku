sub main()
    check(userProfilePinNormalize("numbers", ["4", "8", "2", "9", "1", "3"]) = "482913", "numeric vector normalization")
    check(userProfilePinNormalize("directions", ["Up", "u", "left", "R"]) = "UULR", "direction names and letters case insensitive")
    for each entries in [["1", "2", "3"], ["1", "2", "3", "4", "5", "6", "7"], ["1", "2", "3", "12"], ["1", "2", "3", 4]]
        check(userProfilePinNormalize("numbers", entries) = invalid, "invalid numeric entry fails closed")
    end for
    check(userProfilePinNormalize("directions", ["u", "d", "l", "Select"]) = invalid, "select is not a direction PIN entry")
    check(userProfilePinNormalize("unknown", ["1", "2", "3", "4"]) = invalid, "unknown PIN type not verified")
    a = string(64, "a")
    check(userProfilePinDigestMatches(a, a), "same digest matches")
    check(not userProfilePinDigestMatches(a, "b" + mid(a, 2)), "first mismatch rejected")
    check(not userProfilePinDigestMatches(a, left(a, 63) + "b"), "last mismatch rejected")
    check(not userProfilePinDigestMatches(a, left(a, 63)), "malformed length rejected")
    check(not userProfilePinDigestMatches(string(64, "g"), string(64, "g")), "nonhex digest rejected")
    check(userProfilePinRecordValid({pinType: "numbers", pinHash: a, pinSalt: string(32, "b")}), "valid imported v2 record")
    check(not userProfilePinRecordValid({pinType: "numbers", pinHash: "bad", pinSalt: string(32, "b")}), "corrupt record cannot be an unlocked PIN")
    check(not userProfilePinCreationAllowed(), "new salt creation stays production gated")
    for each text in ["udlr", "Up Down Left Right", " u, DOWN, left, r ", "U D L R", "right right right right right right"]
        entries = userProfilePinTextEntries("directions", text)
        check(type(entries) = "roArray", "native letter or spoken-word text parses without changing the PIN record")
        check(userProfilePinNormalize("directions", entries) <> invalid, "parsed directions use existing canonical hash input")
    end for
    check(userProfilePinNormalize("directions", userProfilePinTextEntries("directions", "up up left right")) = "UULR", "spoken direction words preserve exact entry order and repetition")
    for each text in ["", "UDL", "UDLRUDL", "up down left select", "updownleftright", "up. down left right", "you down left right", "up,,down,left,right", string(65, "u")]
        check(userProfilePinTextEntries("directions", text) = invalid, "malformed or ambiguous keyboard input is not guessed into a PIN")
    end for
    check(userProfilePinNormalize("numbers", userProfilePinTextEntries("numbers", "482913")) = "482913", "numeric pad keeps exact ASCII digit contract")
    check(userProfilePinTextEntries("numbers", "1 2 3 4") = invalid, "numeric input does not gain permissive speech aliases")
    check(userProfilePinTextEntries("unknown", "UDLR") = invalid, "unknown keyboard PIN type fails closed")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
