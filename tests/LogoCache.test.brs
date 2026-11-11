sub main()
    remote = {uuid: "xc-19", logoId: "", logoUrl: "https://images.test/logo.png?token=fixture%2Bvalue&size=100"}
    assertEqual(channelLogoCacheId(remote), "remote-xc-19", "remote cache filename contains only channel identity")
    urls = channelLogoRemoteUrls([remote])
    plan = channelLogoRequest("remote-xc-19", urls, "https://provider.test", "private-fixture-key", "compatible", "PrivateProviderAgent")
    assertEqual(plan.url, remote.logoUrl, "remote artwork query preserved exactly")
    assertEqual(plan.headers.doesExist("X-API-Key"), false, "provider API key never sent to remote artwork")
    assertEqual(plan.headers.doesExist("Authorization"), false, "provider Authorization never sent to remote artwork")
    assertEqual(plan.headers["Referer"], "", "empty Referer suppresses Roku automatic redirect referrers")
    assertEqual(plan.headers["User-Agent"] = "PrivateProviderAgent", false, "provider-specific agent not leaked to artwork host")
    assertEqual(channelLogoRequest("remote-xc-20", urls, "https://provider.test", "key", "compatible", ""), invalid, "missing URL never falls through to provider endpoint")
    dispatcharr = channelLogoRequest("12", {}, "https://provider.test", "key", "compatible", "")
    assertEqual(dispatcharr.url, "https://provider.test/api/channels/logos/12/cache/", "Dispatcharr proxy unchanged")
    assertEqual(dispatcharr.headers["X-API-Key"], "key", "Dispatcharr proxy keeps authenticated headers")
    for each unsafe in ["file:///tmp/logo.png", "pkg:/images/icon.png", "data:image/png;base64,AAAA", "ftp://host/icon.png", "//host/icon.png", "https://user:pass@host/icon.png", "https://host/icon.png" + chr(10) + "Injected: true", "https://host\\@other/icon.png", "https:///icon.png", ""]
        assertEqual(channelLogoUrl(unsafe), "", "unsafe artwork URL rejected")
    end for
    assertEqual(channelLogoUrl(invalid), "", "missing artwork ignored")
    assertEqual(channelLogoUrl("https://cdn.test/at@sign.png?x=1%202&y=3"), "https://cdn.test/at@sign.png?x=1%202&y=3", "path at-sign and encoded spaces are not userinfo")
    assertEqual(guideInitialLogoIds([remote], 0, 6)[0], "remote-xc-19", "initial guide batch includes Xtream artwork")
    bytes = [137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 0]
    assertEqual(logoExtension(bytes), ".png", "PNG signature")
    bytes = [255, 216, 255, 224, 0, 0, 0, 0, 0, 0, 0, 0]
    assertEqual(logoExtension(bytes), ".jpg", "JPEG signature")
    bytes = [82, 73, 70, 70, 0, 0, 0, 0, 87, 69, 66, 80]
    assertEqual(logoExtension(bytes), ".webp", "WebP signature")
    bytes = [123, 101, 114, 114, 111, 114]
    assertEqual(logoExtension(bytes), "", "HTTP error body is not an image")
    assertEqual(logoFailureReason(403, 0), "HTTP 403", "failed authenticated logo request stays actionable")
    assertEqual(logoFailureReason(-1, 0), "network", "network failure does not masquerade as a missing image")
    assertEqual(logoFailureReason(200, 2097153), "image over 2 MiB", "oversized artwork has distinct reason")
    assertEqual(logoFailureReason(200, 0), "empty image", "empty success has distinct reason")
    assertEqual(logoFailureReason(200, 8), "unreadable image", "unsupported image has distinct reason")
    m.top = {active: true, metadataEvent: invalid}
    m.guideLogoTask = invalid
    m.guideLogoFiles = {}
    m.guideLogoFailed = {}
    m.guideLogoMissingReported = 0
    m.rows = [{root: {visible: true}, logoId: ""}, {root: {visible: true}, logoId: "unusable"}]
    requestGuideLogos()
    assertEqual(m.top.metadataEvent.message, "Visible channels without usable logo IDs: 2", "later rows with absent IDs emit actionable diagnostic")
    m.top.metadataEvent = invalid
    requestGuideLogos()
    assertEqual(m.top.metadataEvent, invalid, "repeat draws do not flood diagnostics")
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label
        stop
    end if
end sub
