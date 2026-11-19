sub main()
    m.nativeSyncMapping = false
    wire = "{""v"":{""textScale"":1.1},""tv"":{""textScale"":1.3},""mobile"":{""textScale"":0.9},""FutureLane"":{""future"":true}}"
    if m.nativeSyncMapping then settings = ParseJson(wire, "d") else settings = ParseJson(wire)
    mobileScale = settings["mobile"]["textScale"]
    tv = dispatcharrSyncSettingsLane(settings, "tv")
    check(tv.ok and tv.present and tv.lane = "tv" and tv.values["textScale"] = settings["tv"]["textScale"], "TV scope reads only its own lane")
    check(type(tv.values["textScale"]) = type(settings["tv"]["textScale"]), "lane selection preserves numeric kind without normalization")
    if m.nativeSyncMapping then check(type(tv.values["textScale"]) = "Double" or type(tv.values["textScale"]) = "roDouble", "native lane projection preserves parsed settings Doubles")
    check(dispatcharrSyncSettingsLane(settings, "all").values["textScale"] = settings["v"]["textScale"], "All devices reads the shared v lane")
    check(dispatcharrSyncSettingsLane(settings, "mobile").lane = "v", "a restored other-class scope becomes All devices on Roku")
    check(not dispatcharrSyncSettingsLane(settings, "off").enabled, "Off reads no lane")
    missing = dispatcharrSyncSettingsLane({v: {appearanceMode: "light"}}, "tv")
    check(missing.ok and not missing.present and missing.values = invalid, "missing TV lane never falls back to shared settings")
    check(not dispatcharrSyncSettingsLane({tv: []}, "tv").ok, "malformed selected lane cannot apply defaults")
    appearance = dispatcharrSyncAppearanceMappings()
    check(appearance.count() = 4, "only the four supported appearance settings are mapped")
    values = {v: ParseJson("{""trueBlack"":true,""channelLogoSize"":100,""logoCornersGuide"":false,""logoCornersGuideCells"":true,""logoCornersList"":true}"), tv: ParseJson("{""channelLogoSize"":250,""logoCornersGuide"":true}")}
    check(appearance[0].wire = "channelLogoSize" and appearance[0].item = "logoSize" and appearance[0].kind = "int" and appearance[0].localScope = "guide", "logo size uses the canonical integer and upstream scope item")
    check(appearance[1].wire = "logoCornersGuide" and appearance[1].item = "roundedGuideLogos" and appearance[1].kind = "bool", "guide logo corners do not alias rounded list logos")
    check(appearance[2].wire = "logoCornersGuideCells" and appearance[2].item = "roundedProgramCells" and appearance[2].kind = "bool", "program cells have an independent scope item")
    check(appearance[3].wire = "trueBlack" and appearance[3].item = "trueBlack" and appearance[3].localScope = "profileSettings", "OLED belongs to the local profile appearance carrier")
    check(dispatcharrSyncSettingsLane(values, "tv").values[appearance[0].wire] = 250, "TV lane retains exact logo-size tenths")
    check(not dispatcharrSyncSettingsLane(values, "tv").values.doesExist(appearance[2].wire), "missing TV cell setting does not fall back to shared value")
    check(dispatcharrSyncSettingsLane(values, "all").values[appearance[2].wire], "All devices reads the shared cell toggle")
    check(not dispatcharrSyncSettingsLane(values, "off").present and values.v.logoCornersList, "Off and the foreign list-logo item remain untouched")
    check(settings["mobile"]["textScale"] = mobileScale and settings["FutureLane"]["future"], "lane selection preserves mobile and unknown lanes")
    names = dispatcharrSyncCategoryNames()
    check(names.count() = 13, "mapping contract names all thirteen v3 categories")
    check(dispatcharrSyncCategoryMapping("favorites").identity = "channel-pk" and dispatcharrSyncCategoryMapping("favorites").cap = 1000, "favorites use server integer channel PKs, never UUID or channel number")
    check(dispatcharrSyncCategoryMapping("progress").identity = "vod-pk" and dispatcharrSyncCategoryMapping("progress").rowTime = "unix-seconds", "VOD progress uses integer catalog PK and wall-clock seconds")
    check(dispatcharrSyncCategoryMapping("reminders").identity = "channel-pk+start", "reminders never use unstable XMLTV program IDs")
    check(dispatcharrSyncCategoryMapping("profiles").rowTime = "unix-seconds" and dispatcharrSyncCategoryMapping("profiles").cap = 25, "wire roster cap is separate from four local profiles")
    check(dispatcharrSyncCategoryMapping("remoteMap").mode = "preserve" and dispatcharrSyncCategoryMapping("settings").mode = "preserve", "unimplemented/locally scoped categories are explicitly preserved, not advertised as active")
    recents = dispatcharrSyncCategoryMapping("recents")
    check(recents.known and recents.mode = "preserve", "shared recents are recognized but not synced to local history")
    check(dispatcharrSyncCategoryMapping("FutureCategory").mode = "preserve" and not dispatcharrSyncCategoryMapping("FutureCategory").known, "future categories are never dropped or treated as empty")
    localIds = ["channel-a", "unresolved", "channel-b", "channel-a"]
    channels = [{uuid: "channel-a", id: "1042", number: "77"}, {uuid: "channel-b", id: "77", number: "1042"}]
    translated = dispatcharrSyncChannelIds(localIds, channels)
    check(translated.ids.count() = 2 and translated.ids[0] = 1042 and translated.ids[1] = 77, "channel translation uses integer server PKs in local order, not UUIDs or channel numbers")
    check(not translated.complete and translated.unresolved.count() = 1 and translated.unresolved[0] = "unresolved" and localIds.count() = 4, "unresolved local channels remain local and prevent a destructive full replacement")
    check(dispatcharrSyncLocalServerId("2147483648") = invalid and dispatcharrSyncLocalServerId("3.0") = invalid, "local identifier translation cannot overflow or reinterpret decimal wire IDs")
    channels.push({uuid: "channel-a", id: "9", number: "9"})
    check(not dispatcharrSyncChannelIds(["channel-a"], channels).complete, "ambiguous catalog ownership cannot choose an arbitrary server ID")
    listing = {apps: [{key: "alice.aeriotv", bytes: 100}], total_bytes: 100, limits: {max_value_bytes: 32768, max_total_bytes: 131072, max_apps: 25}}
    check(dispatcharrSyncWriteBudget(listing, "alice.aeriotv", 32768).ok, "older deployed per-key boundary is inclusive")
    check(not dispatcharrSyncWriteBudget(listing, "alice.aeriotv", 32769).ok, "fresh advertised older-server cap overrides larger schema deployment cap")
    listing.total_bytes = 131000
    check(dispatcharrSyncWriteBudget(listing, "alice.aeriotv", 172).ok and not dispatcharrSyncWriteBudget(listing, "alice.aeriotv", 173).ok, "replacement subtracts only its listed own previous size from total quota")
    listing.limits.max_apps = 1
    check(not dispatcharrSyncWriteBudget(listing, "bob.aeriotv", 2).ok, "full key quota cannot create a new canonical key")
    listing.limits.max_value_bytes = "32768"
    check(not dispatcharrSyncWriteBudget(listing, "alice.aeriotv", 2).ok, "malformed advertised limits never grant a PUT")
    check(not dispatcharrSyncWriteBudget({apps: []}, "alice.aeriotv", 32769).ok, "absent limits use conservative older-server per-key cap")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
