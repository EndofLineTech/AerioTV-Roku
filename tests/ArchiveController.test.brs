sub main()
    node = {serial: 1, isSameNode: function(other)
        return m.serial = other.serial
    end function, unobserveField: sub(field)
    end sub}
    m.archiveTask = node
    m.archiveSeeking = true
    m.archiveSession = invalid
    m.archivePositionTask = invalid
    m.archiveContext = {program: {id: "old"}}
    m.mediaPlayer = {visible: true, callFunc: sub(name)
        m.called = name
    end sub}
    m.guide = {visible: false, active: false}
    m.page = "onDemand"
    event = {node: node, getRoSGNode: function()
        return m.node
    end function, getData: function()
        return {ok: false, message: "Creation failed"}
    end function}
    onArchiveCreated(event)
    if m.page <> "guide" or not m.guide.visible or not m.guide.active then stop
    if m.mediaPlayer.visible or m.mediaPlayer.called <> "closeMedia" then stop
    if m.archiveContext <> invalid or m.archiveSeeking then stop
    print "ALL TESTS PASSED"
end sub

sub recordDiagnostic(stage, code, message)
end sub

sub showNotice(message)
    m.notice = message
end sub
