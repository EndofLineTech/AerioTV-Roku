sub main()
    raw = {id: 2, uuid: "safe-uuid", name: "Movie", duration_secs: 3600, direct_source: "secret", logo: {id: 8, url: "secret"}}
    item = vodNormalize(raw, "movie")
    if item.key <> "movie:safe-uuid" or item.logoId <> "8" then stop
    if item.doesExist("direct_source") or item.doesExist("logo") then stop
    if vodNormalize({id: 2, uuid: "../bad"}, "movie") <> invalid then stop
    page = vodPage({count: 120000, next: "/api/vod/movies/?page=2", results: [raw]}, "movie", "https://host.test")
    if not page.ok or page.items.count() <> 1 then stop
    if vodPage({count: 1, results: [raw], next: "https://evil.test/"}, "movie", "https://host.test").ok then stop
    if vodPage({count: 2, results: [raw, raw]}, "movie", "https://host.test", 1).ok then stop
    if not vodPage({count: 0, results: []}, "movie", "https://host.test").ok then stop
    if vodPlaybackUrl("https://host.test", item, "roku_session") <> "https://host.test/proxy/vod/movie/safe-uuid/roku_session" then stop
    categories = []
    for i = 1 to 25
        categories.push({id: i, name: "Category " + i.toStr(), m3u_accounts: [{password: "private"}]})
    end for
    page = vodCategoryPage(categories, 2, "https://host.test")
    if not page.ok or page.items.count() <> 5 or page.total <> 25 or page.next <> "" then stop
    if instr(1, FormatJson(page), "private") > 0 then stop
    print "ALL TESTS PASSED"
end sub
