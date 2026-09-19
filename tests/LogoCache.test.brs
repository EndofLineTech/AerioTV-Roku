sub main()
    bytes = [137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 0]
    assertEqual(logoExtension(bytes), ".png", "PNG signature")
    bytes = [255, 216, 255, 224, 0, 0, 0, 0, 0, 0, 0, 0]
    assertEqual(logoExtension(bytes), ".jpg", "JPEG signature")
    bytes = [82, 73, 70, 70, 0, 0, 0, 0, 87, 69, 66, 80]
    assertEqual(logoExtension(bytes), ".webp", "WebP signature")
    bytes = [123, 101, 114, 114, 111, 114]
    assertEqual(logoExtension(bytes), "", "HTTP error body is not an image")
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label
        stop
    end if
end sub
