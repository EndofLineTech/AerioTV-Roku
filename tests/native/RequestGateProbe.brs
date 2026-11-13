sub init()
    m.broker = m.top.findNode("broker")
    m.global.addFields({requestGate: m.broker, requestGateRequired: true, activeusersession: "fixture-active"})
    m.broker.observeField("ready", "gateProbeReady")
    m.broker.observeField("snapshot", "gateProbeSnapshot")
    m.broker.control = "RUN"
    m.workers = []
end sub

sub gateProbeReady()
    if m.broker.ready then print "[request-gate] "; FormatJson({kind: "ready"})
end sub

sub gateProbeCommand()
    if m.top.command = "sync-read"
        m.syncCases = ["canonical", "legacy", "missing", "key-missing", "forbidden", "unsupported", "proxy404", "identity", "username", "string-identity", "float-schema", "malformed", "newer"]
        m.syncIndex = 0
        m.syncPassed = true
        gateProbeSyncNext()
        return
    end if
    if m.top.command = "session-retire"
        m.global.activeusersession = "fixture-retiring"
        m.retireTimer = m.top.createChild("Timer")
        m.retireTimer.duration = 0.5
        m.retireTimer.observeField("fire", "gateProbeRetireSession")
        m.retireTimer.control = "start"
    end if
    if m.top.command = "video"
        m.nativeVideo = m.top.createChild("Video")
        m.nativePoster = m.top.createChild("Poster")
        m.nativePoster.width = 100
        m.nativePoster.height = 100
        requestGateSetPoster(m.nativePoster, m.top.fixtureBase + "/poster.png", "synthetic-video")
        content = CreateObject("roSGNode", "ContentNode")
        content.url = m.top.fixtureBase + "/movie.mp4"
        content.streamFormat = "mp4"
        content.httpHeaders = ["X-API-Key: synthetic-video"]
        passed = requestGateTrackRenderer(m.nativeVideo, content.url, "synthetic-video")
        if not passed then print "[request-gate] "; FormatJson({kind: "failure", assertion: "video-allowed-after-old-park-expiry"})
        m.nativeVideo.observeField("state", "gateProbeVideoState")
        m.nativeVideo.content = content
        m.nativeVideo.control = "play"
        m.videoStarted = false
        return
    end if
    if m.top.command = "bypasses"
        m.completed = 0
        m.passed = true
        m.workers = []
        for each operation in ["open", "close", "logos", "bridge"]
            kind = "HlsSessionTask"
            if operation = "logos" then kind = "LogoCacheTask"
            if operation = "bridge" then kind = "PlaybackBridgeTask"
            task = CreateObject("roSGNode", kind)
            task.baseUrl = m.top.fixtureBase
            task.apiKey = "synthetic-transport-replacement"
            if operation = "logos"
                task.ids = ["7"]
                urls = {}
                urls["7"] = m.top.fixtureBase + "/blocked-logo"
                task.urls = urls
                task.prefix = "tmp:/request-gate-fixture-logo"
            else if operation = "bridge"
                task.url = m.top.fixtureBase + "/blocked-bridge"
                task.channelUuid = "synthetic"
            else
                task.operation = operation
                task.entryUrl = m.top.fixtureBase + "/blocked-hls"
                task.token = "synthetic-token-123456789"
            end if
            task.observeField("result", "gateProbeBypassDone")
            m.workers.push(task)
            task.control = "RUN"
        end for
        return
    end if
    if m.top.command = "renderers"
        group = m.top.createChild("Group")
        poster = group.createChild("Poster")
        requestGateSetPoster(poster, "https://third.test/image", "synthetic-held")
        passed = poster.uri = ""
        passed = passed and requestGateRenderAllowed("https://third.test/image", "synthetic-replacement")
        video = group.createChild("Video")
        content = CreateObject("roSGNode", "ContentNode")
        content.url = "pkg:/synthetic-not-played"
        video.content = content
        passed = passed and not requestGateTrackRenderer(video, "https://third.test/stream", "synthetic-held")
        requestGateFenceRenderers(group)
        passed = passed and video.content = invalid
        m.top.removeChild(group)
        print "[request-gate] "; FormatJson({kind: "result", operation: "renderers", passed: passed, workers: 0})
        return
    end if
    if m.top.command = "recheck"
        m.recheckTimer = m.top.createChild("Timer")
        m.recheckTimer.duration = 61
        m.recheckTimer.observeField("fire", "gateProbeRecheckDue")
        m.recheckTimer.control = "start"
        m.recheckPhase = 0
        return
    end if
    m.workers = []
    m.completed = 0
    m.passed = true
    m.operation = m.top.command
    count = 1
    if m.operation = "parallel-held" or m.operation = "parallel-park" or m.operation = "parallel-report" then count = 4
    m.expected = count
    for i = 1 to count
        worker = CreateObject("roSGNode", "RequestGateProbeWorker")
        tagTaskForCurrentUser(worker)
        worker.operation = m.operation
        worker.index = i
        worker.fixtureBase = m.top.fixtureBase
        worker.observeField("result", "gateProbeWorkerDone")
        m.workers.push(worker)
        worker.control = "RUN"
    end for
end sub

sub gateProbeSyncNext()
    task = CreateObject("roSGNode", "DispatcharrSyncReadTask")
    tagTaskForCurrentUser(task)
    task.baseUrl = m.top.fixtureBase + "/sync/" + m.syncCases[m.syncIndex]
    task.apiKey = "synthetic-sync"
    task.accountId = "7"
    task.username = "Alice"
    task.observeField("result", "gateProbeSyncDone")
    m.syncTask = task
    task.control = "RUN"
end sub

sub gateProbeSyncDone(event as object)
    result = event.getData()
    m.syncTask.unobserveField("result")
    expected = "unavailable"
    scenario = m.syncCases[m.syncIndex]
    if scenario = "canonical" then expected = "ready"
    if scenario = "legacy" then expected = "legacy"
    if scenario = "missing" or scenario = "key-missing" then expected = "missing"
    if scenario = "newer" then expected = "newer"
    if scenario = "identity" or scenario = "username" or scenario = "string-identity" or scenario = "float-schema" or scenario = "malformed" then expected = "invalid"
    passed = result.state = expected and result.allowWrite = false and m.syncTask.apiKey = ""
    if scenario = "canonical"
        passed = passed and abs(result.data["categories"]["settings"]["data"]["tv"]["textScale"] - 1.3#) < 0.000000001#
        passed = passed and result.data["categories"]["syncProviders"]["data"]["updatedAt"] = 1761700000000&
    end if
    m.syncPassed = m.syncPassed and passed
    if not passed then print "[request-gate] "; FormatJson({kind: "failure", assertion: "sync-read-" + scenario})
    m.syncIndex++
    if m.syncIndex < m.syncCases.count()
        gateProbeSyncNext()
    else
        print "[request-gate] "; FormatJson({kind: "result", operation: "sync-read", passed: m.syncPassed, workers: m.syncIndex})
    end if
end sub

sub gateProbeRetireSession()
    m.global.activeusersession = "fixture-incoming"
end sub

sub gateProbeSnapshot()
    requestGateFenceRenderers(m.top)
end sub

sub gateProbeVideoState()
    if m.nativeVideo = invalid or m.videoStarted then return
    if m.nativeVideo.state = "playing"
        m.videoStarted = true
        m.videoPark = CreateObject("roSGNode", "RequestGateProbeWorker")
        m.videoPark.operation = "video-park"
        m.videoPark.fixtureBase = m.top.fixtureBase
        m.videoPark.observeField("result", "gateProbeVideoParked")
        m.videoPark.control = "RUN"
    else if m.nativeVideo.state = "error"
        print "[request-gate] "; FormatJson({kind: "failure", assertion: "synthetic-native-video-open", code: m.nativeVideo.errorCode})
        print "[request-gate] "; FormatJson({kind: "result", operation: "video", passed: false, workers: 0})
        print "[request-gate] complete"
    end if
end sub

sub gateProbeVideoParked(event as object)
    row = event.getData()
    m.videoPark.unobserveField("result")
    passed = row.ok = true and m.videoStarted and m.nativeVideo.content = invalid and m.nativePoster.uri = ""
    passed = passed and not requestGateTrackRenderer(m.nativeVideo, m.top.fixtureBase + "/movie.mp4", "synthetic-video")
    requestGateSetPoster(m.nativePoster, m.top.fixtureBase + "/blocked-poster.png", "synthetic-video")
    passed = passed and m.nativePoster.uri = ""
    m.nativeVideo.unobserveField("state")
    m.nativeVideo.control = "stop"
    print "[request-gate] "; FormatJson({kind: "result", operation: "video", passed: passed, workers: 1})
    print "[request-gate] complete"
end sub

sub gateProbeBypassDone(event as object)
    row = event.getData()
    ok = row.ok = false
    if type(row.assets) = "roArray" then ok = row.assets.count() = 0 and row.failed.count() = 1
    m.passed = m.passed and ok
    m.completed++
    if m.completed = 4 then print "[request-gate] "; FormatJson({kind: "result", operation: "bypasses", passed: m.passed, workers: m.completed})
end sub

sub gateProbeRecheckDue()
    m.recheck = CreateObject("roSGNode", "RequestGateRecheckTask")
    m.recheck.baseUrl = m.top.fixtureBase
    m.recheck.apiKey = "synthetic-transport-held"
    m.recheck.accountId = "7"
    m.recheck.observeField("result", "gateProbeRecheckDone")
    m.recheck.control = "RUN"
end sub

sub gateProbeRecheckDone(event as object)
    result = event.getData()
    m.recheck.unobserveField("result")
    if m.recheckPhase = 0
        m.recheckPassed = result.ok = true and requestGateRenderAllowed(m.top.fixtureBase + "/ok", "synthetic-transport-held")
        m.recheckPhase = 1
        gateProbeRecheckDue()
        return
    end if
    passed = m.recheckPassed and result.ok = false
    print "[request-gate] "; FormatJson({kind: "result", operation: "recheck", passed: passed, workers: 2})
end sub

sub gateProbeWorkerDone(event as object)
    result = event.getData()
    m.completed++
    m.passed = m.passed and result.ok
    if m.completed = m.expected
        print "[request-gate] "; FormatJson({kind: "result", operation: m.operation, passed: m.passed, workers: m.completed})
    end if
end sub
