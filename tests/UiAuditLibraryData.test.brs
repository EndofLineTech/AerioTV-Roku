sub main()
    first = uiAuditVodResult("movie", "page", 1, "", "library-movies")
    second = uiAuditVodResult("movie", "page", 2, "", "library-movies")
    last = uiAuditVodResult("movie", "page", 3, "", "library-movies")
    check(first.items.count() = 20 and second.items.count() = 20 and last.items.count() = 5, "bounded multi-page catalog")
    check(first.items[0].id <> second.items[0].id and last.next = "", "distinct pages and real end")
    detail = uiAuditVodResult("series", "page", 1, "2", "library-series")
    check(detail.item.kind = "series" and detail.item.id = "2", "detail identity")
    check(uiAuditVodResult("movie", "page", 1, "", "library-denied").status = 403, "denied is not empty")
    check(uiAuditVodResult("movie", "page", 1, "", "library-empty").total = 0, "empty")
    check(uiAuditRecordings("dvr-populated").count() = 48, "multi-section DVR")
    for each state in ["recording", "scheduled", "completed", "failed"]
        rows = uiAuditRecordings("dvr-" + state)
        check(rows.count() = 12 and rows[0].status = state, "recording state fixture")
        check(rows[0].posterLogoId = "", "no provider poster fetch")
    end for
    check(uiAuditRules("dvr-rules").count() = 2, "series rules")
    check(uiAuditRecordings("dvr-empty").count() = 0 and uiAuditRules("dvr-empty").count() = 0, "empty DVR")
    print "ALL TESTS PASSED"
end sub

sub check(ok as boolean, message as string)
    if not ok
        print "FAIL: "; message
        stop
    end if
end sub
