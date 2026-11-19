sub main()
    sample = "#EXTM3U" + chr(10) + "#EXTINF:-1 tvg-id=""station.alpha"" tvg-chno=""12.1"" group-title=""Local"",Alpha TV" + chr(10) + "https://example.test/proxy/ts/stream/11111111-2222-3333-4444-555555555555" + chr(10) + "#EXTINF:-1 tvg-id=""station.beta"" group-title=""News"",Beta TV" + chr(10) + "https://example.test/proxy/ts/stream/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee" + chr(10)
    result = m3uParsePlaylist(sample)
    assertEqual(result.ok, true, "standard EXTINF playlist parsed")
    assertEqual(result.channels.count(), 2, "two stream channels")
    assertEqual(result.channels[0].uuid, "11111111-2222-3333-4444-555555555555", "same-server proxy UUID retained")
    assertEqual(result.channels[0].epgKey, "station.alpha", "exact XMLTV ID retained")
    assertEqual(result.channels[0].number, "12.1", "channel numbering retained")
    assertEqual(result.channels[0].streamUrl, "https://example.test/proxy/ts/stream/11111111-2222-3333-4444-555555555555", "playback URL volatile in channel model")
    assertEqual(result.channels[0].isRadio, false, "untagged playlist row stays video")
    assertEqual(result.groups.count(), 2, "groups normalized")
    assertEqual(result.channels[0].groupId <> result.channels[1].groupId, true, "groups isolated")
    assertEqual(m3uParsePlaylist("not an m3u").ok, false, "invalid header rejected")
    assertEqual(m3uParsePlaylist("#EXTM3U" + chr(10) + "#EXTINF:-1,A" + chr(10) + "https://user:pass@example.test/live.ts").ok, false, "userinfo URL rejected")
    assertEqual(m3uParsePlaylist("#EXTM3U" + chr(10) + "#EXTINF:-1,A" + chr(10) + "https://other.test/live.ts").channels.count(), 1, "external stream URL allowed without Dispatcharr credentials")
    assertEqual(m3uParsePlaylist("#EXTM3U" + chr(10) + "#EXTINF:-1,A" + chr(10) + "file:///etc/passwd").ok, false, "unsupported stream scheme rejected")
    assertEqual(m3uParsePlaylist("#EXTM3U" + chr(10) + string(2100000, "X")).ok, false, "oversized playlist rejected")
    assertEqual(m3uStreamUrl("https://example.test?token=fixture&kind=m3u"), "https://example.test?token=fixture&kind=m3u", "query on root URL retained byte-for-byte")
    assertEqual(directLiveStreamFormat("https://example.test/live.M3U8?token=fixture"), "hls", "HLS reader selected by playlist path")
    assertEqual(directLiveStreamFormat("https://example.test/live.ts?label=guide.m3u8"), "ts", "query value cannot select the HLS reader")
    assertEqual(directLiveStreamFormat("https://example.m3u8"), "ts", "host suffix is not a playlist path")
    headers = dispatcharrRequestHeaders("", "authorization", "Fixture Player/1.0")
    assertEqual(headers["User-Agent"], "Fixture Player/1.0", "custom User-Agent retained for direct media")
    assertEqual(headers.count(), 1, "direct media has no Dispatcharr authorization header")
    sample = "#EXTM3U" + chr(10)
    sample += "#EXTINF:-1 radio=""true"",Station" + chr(10) + "https://example.test/radio.ts" + chr(10)
    sample += "#EXTINF:-1 RADIO="" True "",Another Station" + chr(10) + "https://example.test/radio2.ts" + chr(10)
    sample += "#EXTINF:-1 radio=""false"",Video" + chr(10) + "https://example.test/video.ts" + chr(10)
    sample += "#EXTINF:-1,Video with radio=""true"" in its title" + chr(10) + "https://example.test/video2.ts" + chr(10)
    result = m3uParsePlaylist(sample)
    assertEqual(result.channels[0].isRadio, true, "Dispatcharr M3U radio attribute recognized")
    assertEqual(result.channels[1].isRadio, true, "radio token case and whitespace follow upstream parser")
    assertEqual(result.channels[2].isRadio, false, "false does not declare radio")
    assertEqual(result.channels[3].isRadio, false, "title text does not declare radio")
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
