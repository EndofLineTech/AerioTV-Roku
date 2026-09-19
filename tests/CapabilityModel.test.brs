sub main()
    settings = [{key: "system_settings", value: {catchup_enabled: true}}]
    cap = normalizeCapabilities({id: 1, user_level: 10}, {version: "0.31.0"}, settings, 100)
    assertEqual(cap.switchStreams, "allowed", "admin source switch")
    assertEqual(cap.dvr, "manage", "admin DVR")
    assertEqual(cap.catchup, "allowed", "user and system catchup")
    assertEqual(cap.version, "0.31.0", "server version")
    cap = normalizeCapabilities({id: 2, user_level: 1, is_staff: true, custom_properties: {vod_movies_enabled: false, dvr_access: "manage"}}, invalid, settings, 100)
    assertEqual(cap.switchStreams, "denied", "staff flag alone is not 0.31 IsAdmin")
    assertEqual(cap.movies, "denied", "explicit denial")
    assertEqual(cap.series, "allowed", "default series permission")
    assertEqual(cap.dvr, "manage", "delegated DVR manager")
    assertEqual(normalizeCapabilities({id: 3}, invalid, invalid, 100).switchStreams, "unknown", "missing level is not admin")
    assertEqual(normalizeCapabilities({id: 1, user_level: 10}, invalid, invalid, 100).catchup, "unknown", "unknown global catchup")
    assertEqual(normalizeCapabilities({id: 1, user_level: 10}, invalid, [{key: "system_settings", value: {catchup_enabled: false}}], 100).catchup, "denied", "global catchup denied")
    assertEqual(normalizeCapabilities({id: 3, user_level: 0}, invalid, settings, 100).movies, "denied", "streamer cannot list VOD")
    facts = normalizeChannelCapabilities([{id: 1, is_catchup: true, catchup_days: 99}, {id: 2, is_catchup: false, catchup_days: 7}])
    assertEqual(facts["1"].catchupDays, 30, "retention cap")
    assertEqual(facts["2"].catchupDays, 0, "disabled catchup")
    choices = normalizeStreamChoices([{id: 10, name: "Provider A", url: "https://provider/a/secret"}, {id: 11, name: "Provider B", url: "https://provider/b/secret"}], {stream_id: 11, url: "https://provider/a/secret"})
    assertEqual(choices[0].active, true, "exact URL confirms source despite stale stream ID")
    assertEqual(choices[1].reported, true, "reported source is labeled separately")
    assertEqual(choices[0].doesExist("url"), false, "provider URLs never enter menu data")
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
