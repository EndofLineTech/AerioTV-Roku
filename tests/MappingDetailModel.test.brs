sub main()
    allowed = {"10": true, "11": true, "other/../../path": true, "": true}
    ids = mappingDetailIds(allowed)
    if ids.count() <> 2 then stop
    for each id in ids
        if id <> "10" and id <> "11" then stop
    end for
    if mappingDetailKey({id: 10, tvg_id: "Channel"}, "10") <> "Channel" then stop
    if mappingDetailKey({id: 11, tvg_id: "Channel"}, "10") <> invalid then stop
    if mappingDetailKey({id: 10, tvg_id: ""}, "10") <> "" then stop
    if mappingDetailKey({id: 10}, "10") <> invalid then stop
    if mappingDetailKey([], "10") <> invalid then stop
    print "ALL TESTS PASSED"
end sub
