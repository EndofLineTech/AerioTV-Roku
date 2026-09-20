' Native controller fixture: temporarily copy into components, import in
' AerioScene.xml, call installMetadataLifecycleProbe from init, and expose
' clearStoredGuideCache in GuideView.xml. Remove all hooks after collecting.
' Never include in the normal app package; this fixture requests a live tune.
sub installMetadataLifecycleProbe()
    m.metadataProbePhase = 0
    m.metadataProbeTimer = m.top.createChild("Timer")
    m.metadataProbeTimer.duration = 10
    m.metadataProbeTimer.repeat = true
    m.metadataProbeTimer.observeField("fire", "onMetadataProbeTick")
    m.metadataProbeTimer.control = "start"
end sub

sub onMetadataProbeTick()
    m.metadataProbePhase++
    if m.metadataProbePhase = 1
        for each channel in m.guide.config.channels
            if instr(1, lcase(channel.name), "espn") > 0
                startPlayback(channel)
                exit for
            end if
        end for
        print "[metadata-lifecycle] tuneRequested="; m.playingChannel <> invalid
    else if m.metadataProbePhase = 2
        m.metadataProbeContent = m.video.content
        print "[metadata-lifecycle] before-clear state="; m.video.state
        m.guide.callFunc("clearStoredGuideCache")
    else if m.metadataProbePhase = 3
        if m.metadataProbeContent = invalid or m.video.content = invalid
            print "[metadata-lifecycle] no media content; playback assertions unavailable"
            m.metadataProbeTimer.control = "stop"
            return
        end if
        print "[metadata-lifecycle] after-clear state="; m.video.state; " sameContent="; m.video.content.isSameNode(m.metadataProbeContent)
        refreshChannelLineup()
    else if m.metadataProbePhase = 4
        print "[metadata-lifecycle] after-lineup state="; m.video.state; " sameContent="; m.video.content.isSameNode(m.metadataProbeContent)
        stopPlayback()
        m.metadataProbeTimer.control = "stop"
    end if
end sub
