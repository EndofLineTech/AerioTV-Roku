sub main()
    entry = metadataCacheEnvelope("account-A", "guide", "window-1", "lineup-1", 1000, {programs: []})
    check(metadataCacheState(entry, "account-A", "guide", "window-1", "lineup-1", 1100, true, 1024), "fresh")
    check(metadataCacheState(entry, "account-B", "guide", "window-1", "lineup-1", 1100, true, 1024), "miss")
    check(metadataCacheState(entry, "account-A", "guide", "window-1", "lineup-2", 1100, true, 1024), "miss")
    check(metadataCacheState(entry, "account-A", "guide", "window-1", "lineup-1", 1100, false, 1024), "miss")
    check(metadataCacheState(entry, "account-A", "guide", "window-1", "lineup-1", 1300, true, 1024), "stale")
    check(metadataCacheState(entry, "account-A", "guide", "window-1", "lineup-1", 1900, true, 1024), "miss")
    check(metadataCacheState(entry, "account-A", "guide", "window-1", "lineup-1", 900, true, 1024), "miss")
    check(metadataCacheState(entry, "account-A", "guide", "window-1", "lineup-1", 1100, true, 3145729), "miss")
    entry.complete = false
    check(metadataCacheState(entry, "account-A", "guide", "window-1", "lineup-1", 1100, true, 1024), "miss")
    entry.complete = true
    entry.schema = 2
    check(metadataCacheState(entry, "account-A", "guide", "window-1", "lineup-1", 1100, true, 1024), "miss")
    entry = metadataCacheEnvelope("account-A", "channels", "summary", "lineup", 1000, [])
    check(metadataCacheState(entry, "account-A", "channels", "summary", "lineup", 1300, true, 1024), "miss")
    if metadataCachePolicy("credentials") <> invalid then stop
    check(metadataCacheState({schema: {}}, "account-A", "guide", "window-1", "lineup", 1100, true, 1024), "miss")
    entry = metadataCacheEnvelope("account-A", "guide", "window-1", "lineup", 1000, "bad")
    check(metadataCacheState(entry, "account-A", "guide", "window-1", "lineup", 1100, true, 1024), "miss")
    print "ALL TESTS PASSED"
end sub

sub check(actual as string, expected as string)
    if actual <> expected
        print "FAIL: cache state expected="; expected; " actual="; actual
        stop
    end if
end sub
