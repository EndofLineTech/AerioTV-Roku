sub init()
    m.video = m.top.findNode("video")
    m.video.observeField("state", "onState")
    m.clock = m.top.findNode("clock")
    m.clock.observeField("fire", "tick")
    m.task = CreateObject("roSGNode", "MediaProbeTask")
    m.task.observeField("media", "onMedia")
    m.task.observeField("report", "onReport")
    m.task.control = "RUN"
    m.elapsed = 0
    m.stage = 0
    m.started = false
    m.clock.control = "start"
end sub

sub onMedia()
    media = m.task.media
    if media = invalid then return
    m.media = media
    content = CreateObject("roSGNode", "ContentNode")
    content.url = media.url
    content.streamFormat = media.format
    content.live = false
    content.httpCertificatesFile = "common:/certs/ca-bundle.crt"
    content.httpHeaders = ["X-API-Key: " + media.apiKey, "Authorization: ApiKey " + media.apiKey]
    m.video.content = content
    m.task.media = invalid
    m.video.control = "play"
    m.video.setFocus(true)
end sub

sub onState()
    print "[media-probe] state="; m.video.state; " duration="; m.video.duration; " position="; m.video.position
    if m.video.state = "playing" and not m.started
        print "[media-probe] audio="; m.video.audioFormat; " speed="; m.video.playbackSpeed
        m.started = true
        m.playedAt = m.elapsed
    end if
    if m.video.state = "error"
        print "[media-probe] native-error="; m.video.errorCode; " detail="; sanitizePlaybackDiagnostic(m.video.errorStr, m.media.apiKey)
        stopProbe()
    end if
end sub

sub tick()
    m.elapsed++
    if m.started
        age = m.elapsed - m.playedAt
        if age = 4
            print "[media-probe] seek-from="; m.video.position; " target=60 duration="; m.video.duration
            m.video.seek = 60
        end if
        if age = 12
            print "[media-probe] after-seek="; m.video.position; " state="; m.video.state
            m.video.control = "pause"
        end if
        if age = 14 then m.video.control = "resume"
        if age >= 20 then stopProbe()
    end if
    if m.elapsed >= 75 then stopProbe()
end sub

sub stopProbe()
    if m.stage = 9 then return
    m.stage = 9
    m.clock.control = "stop"
    m.video.control = "stop"
    m.video.content = invalid
    if m.media <> invalid
        if m.media.sessionId <> ""
            m.cleanup = CreateObject("roSGNode", "MediaProbeTask")
            m.cleanup.sessionId = m.media.sessionId
            m.cleanup.observeField("report", "onCleanup")
            m.cleanup.control = "RUN"
            return
        end if
    end if
    print "[media-probe] complete"
end sub

sub onCleanup()
    print "[media-probe] cleanup="; FormatJson(m.cleanup.report)
    print "[media-probe] complete"
end sub

sub onReport()
    print "[media-probe] result="; FormatJson(m.task.report)
    stopProbe()
end sub
