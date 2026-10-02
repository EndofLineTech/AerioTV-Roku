' Inject harmless fixture titles into the active view; never persist or fetch.
sub seedVisualProbe()
    cancelVod()
    m.shelf = "catalog"
    m.kind = "movie"
    m.query = ""
    m.pageNumber = 1
    m.index = 0
    m.total = 5
    m.hasNext = false
    m.failure = ""
    m.items = []
    for i = 1 to 5
        m.items.push({id: i.toStr(), uuid: "visual-" + i.toStr(), key: "movie:visual-" + i.toStr(), kind: "movie", title: "Fictional movie " + i.toStr(), year: "2026", rating: "PG", logoId: "", tmdbPosterPath: "", description: "Visual-only fixture"})
    end for
    drawVod()
end sub
