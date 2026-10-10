sub main()
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
