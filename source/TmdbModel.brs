' Public TMDB metadata only. No provider URLs, credentials or playback transport.
function tmdbImagePath(value as dynamic) as string
    path = textValue(value)
    if CreateObject("roRegex", "^/[A-Za-z0-9_-]+\.(jpg|png)$", "i").isMatch(path) then return path
    return ""
end function

function tmdbTitleKey(value as dynamic) as string
    return CreateObject("roRegex", "\s+", "").replaceAll(lcase(textValue(value)).trim(), " ")
end function

function tmdbSelectMatch(rows as dynamic, item as object) as string
    if type(rows) <> "roArray" then return ""
    matches = {}
    wanted = tmdbTitleKey(item.title)
    if wanted = "" then return ""
    year = textValue(item.year)
    for each row in rows
        if type(row) = "roAssociativeArray"
            id = textValue(row.id)
            title = row.title
            original = row.original_title
            date = row.release_date
            if item.kind = "series"
                title = row.name
                original = row.original_name
                date = row.first_air_date
            end if
            sameYear = true
            if CreateObject("roRegex", "^[0-9]{4}$", "").isMatch(year) then sameYear = left(textValue(date), 4) = year
            if sameYear and (tmdbTitleKey(title) = wanted or tmdbTitleKey(original) = wanted)
                if CreateObject("roRegex", "^[1-9][0-9]*$", "").isMatch(id) then matches[id] = true
            end if
        end if
    end for
    if matches.count() = 1 then return matches.keys()[0]
    return ""
end function

function tmdbMetadata(raw as dynamic, kind as string) as dynamic
    if type(raw) <> "roAssociativeArray" then return invalid
    id = textValue(raw.id)
    if not CreateObject("roRegex", "^[1-9][0-9]*$", "").isMatch(id) then return invalid
    title = textValue(raw.title)
    if title = "" then title = textValue(raw.name)
    data = {id: id, kind: kind, title: left(title, 256), description: left(textValue(raw.overview), 4000), posterPath: tmdbImagePath(raw.poster_path), rating: left(textValue(raw.vote_average), 12), runtimeMinutes: 0, genre: "", people: [], trailerId: "", adult: raw.adult = true}
    if kind = "episode" then data.posterPath = tmdbImagePath(raw.still_path)
    if mediaNumber(raw.runtime)
        if raw.runtime > 0 and raw.runtime <= 1440 then data.runtimeMinutes = int(raw.runtime)
    end if
    if type(raw.genres) = "roArray"
        for each genre in raw.genres
            if type(genre) = "roAssociativeArray"
                if data.genre <> "" then data.genre += ", "
                data.genre += left(textValue(genre.name), 50)
                if len(data.genre) > 180 then exit for
            end if
        end for
    end if
    people = []
    if type(raw.credits) = "roAssociativeArray"
        if type(raw.credits.cast) = "roArray"
            for each person in raw.credits.cast
                if people.count() >= 20 then exit for
                if type(person) = "roAssociativeArray" then people.push({id: person.id, name: person.name, role: person.character, profile_path: person.profile_path, cast: true})
            end for
        end if
        if type(raw.credits.crew) = "roArray"
            for each person in raw.credits.crew
                if people.count() >= 30 then exit for
                if type(person) = "roAssociativeArray"
                    if person.job = "Director" or person.job = "Writer" then people.push({id: person.id, name: person.name, role: person.job, profile_path: person.profile_path})
                end if
            end for
        end if
    end if
    if type(raw.created_by) = "roArray"
        for each person in raw.created_by
            if people.count() >= 30 then exit for
            if type(person) = "roAssociativeArray" then people.push({id: person.id, name: person.name, role: "Creator", profile_path: person.profile_path})
        end for
    end if
    seen = {}
    for each person in people
        personId = textValue(person.id)
        if CreateObject("roRegex", "^[1-9][0-9]*$", "").isMatch(personId)
            director = person.role = "Director" or person.role = "Creator"
            if not seen.doesExist(personId)
                seen[personId] = data.people.count()
                data.people.push({id: personId, name: left(textValue(person.name), 120), role: left(textValue(person.role), 100), posterPath: tmdbImagePath(person.profile_path), cast: person.cast = true, director: director})
            else if director
                existing = data.people[seen[personId]]
                existing.director = true
                if not existing.cast then existing.role = person.role
            end if
        end if
    end for
    if type(raw.videos) = "roAssociativeArray"
        if type(raw.videos.results) = "roArray"
            for each video in raw.videos.results
                if type(video) = "roAssociativeArray"
                    if video.site = "YouTube" and video.type = "Trailer" and CreateObject("roRegex", "^[A-Za-z0-9_-]{11}$", "").isMatch(textValue(video.key))
                        data.trailerId = video.key
                        exit for
                    end if
                end if
            end for
        end if
    end if
    return data
end function

function vodMergeTmdb(item as object, metadata as object) as object
    merged = ParseJson(FormatJson(item))
    if descriptionLanguage(merged.description) <> "en" and metadata.description <> ""
        merged.description = metadata.description
        merged.descriptionSource = "TMDB"
    end if
    if textValue(merged.genre) = "" then merged.genre = metadata.genre
    if textValue(merged.tmdbId) = "" then merged.tmdbId = metadata.id
    if textValue(merged.trailerId) = "" then merged.trailerId = metadata.trailerId
    merged.tmdbPosterPath = metadata.posterPath
    if textValue(metadata.seriesTmdbId) <> "" then merged.seriesTmdbId = metadata.seriesTmdbId
    merged.tmdb = metadata
    return merged
end function

function tmdbReferences(rows as dynamic, defaultKind as string, limit = 200 as integer) as object
    result = []
    seen = {}
    if type(rows) <> "roArray" then return result
    for each row in rows
        if result.count() >= limit then exit for
        ref = tmdbReference(row, defaultKind)
        if ref <> invalid
            key = ref.kind + ":" + ref.id
            if not seen.doesExist(key)
                seen[key] = true
                result.push(ref)
            end if
        end if
    end for
    return result
end function

function tmdbReference(row as dynamic, defaultKind as string) as dynamic
    if type(row) <> "roAssociativeArray" then return invalid
    kind = defaultKind
    if row.media_type = "movie" then kind = "movie"
    if row.media_type = "tv" then kind = "series"
    if row.media_type = "person" or row.adult = true then return invalid
    if kind <> "movie" and kind <> "series" then return invalid
    id = textValue(row.id)
    if not CreateObject("roRegex", "^[1-9][0-9]*$", "").isMatch(id) then return invalid
    title = textValue(row.title)
    date = textValue(row.release_date)
    if kind = "series"
        title = textValue(row.name)
        date = textValue(row.first_air_date)
    end if
    if title = "" then return invalid
    return {id: id, kind: kind, title: left(title, 256), year: left(date, 4)}
end function

function tmdbCatalogMatch(item as object, reference as object) as boolean
    if item.kind <> reference.kind then return false
    if textValue(item.tmdbId) <> "" then return item.tmdbId = reference.id
    if not CreateObject("roRegex", "^[0-9]{4}$", "").isMatch(reference.year) then return false
    return item.year = reference.year and tmdbTitleKey(item.title) = tmdbTitleKey(reference.title)
end function
