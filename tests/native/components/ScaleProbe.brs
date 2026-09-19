sub init()
    m.top.backgroundColor = "0x345678FF"
    m.video = m.top.findNode("video")
    m.viewport = m.top.findNode("viewport")
    m.label = m.top.findNode("label")
    m.timer = m.top.findNode("step")
    m.timer.observeField("fire", "stepProbe")
    m.video.observeField("state", "onState")
    m.phase = 0
    m.video.content = CreateObject("roSGNode", "ContentNode")
    m.video.content.url = "pkg:/fixtures/4by3.mp4"
    m.video.content.streamFormat = "mp4"
    m.video.loop = true
    m.video.control = "play"
    m.timer.control = "start"
end sub

sub onState()
    print "[scale-probe] state="; m.video.state; " error="; m.video.errorCode
end sub

sub stepProbe()
    print "[scale-probe] phase="; m.phase; " state="; m.video.state; " resolution="; FormatJson(m.video.resolution); " bounds="; FormatJson(m.video.sceneBoundingRect()); " stats="; FormatJson(m.video.decoderStats)
    if m.phase = 0
        m.label.text = "Fit: known 4:3 sample in 800x450 viewport"
    else if m.phase = 1
        m.video.width = 600
        m.video.height = 450
        m.video.scale = [1.333333, 1.333333]
        m.video.translation = [0, -75]
        m.label.text = "Fill: 4:3 enlarged uniformly; clipping at 800x450"
    else if m.phase = 2
        m.video.width = 600
        m.video.height = 450
        m.video.scale = [1.333333, 1]
        m.video.translation = [0, 0]
        m.label.text = "Stretch: horizontal-only transform into 800x450"
    else if m.phase = 3
        m.video.scale = [1, 1]
        m.video.width = 464
        m.video.height = 261
        m.viewport.translation = [1360, 24]
        m.viewport.clippingRect = [0, 0, 464, 261]
        m.label.text = "Mini-player: same sample and decoder"
    else if m.phase = 4
        m.video.control = "stop"
        m.label.text = "Native scaling checks finished"
        m.timer.control = "stop"
        print "[scale-probe] COMPLETE"
    end if
    m.phase++
end sub
