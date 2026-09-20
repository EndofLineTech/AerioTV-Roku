sub main()
    items = [{id: "live", enabled: true}, {id: "vod", enabled: false}, {id: "series", enabled: true}]
    if navigationMove(items, 0, 1) <> 2 then stop
    if navigationMove(items, 2, -1) <> 0 then stop
    if navigationMove(items, 2, 1) <> 2 then stop
    if navigationFirst(items, "vod") <> 0 then stop
    if navigationFirst([{id: "vod", enabled: false}], "vod") <> -1 then stop
    print "ALL TESTS PASSED"
end sub
