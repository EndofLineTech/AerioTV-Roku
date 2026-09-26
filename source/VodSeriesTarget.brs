' Selection is pure; callers must authorize both the series and the selected
' episode against the current account before offering playback.
function vodSeriesTarget(episodes as object, rawState as dynamic, seriesId as string, complete as boolean) as object
    fallback = {status: "browse", item: invalid, position: 0}
    numeric = CreateObject("roRegex", "^[0-9]{1,3}$", "")
    ordered = []
    for each item in episodes
        if item.kind = "episode" and textValue(item.seriesId) = seriesId and numeric.isMatch(textValue(item.season)) and numeric.isMatch(textValue(item.episode))
            ' Keep season zero intact; an unnumbered/invalid episode must not
            ' be guessed into a Play Next target.
            at = ordered.count()
            for i = 0 to ordered.count() - 1
                earlier = ordered[i]
                if item.season.toInt() < earlier.season.toInt() or (item.season.toInt() = earlier.season.toInt() and item.episode.toInt() < earlier.episode.toInt())
                    at = i
                    exit for
                end if
            end for
            ordered.push(item)
            for j = ordered.count() - 1 to at + 1 step -1
                ordered[j] = ordered[j - 1]
            end for
            ordered[at] = item
        end if
    end for
    if ordered.count() = 0 then return fallback
    state = vodState(rawState)
    savedEntries = {}
    hiddenEntries = {}
    for each entry in state
        savedEntries[entry.key] = entry
        if entry.hidden
            hiddenEntries[entry.key] = true
            if entry.kind = "series" and entry.id = seriesId then return fallback
        end if
    end for
    anchor = invalid
    anchorIndex = -1
    matched = 0
    orphaned = false
    latestOrphan = 0
    for each entry in state
        if entry.kind = "episode" and entry.seriesId = seriesId and (entry.watched or vodResumePosition(entry, entry.duration) > 0)
            index = -1
            for i = 0 to ordered.count() - 1
                if ordered[i].key = entry.key then index = i
            end for
            if index < 0
                orphaned = true
                if entry.touch > latestOrphan then latestOrphan = entry.touch
            else if not entry.hidden and entry.availability <> "denied" and entry.availability <> "missing"
                matched++
                if anchor = invalid or entry.touch > anchor.touch
                    anchor = entry
                    anchorIndex = index
                end if
            end if
        end if
    end for
    if orphaned and (anchor = invalid or latestOrphan >= anchor.touch) then return fallback
    if matched > 1 and anchor <> invalid
        ' Legacy rows without a sequence have no reliable last-played order.
        if anchor.touch = 0 then return fallback
    end if
    if anchor <> invalid
        if not anchor.watched
            position = vodResumePosition(anchor, anchor.duration)
            if position > 0 and not hiddenEntries.doesExist(ordered[anchorIndex].key) then return {status: "resume", item: ordered[anchorIndex], position: position}
            return fallback
        end if
        for i = anchorIndex + 1 to ordered.count() - 1
            item = ordered[i]
            if not hiddenEntries.doesExist(item.key)
                saved = savedEntries[item.key]
                if saved = invalid then saved = {watched: false, hidden: false, position: 0, duration: 0, availability: "unknown"}
                if saved.availability <> "denied" and saved.availability <> "missing"
                    if not saved.watched
                        position = vodResumePosition(saved, saved.duration)
                        if position > 0 then return {status: "resume", item: item, position: position}
                        return {status: "next", item: item, position: 0}
                    end if
                end if
            end if
        end for
        if complete then return {status: "end", item: invalid, position: 0}
        return fallback
    end if
    if not complete then return fallback
    for each item in ordered
        if not hiddenEntries.doesExist(item.key)
            saved = savedEntries[item.key]
            if saved = invalid then saved = {watched: false, hidden: false, availability: "unknown"}
            if not saved.watched and saved.availability <> "missing" and saved.availability <> "denied" then return {status: "play", item: item, position: 0}
        end if
    end for
    return {status: "end", item: invalid, position: 0}
end function
