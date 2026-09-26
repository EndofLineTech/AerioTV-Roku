sub main()
    episodes = [targetEpisode(3, 1, 1), targetEpisode(1, 0, 1), targetEpisode(2, 0, 2)]
    result = vodSeriesTarget(episodes, [], "42", true)
    assertTarget(result, "play", "episode-1", "season-zero first")
    state = vodStateUpdate([], episodes[0], {position: 80, duration: 1000})
    result = vodSeriesTarget(episodes, state, "42", true)
    assertTarget(result, "resume", "episode-3", "unfinished episode resumes")
    state = vodStateUpdate(state, episodes[0], {position: 0, watched: true})
    assertTarget(vodSeriesTarget(episodes, state, "42", true), "end", "", "last episode completed")
    state = vodStateUpdate([], episodes[1], {watched: true})
    assertTarget(vodSeriesTarget(episodes, state, "42", true), "next", "episode-2", "completed first advances")
    state = vodStateUpdate(state, episodes[2], {watched: true})
    assertTarget(vodSeriesTarget(episodes, state, "42", true), "next", "episode-3", "completed second advances")
    state = vodStateUpdate(state, episodes[1], {watched: true})
    assertTarget(vodSeriesTarget(episodes, state, "42", true), "next", "episode-3", "already watched episode skipped")
    state = vodStateUpdate(state, episodes[0], {hidden: true})
    assertTarget(vodSeriesTarget(episodes, state, "42", true), "end", "", "hidden next not offered")
    if vodSeriesTarget(episodes, state, "42", false).status <> "browse" then stop

    state = vodStateUpdate([], episodes[1], {watched: true})
    state = vodStateUpdate(state, episodes[2], {position: 300, duration: 1000})
    assertTarget(vodSeriesTarget(episodes, state, "42", true), "resume", "episode-2", "touch survives pinned group ordering")
    state = vodStateUpdate(state, episodes[2], {position: 0, watched: true})
    assertTarget(vodSeriesTarget(episodes, state, "42", true), "next", "episode-3", "finish moves ahead")
    missing = vodStateUpdate(state, episodes[0], {position: 0})
    for each row in missing
        if row.key = episodes[0].key then row.availability = "missing"
    end for
    assertTarget(vodSeriesTarget(episodes, missing, "42", true), "end", "", "missing successor excluded")
    if vodSeriesTarget(episodes, missing, "42", false).status <> "browse" then stop

    if vodSeriesTarget(episodes, [], "42", false).status <> "browse" then stop
    if vodSeriesTarget([episodes[1]], [], "wrong-series", true).status <> "browse" then stop
    omitted = vodNormalize({id: 9, uuid: "episode-9", name: "Not on this page", series: {id: 42}, season_number: 3, episode_number: 9}, "episode")
    state = vodStateUpdate([], episodes[1], {watched: true})
    state = vodStateUpdate(state, omitted, {position: 100, duration: 1000})
    if vodSeriesTarget(episodes, state, "42", false).status <> "browse" then stop
    legacy = [{id: "1", uuid: "episode-1", kind: "episode", title: "Old", seriesId: "42", position: 60, duration: 1000}, {id: "2", uuid: "episode-2", kind: "episode", title: "Old", seriesId: "42", watched: true}]
    if vodSeriesTarget(episodes, legacy, "42", true).status <> "browse" then stop
    print "ALL TESTS PASSED"
end sub

function targetEpisode(id as integer, season as integer, number as integer) as object
    return vodNormalize({id: id, uuid: "episode-" + id.toStr(), name: "Episode " + id.toStr(), series: {id: 42, name: "Series"}, season_number: season, episode_number: number}, "episode")
end function

sub assertTarget(actual as object, action as string, key as string, context as string)
    if actual.status <> action or (key <> "" and actual.item.uuid <> key)
        print "FAIL "; context; " result="; FormatJson(actual)
        stop
    end if
end sub
