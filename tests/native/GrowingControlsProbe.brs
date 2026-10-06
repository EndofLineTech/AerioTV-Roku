' Synthetic recording-style HLS fixture, no real account or server access.
sub init()
    m.player = m.top.findNode("player")
    m.player.observeField("closed", "growingControlsClosed")
    m.timer = m.top.findNode("sample")
    m.timer.observeField("fire", "growingControlsSample")
    app = CreateObject("roAppInfo")
    growing = app.getValue("dvr_controls_fixture_growing") = "true"
    m.player.request = {account: "fixture", identity: "synthetic-reader", key: "fixture", mode: "recording", title: "Synthetic recording", url: app.getValue("dvr_controls_fixture_url"), apiKey: "", streamFormat: app.getValue("dvr_controls_fixture_format"), growing: growing, resume: 0}
    m.timer.control = "start"
end sub

sub growingControlsClosed()
    m.timer.control = "stop"
    print "[growing-controls] CLOSED"
end sub

sub growingControlsSample()
    video = m.player.findNode("mediaVideo")
    controls = m.player.findNode("recordingControls")
    print "[growing-controls] state="; video.state; " pos="; video.position; " dur="; video.duration; " nativeUI="; video.enableUI; " controls="; controls.visible
end sub
