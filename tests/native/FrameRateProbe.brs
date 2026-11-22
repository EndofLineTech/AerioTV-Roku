' Isolated local media: never reads the user's account or changes Roku settings.
sub init()
    m.video = m.top.findNode("video")
    m.label = m.top.findNode("status")
    m.timer = m.top.findNode("sample")
    m.timer.observeField("fire", "frameRateTick")
    m.video.observeField("state", "frameRateState")
    m.info = CreateObject("roDeviceInfo")
    m.elapsed = 0
    m.phase = "50"
    print "[frame-rate-probe] baseline mode="; m.info.GetVideoMode()
    print "[frame-rate-probe] baseline ui="; m.info.GetDisplayMode()
    frameRatePlay("pkg:/fixtures/frame-rate-50.mp4")
    m.timer.control = "start"
end sub

sub frameRatePlay(uri as string)
    m.video.control = "stop"
    content = CreateObject("roSGNode", "ContentNode")
    content.url = uri
    content.streamFormat = "mp4"
    m.video.content = content
    m.video.control = "play"
end sub

sub frameRateState()
    print "[frame-rate-probe] phase="; m.phase; " state="; m.video.state; " code="; m.video.errorCode
end sub

sub frameRateTick()
    m.elapsed++
    mode = m.info.GetVideoMode()
    if m.elapsed mod 5 = 0
        print "[frame-rate-probe] phase="; m.phase; " sec="; m.elapsed; " mode="; mode; " state="; m.video.state
    end if
    m.label.text = "Frame-rate check: " + m.phase + " fps / video mode " + mode
    if m.elapsed = 25
        m.phase = "60"
        frameRatePlay("pkg:/fixtures/frame-rate-60.mp4")
    else if m.elapsed = 50
        m.phase = "stopped"
        m.video.control = "stop"
        m.video.content = invalid
    else if m.elapsed = 60
        m.timer.control = "stop"
        print "[frame-rate-probe] COMPLETE mode="; m.info.GetVideoMode()
    end if
end sub
