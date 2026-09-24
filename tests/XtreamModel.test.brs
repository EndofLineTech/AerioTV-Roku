sub main()
    user = {user_info: {username: "viewer", password: "must-not-publish", auth: 1, status: "Active", allowed_output_formats: ["ts"]}, server_info: {timezone: "America/Chicago", url: "example.test"}}
    account = xtreamAccount(user)
    assertEqual(account.ok, true, "verified Xtream account")
    assertEqual(account.timezone, "America/Chicago", "server timezone normalized")
    assertEqual(instr(1, FormatJson(account), "must-not-publish"), 0, "authentication response password stripped")
    assertEqual(xtreamAccount({user_info: {auth: 0, status: "Active"}}).ok, false, "denied account rejected")
    assertEqual(xtreamAccount({user_info: {auth: 1, status: "Disabled"}}).ok, false, "disabled account rejected")
    assertEqual(xtreamEscape("p@ss/word"), "p%40ss%2Fword", "credential path delimiters encoded")
    assertEqual(xtreamCredentialsValid("viewer", "é"), false, "unsupported non-ASCII credential rejected without misencoding")
    categories = [{category_id: "7", category_name: "Local"}]
    streams = [{stream_id: 19, name: "Alpha TV", num: 2, epg_channel_id: "2", category_id: "7", stream_icon: "https://unrelated.test/icon.png"}]
    lineup = xtreamLiveLineup(streams, categories, "https://example.test", "viewer", "must-not-publish")
    assertEqual(lineup.ok, true, "authorized live lineup mapped")
    assertEqual(lineup.channels[0].uuid, "xc-19", "stable stream identity")
    assertEqual(lineup.channels[0].epgKey, "2", "numeric Xtream XMLTV mapping retained")
    assertEqual(lineup.groups[0].name, "Local", "category normalized")
    assertEqual(xtreamLiveUrl("https://example.test", "viewer", "must-not-publish", lineup.channels[0].streamId), "https://example.test/live/viewer/must-not-publish/19.ts", "live URL constructed only when tuning")
    assertEqual(instr(1, FormatJson(lineup), "must-not-publish"), 0, "lineup contains no provider password")
    assertEqual(lineup.channels[0].logoId, "", "untrusted remote artwork URL excluded")
    assertEqual(xtreamLiveLineup([{stream_id: "bad/id", name: "Invalid"}], categories, "https://example.test", "viewer", "pass").ok, false, "unsafe stream IDs rejected")
    assertEqual(xtreamLiveLineup(streams, categories, "https://user:pass@example.test", "viewer", "pass").ok, false, "credentialed base URL rejected")
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
