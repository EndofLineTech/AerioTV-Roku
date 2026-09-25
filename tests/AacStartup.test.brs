sub main()
    resetAacTest()
    if not deferRequiredAacTune({uuid: "first"}, false, false, false, 900) then stop
    if m.starts <> 0 or not m.guide.pendingTune then stop
    if m.pendingAacTune.channel.uuid <> "first" then stop
    m.aacProfile = {id: "7"}
    m.aacDiscoveryState = "ready"
    processAacWait()
    if m.starts <> 1 or m.started.channel.uuid <> "first" or not m.started.useAac then stop
    if m.started.tuneStartedAt <> 900 then stop
    if m.pendingAacTune <> invalid or m.guide.pendingTune then stop

    resetAacTest()
    deferRequiredAacTune({uuid: "first"}, false, false, false)
    cancelAacWait()
    m.aacProfile = {id: "7"}
    processAacWait()
    if m.starts <> 0 then stop

    resetAacTest()
    deferRequiredAacTune({uuid: "old"}, false, false, false)
    cancelAacWait()
    deferRequiredAacTune({uuid: "new"}, true, false, true)
    m.aacProfile = {id: "7"}
    processAacWait()
    if m.starts <> 1 or m.started.channel.uuid <> "new" then stop
    if not m.started.preserveBudget then stop

    resetAacTest()
    deferRequiredAacTune({uuid: "first"}, false, false, false)
    m.pendingAacTune.clock = {totalMilliseconds: function() as integer
        return 20000
    end function}
    processAacWait()
    if m.starts <> 0 or m.failures <> 1 or m.pendingAacTune <> invalid then stop
    m.aacProfile = {id: "7"}
    processAacWait()
    if m.starts <> 0 then stop ' late discovery cannot resurrect timed-out tune

    for each state in ["unavailable", "error"]
        resetAacTest()
        deferRequiredAacTune({uuid: "first"}, false, false, false)
        m.aacDiscoveryState = state
        processAacWait()
        if m.starts <> 0 or m.failures <> 1 then stop
    end for

    resetAacTest()
    deferRequiredAacTune({uuid: "first"}, false, false, false)
    m.accountIdentity = "another-account"
    m.aacProfile = {id: "7"}
    processAacWait()
    if m.starts <> 0 or m.pendingAacTune <> invalid then stop

    resetAacTest()
    m.devicePreferences.audioMode = "direct"
    if deferRequiredAacTune({uuid: "first"}, false, false, false) then stop
    m.devicePreferences.audioMode = "auto"
    if deferRequiredAacTune({uuid: "first"}, false, false, false) then stop
    if not deferRequiredAacTune({uuid: "first"}, true, true, true) then stop

    resetAacTest()
    m.devicePreferences.audioMode = "auto"
    m.aacProfile = {id: "7"}
    if not retryUnsupportedAacDecode(-5, "decoder:pump:Unsupported AAC stream:clip") then stop
    if m.starts <> 1 or m.started.channel.uuid <> "first" then stop
    if not m.started.force or not m.started.useAac or not m.started.preserveBudget then stop
    if m.started.tuneStartedAt <> 900 or not m.aacDecodeRetried then stop
    if retryUnsupportedAacDecode(-5, "Unsupported AAC stream") or m.starts <> 1 then stop

    for each mode in ["direct", "aac"]
        resetAacTest()
        m.devicePreferences.audioMode = mode
        m.aacProfile = {id: "7"}
        if retryUnsupportedAacDecode(-5, "Unsupported AAC stream") then stop
    end for
    resetAacTest()
    m.devicePreferences.audioMode = "auto"
    m.aacProfile = {id: "7"}
    if retryUnsupportedAacDecode(-5, "unsupported video codec") then stop
    if retryUnsupportedAacDecode(-1, "Unsupported AAC stream") then stop
    m.streamReady = true
    if retryUnsupportedAacDecode(-5, "Unsupported AAC stream") then stop
    m.streamReady = false
    m.activeAudioProfile = "7"
    if retryUnsupportedAacDecode(-5, "Unsupported AAC stream") then stop
    m.activeAudioProfile = ""
    m.pendingChannel = {uuid: "new"}
    if retryUnsupportedAacDecode(-5, "Unsupported AAC stream") then stop
    m.pendingChannel = invalid
    m.connectionStore.entries[0].provider = "m3u"
    if retryUnsupportedAacDecode(-5, "Unsupported AAC stream") then stop
    m.connectionStore.entries[0].provider = "dispatcharr"
    m.aacProfile = invalid
    if retryUnsupportedAacDecode(-5, "Unsupported AAC stream") or m.starts <> 0 then stop
    print "ALL TESTS PASSED"
end sub

sub resetAacTest()
    m.devicePreferences = {audioMode: "aac"}
    m.accountIdentity = "account-one"
    m.aacProfile = invalid
    m.aacDiscoveryState = "pending"
    m.aacDiscoveryMessage = "Profile unavailable"
    m.capabilityTask = {}
    m.pendingAacTune = invalid
    m.aacWaitTimer = {control: "stop"}
    m.guide = {pendingTune: false}
    m.noticeText = {text: ""}
    m.noticeTimer = {control: "stop"}
    m.starts = 0
    m.failures = 0
    m.playingChannel = {uuid: "first"}
    m.liveSession = {openedAt: 900}
    m.page = "player"
    m.streamReady = false
    m.activeAudioProfile = ""
    m.aacDecodeRetried = false
    m.pendingChannel = invalid
    m.heldZap = ""
    m.selectedConnectionId = "current"
    m.connectionStore = {entries: [{id: "current", provider: "dispatcharr"}]}
end sub

function connectionStoreEntry(store as object, id as string) as dynamic
    for each entry in store.entries
        if entry.id = id then return entry
    end for
    return invalid
end function

sub refreshCapabilities()
    m.aacDiscoveryState = "pending"
end sub

sub showNotice(message as string)
    m.noticeText.text = message
end sub

sub hideNotice()
    m.noticeText.text = ""
end sub

sub showAacUnavailable(request as object, message as string)
    m.failures++
    m.failureMessage = message
end sub

sub startPlayback(channel as object, force as boolean, useAac as boolean, preserveBudget as boolean, tuneStartedAt = 0 as integer)
    m.starts++
    m.started = {channel: channel, force: force, useAac: useAac, preserveBudget: preserveBudget, tuneStartedAt: tuneStartedAt}
end sub
