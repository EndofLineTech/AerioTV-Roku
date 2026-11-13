sub init()
    m.broker = m.top.findNode("broker")
    m.global.addFields({requestGate: m.broker, requestGateRequired: true})
    m.broker.observeField("ready", "gateProbeReady")
    m.broker.control = "RUN"
    m.workers = []
end sub

sub gateProbeReady()
    if m.broker.ready then print "[request-gate] "; FormatJson({kind: "ready"})
end sub

sub gateProbeCommand()
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
        worker.operation = m.operation
        worker.index = i
        worker.fixtureBase = m.top.fixtureBase
        worker.observeField("result", "gateProbeWorkerDone")
        m.workers.push(worker)
        worker.control = "RUN"
    end for
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
    print "[request-gate] complete"
end sub

sub gateProbeWorkerDone(event as object)
    result = event.getData()
    m.completed++
    m.passed = m.passed and result.ok
    if m.completed = m.expected
        print "[request-gate] "; FormatJson({kind: "result", operation: m.operation, passed: m.passed, workers: m.completed})
    end if
end sub
