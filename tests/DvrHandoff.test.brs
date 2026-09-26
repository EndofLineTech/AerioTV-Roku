sub main()
    m.page = "onDemand"
    m.mediaReturn = "dvr"
    m.accountIdentity = "account"
    m.serverAccountId = "server-account"
    m.baseUrl = "https://example.test"
    m.apiKey = "private"
    m.mediaIdentity = "playback-1"
    m.capabilities = {dvr: "view"}
    m.dvrPlayback = {account: "account", id: "12", growing: true}
    m.mediaPlayer = {request: {account: "account", identity: "playback-1", key: "12", mode: "recording", growing: true, title: "Original", apiKey: "private"}}
    m.dvrHandoff = {account: "account", identity: "playback-1", id: "12", position: 45}
    m.dvrHandoffTask = handoffTask()
    m.result = {ok: true, accountId: "server-account", recording: {id: "12", status: "recording", hlsReady: true, fileReady: true}}
    onDvrHandoffReady(handoffEvent(m.result))
    if m.mediaPlayer.request.growing <> true or m.dvrPlayback.growing <> true then stop ' still recording, never open MKV placeholder

    m.dvrHandoff = {account: "account", identity: "playback-1", id: "12", position: 45}
    m.dvrHandoffTask = handoffTask()
    m.result = {ok: true, accountId: "server-account", recording: {id: "13", status: "completed", fileReady: true}}
    onDvrHandoffReady(handoffEvent(m.result))
    if m.mediaPlayer.request.growing <> true then stop ' a different recording cannot replace the video

    m.dvrHandoff = {account: "account", identity: "playback-1", id: "12", position: 45}
    m.dvrHandoffTask = handoffTask()
    m.result = {ok: true, accountId: "another-server-account", recording: {id: "12", status: "completed", fileReady: true}}
    onDvrHandoffReady(handoffEvent(m.result))
    if m.mediaPlayer.request.growing <> true then stop ' a stale account cannot replace the video

    m.dvrHandoff = {account: "account", identity: "playback-1", id: "12", position: 45}
    m.dvrHandoffTask = handoffTask()
    m.result = {ok: true, accountId: "server-account", recording: {id: "12", status: "completed", fileReady: true}}
    onDvrHandoffReady(handoffEvent(m.result))
    if m.mediaPlayer.request.url <> "https://example.test/api/channels/recordings/12/file/" then stop
    if m.mediaPlayer.request.streamFormat <> "mkv" or m.mediaPlayer.request.growing <> false then stop
    if m.mediaPlayer.request.resume <> 45 or m.dvrPlayback.growing <> false then stop
    if m.mediaPlayer.request.identity <> "playback-1" then stop
    if m.mediaPlayer.request.apiKey <> "private" then stop

    m.dvrHandoff = {account: "account", identity: "playback-1", id: "12", position: 45}
    m.dvrHandoffTask = handoffTask()
    cancelDvrHandoff()
    if m.dvrHandoff <> invalid or m.dvrHandoffTask <> invalid then stop
    m.mediaPlayer.request = {growing: true}
    onDvrHandoffReady(handoffEvent(m.result))
    if m.mediaPlayer.request.growing <> true then stop ' stale task after exit

    m.mediaPlayer.isSameNode = function(node as object) as boolean
        return node.id = "player"
    end function
    m.dvrPlayback.growing = true
    m.mediaPlayer.request = {account: "account", identity: "playback-1", key: "12", mode: "recording", growing: true}
    m.capabilities.dvr = "denied"
    onDvrHandoffRequested(requestEvent({account: "account", identity: "playback-1", id: "12", position: 45}))
    if m.dvrHandoffTask <> invalid then stop ' permission revocation blocks status fetch
    m.capabilities.dvr = "view"
    onDvrHandoffRequested(requestEvent({account: "other-account", identity: "playback-1", id: "12", position: 45}))
    if m.dvrHandoffTask <> invalid then stop ' event from a different account cannot fetch
    print "ALL TESTS PASSED"
end sub

function handoffTask() as object
    return {cancelRequested: false, unobserveField: sub(field as string)
    end sub, isSameNode: function(node as object) as boolean
        return node.id = "task"
    end function}
end function

function handoffEvent(data as object) as object
    return {data: data, getRoSGNode: function() as object
        return {id: "task"}
    end function, getData: function() as object
        return m.data
    end function}
end function

function requestEvent(data as object) as object
    return {data: data, getRoSGNode: function() as object
        return {id: "player"}
    end function, getData: function() as object
        return m.data
    end function}
end function
