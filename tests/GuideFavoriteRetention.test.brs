sub main()
    saved = ["8", "99", "7"]
    channels = [{id: "8", uuid: "visible-8"}, {id: "7", uuid: "visible-7"}]
    selected = {"visible-8": true}
    ids = retainedGuideFavoriteIds(saved, channels, selected)
    check(FormatJson(ids) = FormatJson(["8", "99"]), "visible untoggle removes only that channel, preserving unavailable IDs and order")
    selected["visible-7"] = true
    ids = retainedGuideFavoriteIds(["99", "8"], channels, selected)
    check(FormatJson(ids) = FormatJson(["99", "8", "7"]), "new favorite appends without reordering or deleting unavailable favorites")
    check(FormatJson(retainedGuideFavoriteIds(saved, [], {})) = FormatJson(saved), "an empty authorized lineup cannot clear saved favorites")
    check(FormatJson(retainedGuideFavoriteIds(["8", "99"], [{id: "8", uuid: "first"}, {id: "8", uuid: "second"}], {first: true})) = FormatJson(["8", "99"]), "duplicate metadata rows cannot reorder an ID still selected by a visible row")
    selected = guideFavoriteSelection(["99", "8"], [{id: "99", uuid: "now-visible-99"}, {id: "8", uuid: "visible-8"}])
    check(selected.doesExist("now-visible-99") and selected.doesExist("visible-8"), "previously unavailable numeric IDs become visible favorites when their lineup returns")
    selected = guideFavoriteSelection(["99", "8"], channels)
    check(selected.count() = 1 and selected.doesExist("visible-8"), "unavailable favorites never create unauthorized visible channel selections")
    check(FormatJson(retainedGuideFavoriteIds(["OpaqueA", "opaquea"], [], {})) = FormatJson(["OpaqueA", "opaquea"]), "unknown opaque saved IDs remain distinct and ordered")
    full = []
    for i = 1000 to 2999
        full.push(i.toStr())
    end for
    ids = retainedGuideFavoriteIds(full, channels, {"visible-8": true})
    check(ids.count() = 2000 and ids[0] = "1000" and ids[1999] = "2999", "existing local cap never displaces an unavailable favorite to make room for a new one")
    check(FormatJson(saved) = FormatJson(["8", "99", "7"]), "favorite planning never mutates the source profile's saved order")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
