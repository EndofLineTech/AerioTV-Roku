sub main()
    item = {kind: "movie", title: "The Matrix", year: "1999", tmdbId: "", description: "", genre: "", actors: "", director: "", trailerId: ""}
    rows = [{id: 603, title: "The Matrix", release_date: "1999-03-30"}, {id: 999, title: "The Matrix", release_date: "2020-01-01"}]
    if tmdbSelectMatch(rows, item) <> "603" then stop
    rows.push({id: 604, title: "The Matrix", release_date: "1999-01-01"})
    if tmdbSelectMatch(rows, item) <> "" then stop
    if tmdbImagePath("https://private/key.jpg") <> "" then stop
    if tmdbImagePath("/../key.jpg") <> "" then stop
    if tmdbImagePath("/abc_123.jpg") <> "/abc_123.jpg" then stop
    raw = {id: 603, title: "The Matrix", overview: "An English overview", poster_path: "/abc.jpg", runtime: 136, vote_average: 8.2, genres: [{name: "Science Fiction"}], credits: {cast: [{id: 6384, name: "Keanu Reeves", character: "Neo", profile_path: "/person.jpg"}], crew: [{id: 9339, name: "Lana Wachowski", job: "Director"}]}, videos: {results: [{site: "YouTube", type: "Trailer", key: "abcdefghijk"}]}}
    data = tmdbMetadata(raw, "movie")
    if data.id <> "603" or data.people.count() <> 2 or data.runtimeMinutes <> 136 then stop
    if data.trailerId <> "abcdefghijk" or data.posterPath <> "/abc.jpg" then stop
    merged = vodMergeTmdb(item, data)
    if merged.description <> raw.overview or merged.descriptionSource <> "TMDB" then stop
    if item.description <> "" then stop
    item.description = "The story follows a man and his friends as they discover the world around them."
    if vodMergeTmdb(item, data).description <> item.description then stop
    candidate = vodNormalize({id: 1, uuid: "movie-uuid", name: "The Matrix", year: 1999, tmdb_id: 603}, "movie")
    ref = {id: "603", kind: "movie", title: "The Matrix", year: "1999"}
    if not tmdbCatalogMatch(candidate, ref) then stop
    ref.kind = "series"
    if tmdbCatalogMatch(candidate, ref) then stop
    refs = tmdbReferences([{id: 1, media_type: "person", name: "Someone"}, {id: 603, media_type: "movie", title: "The Matrix", release_date: "1999-03-30"}], "movie", 20)
    if refs.count() <> 1 or refs[0].year <> "1999" then stop
    print "ALL TESTS PASSED"
end sub
