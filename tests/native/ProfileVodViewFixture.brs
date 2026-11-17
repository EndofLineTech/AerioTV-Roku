' Private component accessors: ordinary loading, details and play controllers.
function profileVodAcceptanceState() as object
    return {loading: m.task <> invalid, count: m.items.count(), total: m.total, kind: m.kind, detail: m.dialog <> invalid and m.detail <> invalid, failure: m.failure <> ""}
end function

function profileVodAcceptanceAction(action as string) as boolean
    if m.task <> invalid then return false
    if action = "search"
        m.query = "The Matrix"
        m.pageNumber = 1
        m.index = 0
        loadVodPage()
        return true
    else if action = "detail"
        for each item in m.items
            if instr(1, lcase(item.title), "the matrix") > 0 and item.year = "1999"
                loadVodPage(item.id)
                return true
            end if
        end for
    else if action = "play"
        if m.dialog = invalid or m.detail = invalid then return false
        for i = 0 to m.detailActions.count() - 1
            if m.detailActions[i] = "play"
                event = {node: m.dialog, choice: i, getRoSGNode: function() as object
                    return m.node
                end function, getData: function() as integer
                    return m.choice
                end function}
                onVodDetailAction(event)
                return true
            end if
        end for
    end if
    return false
end function
