sub main()
    item = vodNormalize({id: 2, uuid: "movie-2", name: "A movie"}, "movie")
    state = vodStateUpdate(invalid, item, {position: 100, duration: 1000, watchlist: true})
    if vodResumePosition(state[0], 1000) <> 100 then stop
    if vodResumePosition(state[0], 90) <> 0 then stop
    state = vodStateUpdate(state, item, {hidden: true})
    if vodResumePosition(state[0], 1000) <> 0 then stop
    state = vodStateUpdate(state, item, {hidden: false, watched: true})
    if vodResumePosition(state[0], 1000) <> 0 then stop
    state = vodStateUpdate(state, item, {watched: false, position: 0})
    if not state[0].watchlist or state[0].position <> 0 then stop
    for i = 1 to 30
        item = vodNormalize({id: i, uuid: "title-" + i.toStr(), name: "Title"}, "movie")
        state = vodStateUpdate(state, item, {position: 100})
    end for
    if state.count() <> 20 then stop
    if state[0].uuid <> "title-30" then stop
    if vodState([{id: "../bad", uuid: "bad", kind: "movie"}]).count() <> 0 then stop
    item.authorization = "current"
    state = vodStateUpdate([], item, {position: 100, duration: 1000})
    if vodShelfEntries(state, "continue", {movies: "allowed", series: "allowed", authorization: "changed"}).count() <> 0 then stop
    if vodShelfEntries(state, "continue", {movies: "allowed", series: "allowed", authorization: "current"}).count() <> 1 then stop
    if vodShelfEntries(state, "continue", {movies: "denied", series: "allowed", authorization: "current"}).count() <> 0 then stop
    item.streamFormat = "mkv"
    item.duration = 1000
    menu = vodDetailMenu(item, state[0])
    if menu.buttons.count() <> menu.actions.count() or menu.actions[0] <> "resume" then stop
    if menu.actions[menu.actions.count() - 1] <> "back" then stop
    item.kind = "series"
    menu = vodDetailMenu(item, state[0])
    if menu.actions[0] <> "episodes" or menu.buttons.count() <> 5 then stop
    print "ALL TESTS PASSED"
end sub
