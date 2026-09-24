sub main()
    assertEqual(chr(233), "é", "BrightScript emits Unicode code points")
    start = guideEpoch("2026-09-23T18:00:00Z")
    assertEqual(xmltvEpoch("20260923133000 -0500"), guideEpoch("2026-09-23T18:30:00Z"), "XMLTV negative timezone offset")
    assertEqual(xmltvEpoch("20260923204500 +0230"), guideEpoch("2026-09-23T18:15:00Z"), "XMLTV positive timezone offset")
    assertEqual(xmltvEpoch("20260923183000"), invalid, "missing timezone rejected")
    assertEqual(xmltvEpoch("20260923183000 +2560"), invalid, "invalid timezone rejected")
    fast = xmltvFastFields("<programme><title lang=""en"">News &amp; Weather</title><desc>Caf&#xE9; updates</desc><category>News</category><new/><icon src=""https://example.test/icon.jpg""/></programme>")
    assertEqual(fast.title, "News & Weather", "named entity decoded without whole XML tree")
    assertEqual(fast.description, "Café updates", "hexadecimal Unicode entity decoded")
    assertEqual(fast.categories[0], "News", "XMLTV category retained")
    assertEqual(fast.is_new, true, "XMLTV new flag retained")
    assertEqual(fast.icon, "https://example.test/icon.jpg", "XMLTV icon URI retained only in volatile metadata")
    assertEqual(xmltvFastFields("<programme><title>Missing closing tag</programme>"), invalid, "malformed fragment needs native validation")
    allowed = guideDictionary()
    allowed["station.alpha"] = true
    parser = function(fragment as string) as object
        return {title: "News & Weather", description: "Local updates", categories: ["News"], is_new: true, icon: "https://example.test/icon.jpg"}
    end function
    state = xmltvWindowState(start, start + 10800, allowed, parser)
    fragment = "<programme start=""20260923133000 -0500"" stop=""20260923140000 -0500"" channel=""station.alpha""><title lang=""en"">News &amp; Weather</title><desc>Local updates</desc><category>News</category><new/><icon src=""https://example.test/icon.jpg""/></programme>"
    ' Split inside the first programme attribute, then complete it.
    xmltvConsumeChunk(state, "<tv>" + left(fragment, 62))
    xmltvConsumeChunk(state, mid(fragment, 63) + "</tv>")
    assertEqual(state.error, "", "chunked programme parsed")
    assertEqual(state.count, 1, "one permitted programme indexed")
    assertEqual(state.index["station.alpha"][0].title, "News & Weather", "parsed title mapped")
    assertEqual(state.index["station.alpha"][0].startsAt, start + 1800, "XMLTV timezone converted to UTC")
    assertEqual(state.index["station.alpha"][0].id, "station.alpha-" + (start + 1800).toStr(), "stable reminder identity without provider URL")
    assertEqual(state.index["station.alpha"][0].categories[0], "News", "category retained")
    assertEqual(state.index["station.alpha"][0].is_new, true, "new badge retained")
    assertEqual(state.index["station.alpha"][0].poster, "https://example.test/icon.jpg", "program artwork retained only in volatile response")
    assertEqual(len(state.tail) <= 9, true, "no raw programme retained after completed record")
    xmltvConsumeChunk(state, "<programme start=""20260923133000 -0500"" stop=""20260923140000 -0500"" channel=""foreign""><title>Ignore</title></programme>")
    assertEqual(state.count, 1, "other account/channel not indexed")
    xmltvConsumeChunk(state, "<programme start=""20260922133000 -0500"" stop=""20260922140000 -0500"" channel=""station.alpha""><title>Old</title></programme>")
    assertEqual(state.count, 1, "outside requested window not indexed")
    bad = xmltvWindowState(start, start + 10800, allowed)
    xmltvConsumeChunk(bad, "<programme " + string(17000, "X"))
    assertEqual(bad.error <> "", true, "oversized record fails within bounded buffer")
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
