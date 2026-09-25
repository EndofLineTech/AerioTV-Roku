' Disposable installed-app probe. No server or stored preference changes.
' This exercises production startup-error routing on an already authorized
' sample; source names, URLs and credentials are never printed.
sub installAacDecodeProbe()
    m.aacProbeTicks = 0
    m.aacProbeStage = 0
    m.aacProbeOriginalMode = ""
    m.aacProbeMemory = CreateObject("roAppMemoryMonitor")
    m.aacProbeTimer = m.top.createChild("Timer")
    m.aacProbeTimer.duration = 1
    m.aacProbeTimer.repeat = true
    m.aacProbeTimer.observeField("fire", "aacDecodeProbeTick")
    m.aacProbeTimer.control = "start"
end sub

sub finishAacDecodeProbe(result as string)
    m.aacProbeTimer.control = "stop"
    m.audioCheck.control = "stop"
    stopPlayback()
    if m.aacProbeOriginalMode <> "" then m.devicePreferences.audioMode = m.aacProbeOriginalMode
    print "[aac-probe] local-cleanup="; m.video.content = invalid and m.page = "guide"; " app-memory-percent="; m.aacProbeMemory.getMemoryLimitPercent()
    print "[aac-probe] result="; result
end sub

sub onAacProbeVideoState()
    print "[aac-probe] state="; m.video.state; " profile="; m.activeAudioProfile <> ""; " code="; m.video.errorCode
end sub

sub aacDecodeProbeTick()
    m.aacProbeTicks++
    if m.aacProbeTicks > 100
        finishAacDecodeProbe("timeout")
        return
    end if
    if m.aacProbeStage = 0
        if m.page <> "guide" or m.guide.config = invalid or m.capabilityTask <> invalid then return
        if m.aacProfile = invalid
            finishAacDecodeProbe("no-existing-aac-profile")
            return
        end if
        sample = invalid
        reference = invalid
        for each channel in m.guide.config.channels
            if textValue(channel.number) = "5.1" then sample = channel
            if textValue(channel.number) = "3.3" then reference = channel
        end for
        if sample = invalid or reference = invalid
            finishAacDecodeProbe("authorized-sample-unavailable")
            return
        end if
        m.aacProbeOriginalMode = m.devicePreferences.audioMode
        print "[aac-probe] saved-mode="; m.aacProbeOriginalMode; " profile-present=true"
        ' In-memory Auto only. Never save a preference or change a provider.
        m.devicePreferences.audioMode = "auto"
        m.aacProbeTarget = sample
        m.aacProbeStage = 10
        m.video.observeField("state", "onAacProbeVideoState")
        startPlayback(reference, true)
        return
    end if
    if m.aacProbeStage = 10
        if m.video.state = "playing"
            m.aacProbeStage = 11
            m.aacProbeReferenceAt = m.aacProbeTicks
            m.audioCheck.control = "stop"
            print "[aac-probe] reference-playing=true"
        else if m.playbackFailureDialog <> invalid
            finishAacDecodeProbe("reference-source-failed")
        end if
        return
    end if
    if m.aacProbeStage = 11
        m.audioCheck.control = "stop"
        if m.video.state <> "playing"
            finishAacDecodeProbe("reference-ended")
            return
        end if
        if m.aacProbeTicks - m.aacProbeReferenceAt < 2 then return
        m.aacProbeStage = 1
        startPlayback(m.aacProbeTarget, true)
        return
    end if
    if m.aacProbeStage = 1
        if m.aacDecodeRetried = true
            m.aacProbeStage = 2
            print "[aac-probe] bounded-fallback="; m.activeAudioProfile <> ""
        else if m.playbackFailureDialog <> invalid
            finishAacDecodeProbe("failed-before-fallback")
        end if
        return
    end if
    if m.aacProbeStage = 2
        if m.video.state = "playing"
            m.audioCheck.control = "stop"
            m.aacProbeStage = 3
            m.aacProbePlayingAt = m.aacProbeTicks
            print "[aac-probe] playing after fallback audio="; m.video.audioFormat; " video="; m.video.videoFormat
        else if m.playbackFailureDialog <> invalid
            detail = lcase(m.playbackFailureDialog.message)
            kind = "other"
            if instr(1, detail, "unsupported aac") > 0 then kind = "unsupported-aac"
            if instr(1, detail, "buffer") > 0 then kind = "buffering"
            if instr(1, detail, "http") > 0 then kind = "http"
            print "[aac-probe] replacement-failure-class="; kind
            safe = sanitizePlaybackDiagnostic(m.playbackFailureDialog.message, m.apiKey)
            safe = CreateObject("roRegex", "[A-Za-z0-9-]{24,}", "").replaceAll(safe, "[identifier]")
            safe = CreateObject("roRegex", "[\r\n]+", "").replaceAll(safe, " / ")
            print "[aac-probe] replacement-detail="; left(safe, 260)
            finishAacDecodeProbe("aac-replacement-failed")
        end if
        return
    end if
    if m.aacProbeStage = 3
        m.audioCheck.control = "stop"
        if m.aacProbeTicks - m.aacProbePlayingAt < 3 then return
        if m.video.state = "playing" and m.video.audioFormat <> "none" and m.video.audioFormat <> ""
            finishAacDecodeProbe("native-audio-and-playing")
        else
            finishAacDecodeProbe("audio-or-picture-unconfirmed")
        end if
    end if
end sub
