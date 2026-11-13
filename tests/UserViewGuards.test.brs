sub main()
    m.global = {activeusersession: "incoming"}
    m.page = "onDemand"
    node = {isSameNode: function(other as object) as boolean
        return true
    end function}
    m.mediaPlayer = node
    m.vod = node
    event = {data: userViewEvent({target: 60, closed: true}, "outgoing")
        getData: function() as dynamic
            return m.data
        end function
        getRoSGNode: function() as object
            return {}
        end function
    }
    ' No account, archive, registry or player state exists here. Any work past
    ' the scope fence would fail rather than silently passing a no-op fixture.
    onMediaClosed(event)
    onArchiveSeek(event)
    onArchiveGoLive(event)
    onMediaProgress(event)
    onMediaDiagnostic(event)
    onVodStateChange(event)
    onVodBookmark(event)
    onVodPlay(event)
    onArchiveRequested(event)
    onUnifiedSearchVodSelection(event)
    if m.page <> "onDemand" then stop
    event.data = 60
    onArchiveSeek(event) ' Legacy scalar controls cannot bypass an active scope.
    if m.page <> "onDemand" then stop
    print "ALL TESTS PASSED"
end sub
