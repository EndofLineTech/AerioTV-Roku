' Temporary AerioScene fixture: one intentional tune, existing preferences.
sub installLiveReaderProbe()
    for each format in ["mpegts", "ts"]
        node = CreateObject("roSGNode", "ContentNode")
        node.streamFormat = format
        print "[live-reader] input="; format; " stored="; node.streamFormat
    end for
    m.readerProbeTicks = 0
    m.readerProbeStarted = false
    m.readerProbePlaying = 0
    m.readerProbeTimer = m.top.createChild("Timer")
    m.readerProbeTimer.duration = 1
    m.readerProbeTimer.repeat = true
    m.readerProbeTimer.observeField("fire", "liveReaderProbeTick")
    m.readerProbeTimer.control = "start"
end sub

sub liveReaderProbeTick()
    m.readerProbeTicks++
    if m.readerProbeTicks > 70
        print "[live-reader] timeout state="; m.video.state
        stopPlayback()
        m.readerProbeTimer.control = "stop"
        return
    end if
    if not m.readerProbeStarted
        if m.guide.config = invalid or m.capabilityTask <> invalid then return
        for each channel in m.guide.config.channels
            if channel.number = "426"
                print "[live-reader] existing-audio-mode="; m.devicePreferences.audioMode
                m.readerProbeStarted = true
                startPlayback(channel, true)
                print "[live-reader] native-format="; m.video.content.streamFormat; " audio-profile="; m.activeAudioProfile
                exit for
            end if
        end for
    else if m.video.state = "playing"
        m.readerProbePlaying++
        if m.readerProbePlaying >= 10
            print "[live-reader] playing position="; m.video.position; " video="; m.video.videoFormat; " audio="; m.video.audioFormat
            stopPlayback()
            m.readerProbeTimer.control = "stop"
            print "[live-reader] complete"
        end if
    else if m.playbackFailureDialog <> invalid
        print "[live-reader] failed="; m.playbackFailureDialog.message
        m.readerProbeTimer.control = "stop"
    end if
end sub
