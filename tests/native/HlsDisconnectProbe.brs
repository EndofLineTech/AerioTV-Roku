' Disposable app overlay, only runs after the saved Dispatcharr account is ready.
sub installHlsDisconnectProbe()
    m.hlsProbeTimer = m.top.createChild("Timer")
    m.hlsProbeTimer.duration = 1
    m.hlsProbeTimer.repeat = true
    m.hlsProbeTimer.observeField("fire", "startHlsDisconnectProbe")
    m.hlsProbeTimer.control = "start"
end sub

sub startHlsDisconnectProbe()
    if m.page <> "guide" or m.guide.config = invalid then return
    if m.guide.config.providerType <> "dispatcharr" then return
    if m.guide.config.channels.count() = 0 then return
    m.hlsProbeTimer.control = "stop"
    m.hlsProbeTask = CreateObject("roSGNode", "HlsDisconnectProbeTask")
    m.hlsProbeTask.baseUrl = m.baseUrl
    m.hlsProbeTask.apiKey = m.apiKey
    m.hlsProbeTask.channelUuid = m.guide.config.channels[0].uuid
    m.hlsProbeTask.observeField("result", "onHlsDisconnectProbe")
    m.hlsProbeTask.control = "RUN"
end sub

sub onHlsDisconnectProbe()
    if m.hlsProbeTask = invalid then return
    m.hlsProbeTask.unobserveField("result")
    m.hlsProbeTask = invalid
    print "[hls-disconnect-probe] complete"
end sub
