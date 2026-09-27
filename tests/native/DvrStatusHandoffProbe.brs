' Credential-free test scene exercising the production DvrPlayback handlers.
sub init()
    m.mediaPlayer = m.top.findNode("player")
    m.mediaPlayer.observeField("recordingHandoff", "onDvrHandoffRequested")
    m.mediaPlayer.observeField("closed", "onStatusProbeClosed")
    m.timer = m.top.findNode("sample")
    m.timer.observeField("fire", "onStatusProbeSample")
    app = CreateObject("roAppInfo")
    url = app.getValue("dvr_controls_fixture_url")
    suffix = "/hls/index.m3u8"
    if right(url, len(suffix)) <> suffix then return
    m.baseUrl = left(url, len(url) - len(suffix))
    m.apiKey = ""
    m.serverAccountId = "synthetic-account"
    m.accountIdentity = "synthetic-account"
    m.mediaIdentity = "synthetic-playback"
    m.capabilities = {dvr: "view"}
    m.dvrPlayback = {account: m.accountIdentity, id: "12", growing: true}
    m.mediaReturn = "dvr"
    m.page = "onDemand"
    m.mediaPlayer.request = {account: m.accountIdentity, identity: m.mediaIdentity, key: "12", mode: "recording", title: "Synthetic status handoff", url: url, apiKey: "", streamFormat: "hls", growing: true, resume: 0}
    m.timer.control = "start"
end sub

sub onStatusProbeSample()
    request = m.mediaPlayer.request
    if request = invalid then return
    video = m.mediaPlayer.findNode("mediaVideo")
    print "[status-handoff-probe] state="; video.state; " pos="; video.position; " dur="; video.duration; " reader="; request.streamFormat
end sub

sub onStatusProbeClosed()
    m.timer.control = "stop"
    cancelDvrHandoff()
    print "[status-handoff-probe] CLOSED"
end sub
