' Native-only, two-video, 20-second capacity probe. No session persists.
' Logs state/error code and bounded transport counters only; never URLs,
' credentials or media names.
sub installMultiviewProbe()
    m.multiviewStage = "wait"
    m.multiviewElapsed = 0
    m.multiviewFirst = invalid
    m.multiviewSecond = invalid
    m.multiviewHttp = invalid
    m.multiviewTimer = m.top.createChild("Timer")
    m.multiviewTimer.duration = 1
    m.multiviewTimer.repeat = true
    m.multiviewTimer.observeField("fire", "multiviewTick")
    m.multiviewTimer.control = "start"
end sub

sub multiviewTick()
    if m.multiviewStage = "alonePending"
        m.multiviewElapsed++
        if m.multiviewElapsed >= 3
            m.multiviewStage = "alone"
            m.multiviewElapsed = 0
            print "[multiview-probe] starting second source alone"
            m.multiviewFirst = multiviewOpen(1)
        end if
        return
    end if
    if m.multiviewStage = "alone"
        m.multiviewElapsed++
        if m.multiviewElapsed >= 20
            print "[multiview-probe] second-alone state="; m.multiviewFirst.state; " error-code="; m.multiviewFirst.errorCode
            multiviewStop()
        end if
        return
    end if
    if m.multiviewStage = "wait"
        if m.page <> "guide" or m.guide.config = invalid then return
        channels = m.guide.config.channels
        if channels.count() < 2 then return
        first = livePlaybackDescriptor(m.baseUrl, channels[0])
        second = livePlaybackDescriptor(m.baseUrl, channels[1])
        if first = invalid or second = invalid then return
        m.multiviewDescriptors = [first, second]
        m.multiviewStage = "running"
        m.multiviewElapsed = 0
        print "[multiview-probe] started two-source trial"
        m.multiviewFirst = multiviewOpen(0)
        return
    end if
    if m.multiviewStage <> "running" then return
    m.multiviewElapsed++
    if m.multiviewElapsed = 4 then m.multiviewSecond = multiviewOpen(1)
    if m.multiviewElapsed = 8
        m.multiviewHttp = CreateObject("roSGNode", "MultiviewHttpTask")
        m.multiviewHttp.url = m.multiviewDescriptors[1].url
        m.multiviewHttp.apiKey = m.apiKey
        m.multiviewHttp.observeField("result", "onMultiviewHttpResult")
        m.multiviewHttp.control = "RUN"
    end if
    if m.multiviewElapsed = 14
        print "[multiview-probe] simultaneous first="; m.multiviewFirst.state; " second="; m.multiviewSecond.state
    end if
    if m.multiviewElapsed >= 20
        multiviewCleanNodes()
        m.multiviewStage = "alonePending"
        m.multiviewElapsed = 0
        print "[multiview-probe] dual sessions cleaned up"
    end if
end sub

sub onMultiviewHttpResult(event as object)
    if not isCurrentTaskEvent(event, m.multiviewHttp) then return
    result = event.getData()
    m.multiviewHttp.unobserveField("result")
    m.multiviewHttp = invalid
    print "[multiview-probe] parallel HTTP status="; result.status; " staged-bytes="; result.bytes; " transport-error="; result.error
end sub

function multiviewOpen(index as integer) as object
    descriptor = m.multiviewDescriptors[index]
    node = m.top.createChild("Video")
    node.translation = [96 + index * 864, 330]
    node.width = 820
    node.height = 462
    node.enableUI = false
    node.mute = index <> 0
    content = CreateObject("roSGNode", "ContentNode")
    content.setFields(descriptor)
    content.httpCertificatesFile = "common:/certs/ca-bundle.crt"
    content.httpHeaders = ["X-API-Key: " + m.apiKey, "Authorization: ApiKey " + m.apiKey]
    node.content = content
    node.observeField("state", "onMultiviewState")
    node.control = "play"
    return node
end function

sub onMultiviewState(event as object)
    video = event.getRoSGNode()
    index = 1
    if m.multiviewFirst <> invalid
        if video.isSameNode(m.multiviewFirst) then index = 0
    end if
    if video.state = "playing" or video.state = "error" or video.state = "finished"
        print "[multiview-probe] video="; index; " state="; video.state; " error-code="; video.errorCode
        if video.state = "error"
            detail = sanitizePlaybackDiagnostic(video.errorStr, m.apiKey)
            category = "other"
            if instr(1, lcase(detail), "buffer") > 0 then category = "buffering"
            if instr(1, detail, "HTTP 403") > 0 then category = "http-403"
            if instr(1, detail, "HTTP 429") > 0 then category = "http-429"
            if instr(1, detail, "HTTP 503") > 0 then category = "http-503"
            print "[multiview-probe] video error category="; category
            info = video.errorInfo
            if type(info) = "roAssociativeArray"
                kind = textValue(info.category)
                if kind <> "http" and kind <> "mediaerror" and kind <> "mediaplayer" then kind = "other"
                singleInstance = instr(1, lcase(textValue(info.dbgmsg)), "only one playing instance") > 0
                print "[multiview-probe] native category="; kind; " code="; textValue(info.errcode); " single-instance="; singleInstance
            end if
        end if
    end if
end sub

sub multiviewStop()
    m.multiviewTimer.control = "stop"
    multiviewCleanNodes()
    m.multiviewStage = "complete"
    print "[multiview-probe] complete cleaned up both sessions"
end sub

sub multiviewCleanNodes()
    if m.multiviewHttp <> invalid
        m.multiviewHttp.cancelRequested = true
        m.multiviewHttp.unobserveField("result")
        m.multiviewHttp = invalid
    end if
    for each video in [m.multiviewFirst, m.multiviewSecond]
        if video <> invalid
            video.unobserveField("state")
            video.control = "stop"
            video.content = invalid
            m.top.removeChild(video)
        end if
    end for
    m.multiviewFirst = invalid
    m.multiviewSecond = invalid
end sub
