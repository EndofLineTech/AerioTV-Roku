' Synthetic recording-style HLS fixture, no real account or server access.
sub init()
    m.player = m.top.findNode("player")
    m.player.observeField("closed", "growingControlsClosed")
    m.player.observeField("recordingHandoff", "onSyntheticHandoff")
    m.timer = m.top.findNode("sample")
    m.timer.observeField("fire", "growingControlsSample")
    app = CreateObject("roAppInfo")
    if app.getValue("dvr_controls_fixture_native") = "true"
        m.nativeVideo = m.top.findNode("nativeVideo")
        media = CreateObject("roSGNode", "ContentNode")
        media.url = app.getValue("dvr_controls_fixture_url")
        media.streamFormat = "hls"
        media.live = true
        media.title = "Synthetic native HLS baseline"
        m.nativeVideo.enableLiveAvailabilityWindow = true
        m.nativeVideo.enableTrickPlay = true
        m.nativeVideo.observeField("state", "growingNativeState")
        m.nativeVideo.content = media
        m.nativeVideo.visible = true
        m.nativeVideo.control = "play"
        m.nativeVideo.setFocus(true)
        m.timer.control = "start"
        return
    end if
    growing = app.getValue("dvr_controls_fixture_growing") = "true"
    m.player.request = {account: "fixture", identity: "synthetic-reader", key: "fixture", mode: "recording", title: "Synthetic recording", url: app.getValue("dvr_controls_fixture_url"), apiKey: "", streamFormat: app.getValue("dvr_controls_fixture_format"), growing: growing, resume: 0}
    m.timer.control = "start"
end sub

sub growingNativeState()
    print "[growing-controls] baseline state="; m.nativeVideo.state; " code="; m.nativeVideo.errorCode
end sub

' The synthetic fixture has no Dispatcharr status endpoint. Its finite file
' already exists before the timed redirect; this test-only driver exercises the
' completed reader after the production player detects a final-segment stall.
sub onSyntheticHandoff(event as object)
    if m.switched = true then return
    request = m.player.request
    suffix = "/hls/index.m3u8"
    if request.growing <> true or right(request.url, len(suffix)) <> suffix then return
    m.switched = true
    completed = {}
    completed.append(request)
    completed.url = left(request.url, len(request.url) - len(suffix)) + "/file/"
    completed.streamFormat = "mkv"
    completed.growing = false
    completed.resume = int(event.getData().position)
    print "[growing-controls] fixture completed-file handoff; second="; completed.resume
    m.player.request = completed
end sub

sub growingControlsClosed()
    m.timer.control = "stop"
    print "[growing-controls] CLOSED"
end sub

sub growingControlsSample()
    if m.nativeVideo <> invalid
        print "[growing-controls] baseline sample="; m.nativeVideo.state; " pos="; m.nativeVideo.position; " dur="; m.nativeVideo.duration
        return
    end if
    video = m.player.findNode("mediaVideo")
    controls = m.player.findNode("recordingControls")
    print "[growing-controls] state="; video.state; " pos="; video.position; " dur="; video.duration; " nativeUI="; video.enableUI; " controls="; controls.visible
end sub
