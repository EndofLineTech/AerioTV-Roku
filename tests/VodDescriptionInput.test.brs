sub main()
    resetDescriptionTest()
    onDescriptionLoaded(descriptionEvent(m.descriptionTask, {ok: true, key: m.detail.key, description: "The crew and their captain must find the visitor who arrived from another world."}))
    if instr(1, m.detail.description, "The crew") <> 1 then stop
    if m.dialog.serial <> 5 or m.dialog.buttons.count() <> 2 or m.dialog.focused <> 1 then stop
    if m.descriptionTask <> invalid then stop

    resetDescriptionTest()
    onDescriptionLoaded(descriptionEvent(descriptionNode(99), {ok: true, key: m.detail.key, description: "Stale"}))
    if m.detail.description <> "Texte original" then stop
    onDescriptionLoaded(descriptionEvent(m.descriptionTask, {ok: true, key: "movie:old", description: "Wrong title"}))
    if m.detail.description <> "Texte original" then stop

    resetDescriptionTest()
    onDescriptionLoaded(descriptionEvent(m.descriptionTask, {ok: false, key: m.detail.key}))
    if m.detail.description <> "Texte original" then stop
    if instr(1, m.dialog.message, "No alternate English summary found") = 0 then stop
    print "ALL TESTS PASSED"
end sub

sub resetDescriptionTest()
    m.top = {active: true}
    m.detail = vodNormalize({id: 1, uuid: "test", name: "Title", description: "Texte original"}, "movie")
    m.dialog = descriptionNode(5)
    m.dialog.buttons = ["Play", "Back"]
    m.dialog.focused = 1
    m.descriptionDialog = m.dialog
    m.descriptionTask = descriptionNode(6)
end sub

function descriptionNode(serial)
    return {serial: serial, isSameNode: function(other)
        return m.serial = other.serial
    end function, unobserveField: sub(field)
    end sub}
end function

function descriptionEvent(node, data)
    return {node: node, data: data, getRoSGNode: function()
        return m.node
    end function, getData: function()
        return m.data
    end function}
end function
